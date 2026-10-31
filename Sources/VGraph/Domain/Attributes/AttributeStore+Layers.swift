/// ADR-0030 on `AttributeStore`. A query names its topmost layer and
/// reads the path from the root to it; within each layer a key is tried before
/// its type. A value that its ancestors already resolve along that chain is
/// not stored.
extension AttributeStore {

    public func addLayer(_ layer: AttributeLayer, parent: AttributeLayer, admission: LayerAdmission) throws(VError)
        -> AttributeStore
    {
        _ = try info(parent)
        guard layers[layer] == nil else { throw VError.duplicateAttributeLayer(layer) }
        var result = self
        result.layers[layer] = LayerInfo(parent: parent, admission: admission)
        return result
    }

    public func removeLayer(_ layer: AttributeLayer) throws(VError) -> AttributeStore {
        _ = try info(layer)
        var result = self
        result.layers[layer] = nil
        result.layerValues[layer] = nil
        result.ruleSources[layer] = nil
        return result
    }

    /// Judges `key`'s values, and those of keys typed by it, against their
    /// chains again — after the key was retyped, say.
    public func repruning(_ key: ItemKey, chains: some ChainSource) -> AttributeStore {
        repruned(affected(by: key, chains), fromLayer: nil, chains)
    }

    public func set(
        _ attribute: Attribute, for key: ItemKey, in layer: AttributeLayer, source: AttributeSource = .direct,
        chains: some ChainSource
    ) throws(VError) -> AttributeStore {
        let definition = try checked(attribute, for: key, in: layer)
        let redundant =
            definition.category != .computed
            && isRedundant(attribute.stringValue, attribute.id, for: key, in: layer, definition, chains)
        return writing(redundant ? nil : attribute.stringValue, source: source, attribute.id, for: key, in: layer)
            .repruned(affected(by: key, chains), fromLayer: layer, chains)
    }

    /// Checked like `set`, but pruned once at the end, so no value is judged
    /// before the values it depends on are in place.
    public func merging(
        _ values: [(key: ItemKey, attribute: Attribute)], into layer: AttributeLayer, chains: some ChainSource
    ) throws(VError) -> AttributeStore {
        var result = self
        var touched: Set<ItemKey> = []
        for (key, attribute) in values {
            _ = try checked(attribute, for: key, in: layer)
            result = result.writing(attribute.stringValue, source: .direct, attribute.id, for: key, in: layer)
            touched.formUnion(affected(by: key, chains))
        }
        return result.repruned(touched, fromLayer: layer, chains)
    }

    private func checked(_ attribute: Attribute, for key: ItemKey, in layer: AttributeLayer) throws(VError)
        -> AttributeDefinition
    {
        let definition = try admitted(attribute.id, key: key, in: layer)
        guard attribute.definition.typeAsString == definition.typeAsString else {
            throw VError.attributeTypeMismatch(
                attribute.id, expected: definition.typeAsString, found: attribute.definition.typeAsString)
        }
        return definition
    }

    /// Admitted like a write: a layer that may not hold a value may not be
    /// asked to drop one either.
    public func remove(
        _ id: Attribute.Id, for key: ItemKey, in layer: AttributeLayer, chains: some ChainSource
    ) throws(VError) -> AttributeStore {
        _ = try admitted(id, key: key, in: layer)
        return writing(nil, source: .direct, id, for: key, in: layer)
            .repruned(affected(by: key, chains), fromLayer: layer, chains)
    }

    public func removeKey(_ key: ItemKey) -> AttributeStore {
        var result = self
        for (layer, values) in layerValues where values[key.kind]?[key.id] != nil {
            result.layerValues[layer]?[key.kind]?[key.id] = nil
            result.ruleSources[layer]?[key] = nil
        }
        return result
    }

    /// The same values, rule sources included, under another key in every layer:
    /// a node becoming a detailed node and back keeps what it had (ADR-0032).
    /// Neither admitted nor pruned here — the caller's chains changed with the key.
    public func rekeying(from old: ItemKey, to new: ItemKey) -> AttributeStore {
        guard old != new else { return self }
        var result = self
        for (layer, values) in layerValues {
            guard let container = values[old.kind]?[old.id] else { continue }
            result.layerValues[layer]?[old.kind]?[old.id] = nil
            result.layerValues[layer, default: [:]][new.kind, default: [:]][new.id] = container
            result.ruleSources[layer]?[new] = ruleSources[layer]?[old]
            result.ruleSources[layer]?[old] = nil
        }
        return result
    }

