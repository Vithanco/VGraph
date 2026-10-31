/// How VGraph reads and writes its attributes through the layers (ADR-0030).
/// An element resolves along its chain (itself, then its type) through the
/// model's stack; nothing flows down from an enclosing group or the root.
extension VGraph {

    static func key(_ node: Node) -> ItemKey { ItemKey(.node, node.description) }
    static func key(_ edge: Edge.Id) -> ItemKey { ItemKey(.edge, edge.description) }
    /// The root group is the diagram itself, whose values live on the root key.
    static func key(_ group: Group) -> ItemKey {
        group.id.description == rootGroup ? .root : ItemKey(.group, group.id.description)
    }
    static func key(_ nodeType: NodeType) -> ItemKey { ItemKey(.nodeType, nodeType.description) }
    static func key(_ edgeType: EdgeType.Id) -> ItemKey { ItemKey(.edgeType, edgeType.description) }
    static func key(_ groupType: GroupType) -> ItemKey { ItemKey(.groupType, groupType.description) }

    /// Where a plain write for `key` lands: an edit to a type is an edit to the
    /// document's `vnotation`. A notation's own values arrive through `placing`.
    func layer(for key: ItemKey) -> AttributeLayer {
        key.kind.isType ? .vnotation : .model
    }

    /// Registers the content's types and puts its values in `layer`.
    public func placing(_ content: NotationContent, in layer: AttributeLayer) throws(VError) -> VGraph {
        var result = updatedSelfWith(ads: ads.define(content.definitions))
        for nodeType in content.nodeTypes { result = try result.add(nodeType: nodeType) }
        for edgeType in content.edgeTypes { result = try result.add(edgeType: edgeType) }
        for groupType in content.groupTypes { result = try result.add(groupType: groupType) }
        for detailing in content.detailings {
            result = try result.updatedSelfWith(notationDefinition: result.notationDefinition.declaring(detailing, in: layer))
                .startingFolded(detailing.nodeType)
        }
        try result.validateNotation()
        var values: [(key: ItemKey, attribute: Attribute)] = []
        for typeValues in content.values {
            for attribute in typeValues.attributes { values.append((key: typeValues.key, attribute: attribute)) }
        }
        return result.updatedSelfWith(ads: try result.ads.merging(values, into: layer, chains: result))
    }

    /// An attribute must be defined before it is written (ADR-0030): one defined
    /// on first use would have no category, and admission depends on it.
    func writing(_ attribute: Attribute, for key: ItemKey) throws(VError) -> VGraph {
        updatedSelfWith(ads: try ads.set(attribute, for: key, in: layer(for: key), chains: self))
    }

    func erasing(_ id: Attribute.Id, for key: ItemKey) -> VGraph {
        guard let store = try? ads.remove(id, for: key, in: layer(for: key), chains: self) else { return self }
        return updatedSelfWith(ads: store)
    }

    /// After `key` was retyped: its values, and its members', are judged again.
    func repruning(_ key: ItemKey) -> VGraph {
        updatedSelfWith(ads: ads.repruning(key, chains: self))
    }

    func forgetting(_ key: ItemKey) -> VGraph {
        updatedSelfWith(ads: ads.removeKey(key))
    }

    /// The value in force for `key`, or the definition's default. An attribute
    /// the graph has never defined resolves to its default.
    func resolvedValue(_ definition: AttributeDefinition, for key: ItemKey) throws(VError) -> String {
        guard ads.definitions[definition.id] != nil else { return definition.defaultValue }
        return try ads.resolve(definition.id, for: key, through: readLayer, chains: self).value
    }

    /// The value set along the key's chain, or `nil` where only the default applies.
    func explicitValue(_ definition: AttributeDefinition, for key: ItemKey) -> String? {
        guard ads.definitions[definition.id] != nil,
            let resolved = try? ads.resolve(definition.id, for: key, through: readLayer, chains: self),
            resolved.provenance != .default
        else { return nil }
        return resolved.value
    }

    func resolvedValues(for key: ItemKey) -> AttributeContainer {
        var result = AttributeContainer()
        for (id, resolved) in (try? ads.resolveAll(for: key, through: readLayer, chains: self)) ?? [:] {
            result[id] = resolved.value
        }
        return result
    }

    /// What `key` resolves to through the layers up to `layer` only — what a
    /// notation says before a document's own `vnotation` changes it.
    public func value<T: AttributeType>(
        _ definition: TypedAttributeDefinition<T>, of key: ItemKey, through layer: AttributeLayer
    ) -> T? {
        guard ads.definitions[definition.id] != nil,
            let raw = try? ads.resolve(definition.id, for: key, through: layer, chains: self).value
        else { return nil }
        return try? T.fromString(raw)
    }

    func ownValues(of key: ItemKey) -> AttributeContainer {
        var result = (try? attributes(in: .model, of: key)) ?? [:]
        if readLayer != .model {
            for (id, value) in (try? attributes(in: readLayer, of: key)) ?? [:] { result[id] = value }
        }
        return result
    }

    /// What one layer holds for one element or type, and nothing it inherits.
    public func attributes(in layer: AttributeLayer, of key: ItemKey) throws(VError) -> AttributeContainer {
        try ads.values(in: layer, for: key)
    }
}

/// The graph's structure is the only record of which type an element has.
extension VGraph: ChainSource {
    public func type(of key: ItemKey) -> ItemKey? {
        switch key.kind {
        case .node: return typedGraph.nodeType(for: Node(string: key.id)).map { Self.key($0) }
        case .edge: return typedGraph.edgeType(for: Edge.Id(string: key.id)).map { Self.key($0.id) }
        case .group:
            let group = Group(rawValue: key.id)
            return nodeType(of: group).map { Self.key($0) } ?? groupType(of: group).map { Self.key($0) }
        case .edgeType: return derivedEdgeTypes[EdgeType.Id(string: key.id)].map { Self.key($0) }
        case .root, .nodeType, .groupType: return nil
        }
    }

    public func members(of type: ItemKey) -> [ItemKey] {
        switch type.kind {
        case .nodeType:
            let nodes = typedGraph.nodeTypeMapping.getMany(one: NodeType(string: type.id)) ?? []
            let detailed = groups.filter { nodeType(of: $0)?.description == type.id }
            return nodes.map { Self.key($0) } + detailed.map { Self.key($0) }
        case .edgeType:
            let id = EdgeType.Id(string: type.id)
            let edges = (typedGraph.edgeTypeMapping.getMany(one: id) ?? []).map { Self.key($0) }
            return edges + derivedEdgeTypes.filter { $0.value == id }.map { Self.key($0.key) }
        case .groupType:
            return groups.filter { groupType(of: $0)?.description == type.id }.map { Self.key($0) }
        case .node, .edge, .group, .root:
            return []
        }
    }
}