    /// Drops the key's values whose definition `discard` picks, in every layer.
    func removing(for key: ItemKey, where discard: (AttributeDefinition) -> Bool) -> AttributeStore {
        var result = self
        for layer in layerValues.keys {
            for (id, _) in layerValues[layer]?[key.kind]?[key.id] ?? [:] {
                guard let definition = definitions[id], discard(definition) else { continue }
                result = result.writing(nil, source: .direct, id, for: key, in: layer)
            }
        }
        return result
    }

    /// Swaps a layer's contents, as when a document's `vnotation` is reparsed.
    /// Every value is checked as `set` would check it.
    public func replaceLayer(
        _ layer: AttributeLayer, with values: [ItemKey: AttributeContainer], chains: some ChainSource
    ) throws(VError) -> AttributeStore {
        var result = self
        result.layerValues[layer] = nil
        result.ruleSources[layer] = nil
        for (key, container) in values {
            for (id, value) in container {
                _ = try admitted(id, key: key, in: layer)
                result = result.writing(value, source: .direct, id, for: key, in: layer)
            }
        }
        return result.repruned(nil, fromLayer: layer, chains)
    }

    public func resolve(
        _ id: Attribute.Id, for key: ItemKey, through layer: AttributeLayer, chains: some ChainSource
    ) throws(VError) -> ResolvedAttribute {
        let definition = try getAttributeDefinition(id)
        _ = try info(layer)
        let keys = chain(of: key, chains)
        var current: AttributeLayer? = layer
        while let name = current {
            for step in keys {
                if let value = layerValues[name]?[step.kind]?[step.id]?[id] {
                    return ResolvedAttribute(value, from: .layer(name, key: step, source: source(id, step, name)))
                }
            }
            current = layers[name]?.parent
        }
        return ResolvedAttribute(definition.defaultValue, from: .default)
    }

    /// Every attribute some layer sets along the key's chain. No defaults.
    public func resolveAll(
        for key: ItemKey, through layer: AttributeLayer, chains: some ChainSource
    ) throws(VError) -> [Attribute.Id: ResolvedAttribute] {
        _ = try info(layer)
        let keys = chain(of: key, chains)
        var result: [Attribute.Id: ResolvedAttribute] = [:]
        var current: AttributeLayer? = layer
        while let name = current {
            for step in keys {
                for (id, value) in layerValues[name]?[step.kind]?[step.id] ?? [:] where result[id] == nil {
                    result[id] = ResolvedAttribute(value, from: .layer(name, key: step, source: source(id, step, name)))
                }
            }
            current = layers[name]?.parent
        }
        return result
    }

    /// What one layer holds for one key, and nothing it inherits.
    public func values(in layer: AttributeLayer, for key: ItemKey) throws(VError) -> AttributeContainer {
        _ = try info(layer)
        return layerValues[layer]?[key.kind]?[key.id] ?? [:]
    }

    private func info(_ layer: AttributeLayer) throws(VError) -> LayerInfo {
        guard let info = layers[layer] else { throw VError.unknownAttributeLayer(layer) }
        return info
    }

    private func admitted(_ id: Attribute.Id, key: ItemKey, in layer: AttributeLayer) throws(VError)
        -> AttributeDefinition
    {
        let definition = try getAttributeDefinition(id)
        guard try info(layer).admission.admits(key, definition) else {
            throw VError.attributeNotAdmitted(id, key: key, layer: layer)
        }
        return definition
    }

    /// A cycle ends the chain rather than looping.
    func chain(of key: ItemKey, _ chains: some ChainSource) -> [ItemKey] {
        var result = [key]
        while let next = chains.type(of: result[result.count - 1]), !result.contains(next) {
            result.append(next)
        }
        return result
    }

    /// The keys whose values a change to `key` may make redundant: its
    /// dependents, and the types on its chain, whose values in a more specific
    /// layer may have been kept only to beat it.
    private func affected(by key: ItemKey, _ chains: some ChainSource) -> Set<ItemKey> {
        dependents(of: key, chains).union(chain(of: key, chains))
    }

    /// The key and every key whose chain passes through it.
    private func dependents(of key: ItemKey, _ chains: some ChainSource) -> Set<ItemKey> {
        var result: Set<ItemKey> = [key]
        var frontier = [key]
        while let current = frontier.popLast() {
            for member in chains.members(of: current) where !result.contains(member) {
                result.insert(member)
                frontier.append(member)
            }
        }
        return result
    }

    private func source(_ id: Attribute.Id, _ key: ItemKey, _ layer: AttributeLayer) -> AttributeSource {
        ruleSources[layer]?[key]?[id].map { AttributeSource.rule($0) } ?? .direct
    }

    /// Whether `value` on `key` in `layer` changes no resolution through
    /// `layer`: neither the key's own nor that of any element it is the type
    /// of. A view's value on a type is not redundant while it beats a model
    /// value on one of the type's elements.
    private func isRedundant(
        _ value: String, _ id: Attribute.Id, for key: ItemKey, in layer: AttributeLayer,
        _ definition: AttributeDefinition, _ chains: some ChainSource
    ) -> Bool {
        dependents(of: key, chains).allSatisfy { dependent in
            let keys = chain(of: dependent, chains)
            let shadowed = keys.prefix { $0 != key }.contains { layerValues[layer]?[$0.kind]?[$0.id]?[id] != nil }
            return shadowed || definition.isEqual(value, resolved(id, along: keys, through: layer, ignoring: key, definition))
        }
    }

    /// What `resolve` returns along `keys` through `layer` if `layer` held no
    /// value for `ignored`. The layer's own less specific keys outrank its
    /// ancestors, so they are asked first.
    private func resolved(
        _ id: Attribute.Id, along keys: [ItemKey], through layer: AttributeLayer, ignoring ignored: ItemKey,
        _ definition: AttributeDefinition
    ) -> String {
        for step in keys where step != ignored {
            if let value = layerValues[layer]?[step.kind]?[step.id]?[id] { return value }
        }
        var current = layers[layer]?.parent
        while let name = current {
            for step in keys {
                if let value = layerValues[name]?[step.kind]?[step.id]?[id] { return value }
            }
            current = layers[name]?.parent
        }
        return definition.defaultValue
    }

    private func writing(
        _ value: String?, source: AttributeSource, _ id: Attribute.Id, for key: ItemKey, in layer: AttributeLayer
    ) -> AttributeStore {
        var result = self
        var container = layerValues[layer]?[key.kind]?[key.id] ?? [:]
        container[id] = value
        result.layerValues[layer, default: [:]][key.kind, default: [:]][key.id] = container.isEmpty ? nil : container
        var rules = ruleSources[layer]?[key] ?? [:]
        if value != nil, case .rule(let rule) = source {
            rules[id] = rule
        } else {
            rules[id] = nil
        }
        result.ruleSources[layer, default: [:]][key] = rules.isEmpty ? nil : rules
        return result
    }

    /// `layer` and the layers below it (all of them if nil), parents before
    /// children, so each is judged against ancestors already pruned. `layer`
    /// itself is included: its type values judge its element values.
    private func layersFrom(_ layer: AttributeLayer?) -> [AttributeLayer] {
        var frontier: [AttributeLayer] = layer.map { [$0] } ?? layers.filter { $0.value.parent == nil }.map { $0.key }
        var result = frontier
        while !frontier.isEmpty {
            let parent = frontier.removeFirst()
            for (child, info) in layers where info.parent == parent {
                result.append(child)
                frontier.append(child)
            }
        }
        return result
    }

    /// Drops values that became redundant: for `keys`, or for every key if nil.
    private func repruned(
        _ keys: Set<ItemKey>?, fromLayer layer: AttributeLayer?, _ chains: some ChainSource
    ) -> AttributeStore {
        var result = self
        for name in layersFrom(layer) {
            for key in keys.map({ Array($0) }) ?? result.keys(in: name) {
                for (attribute, value) in result.layerValues[name]?[key.kind]?[key.id] ?? [:] {
                    guard let definition = definitions[attribute], definition.category != .computed,
                        result.isRedundant(value, attribute, for: key, in: name, definition, chains)
                    else { continue }
                    result = result.writing(nil, source: .direct, attribute, for: key, in: name)
                }
            }
        }
        return result
    }

    func keys(in layer: AttributeLayer) -> [ItemKey] {
        var result: [ItemKey] = []
        for (kind, byId) in layerValues[layer] ?? [:] {
            for id in byId.keys { result.append(ItemKey(kind, id)) }
        }
        return result
    }
}
