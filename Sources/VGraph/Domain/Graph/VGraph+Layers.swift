/// How VGraph reads and writes its attributes through the layers (ADR-0030).
/// An element resolves along its chain (itself, then its type) through the
/// model's stack; nothing flows down from an enclosing group or the root.
extension VGraph {

    /// Where a plain write for `key` lands: an edit to a type is an edit to the
    /// document's `vnotation`. A notation's own values arrive through `placing`.
    func layer(for key: ItemKey) -> AttributeLayer {
        key.kind.isType ? .vnotation : .model
    }

    /// Registers the content's types and puts its values in `layer`.
    public func placing(_ content: NotationContent, in layer: AttributeLayer) throws(VError) -> VGraph {
        let defined = updatedSelfWith(attributeStore: try attributeStore.defining(content.definitions))
        let withNodeTypes = try content.nodeTypes.folding(defined) { (graph, type) throws(VError) in
            try graph.adding(nodeType: type)
        }
        let withEdgeTypes = try content.edgeTypes.folding(withNodeTypes) { (graph, type) throws(VError) in
            try graph.adding(edgeType: type)
        }
        let withGroupTypes = content.groupTypes.reduce(withEdgeTypes) { graph, type in graph.adding(groupType: type) }
        let typed = try content.detailings.folding(withGroupTypes) { (graph, detailing) throws(VError) in
            try graph.updatedSelfWith(notationDefinition: graph.notationDefinition.declaring(detailing, in: layer))
                .startingFolded(detailing.nodeType)
        }
        try typed.validateNotation()
        let values = content.values.flatMap { typeValues in
            typeValues.attributes.map { (key: typeValues.key, attribute: $0) }
        }
        return typed.updatedSelfWith(attributeStore: try typed.attributeStore.merging(values, into: layer, chains: typed))
    }

    /// An attribute must be defined before it is written (ADR-0030): one defined
    /// on first use would have no category, and admission depends on it.
    func writing(_ attribute: Attribute, for key: ItemKey) throws(VError) -> VGraph {
        updatedSelfWith(attributeStore: try attributeStore.setting(attribute, for: key, in: layer(for: key), chains: self))
    }

    /// After `key` was retyped: its values, and its members', are judged again.
    func repruning(_ key: ItemKey) -> VGraph {
        updatedSelfWith(attributeStore: attributeStore.repruning(key, chains: self))
    }

    /// The value in force for `key`, or the definition's default. An attribute
    /// the graph has never defined resolves to its default.
    func resolvedValue(_ definition: AttributeDefinition, for key: ItemKey) throws(VError) -> String {
        guard attributeStore.definitions[definition.id] != nil else { return definition.defaultValue }
        return try attributeStore.resolve(definition.id, for: key, through: readLayer, chains: self).value
    }

    /// The value set along the key's chain, or `nil` where only the default applies.
    func explicitValue(_ definition: AttributeDefinition, for key: ItemKey) -> String? {
        guard attributeStore.definitions[definition.id] != nil,
            let resolved = try? attributeStore.resolve(definition.id, for: key, through: readLayer, chains: self),
            resolved.provenance != .default
        else { return nil }
        return resolved.value
    }

    func resolvedValues(for key: ItemKey) -> AttributeContainer {
        ((try? attributeStore.resolveAll(for: key, through: readLayer, chains: self)) ?? [:]).mapValues { $0.value }
    }

    /// What `key` resolves to through the layers up to `layer` only — what a
    /// notation says before a document's own `vnotation` changes it.
    public func value<T: AttributeType>(
        _ definition: TypedAttributeDefinition<T>, of key: ItemKey, through layer: AttributeLayer
    ) -> T? {
        guard attributeStore.definitions[definition.id] != nil,
            let raw = try? attributeStore.resolve(definition.id, for: key, through: layer, chains: self).value
        else { return nil }
        return try? T.fromString(raw)
    }

    /// The model's values, with the shown view's own on top.
    func ownValues(of key: ItemKey) -> AttributeContainer {
        let model = (try? attributes(in: .model, of: key)) ?? [:]
        guard readLayer != .model else { return model }
        return model.merging((try? attributes(in: readLayer, of: key)) ?? [:]) { _, view in view }
    }

    /// What one layer holds for one element or type, and nothing it inherits.
    public func attributes(in layer: AttributeLayer, of key: ItemKey) throws(VError) -> AttributeContainer {
        try attributeStore.values(in: layer, for: key)
    }
}

/// The graph's structure is the only record of which type an element has.
extension VGraph: ChainSource {
    public func type(of key: ItemKey) -> ItemKey? {
        switch key.kind {
        case .node: return typedGraph.nodeType(for: Node(rawValue: key.id)).map { ItemKey($0) }
        case .edge: return typedGraph.edgeType(for: Edge.Id(rawValue: key.id)).map { ItemKey($0.id) }
        case .group:
            let group = Group(rawValue: key.id)
            return nodeType(of: group).map { ItemKey($0) } ?? groupType(of: group).map { ItemKey($0) }
        case .edgeType: return derivedEdgeTypes[EdgeType.Id(rawValue: key.id)].map { ItemKey($0) }
        case .root, .nodeType, .groupType: return nil
        }
    }

    public func members(of type: ItemKey) -> [ItemKey] {
        switch type.kind {
        case .nodeType:
            let nodes = typedGraph.nodeTypeMapping.getMany(one: NodeType(rawValue: type.id)) ?? []
            let detailed = groups.filter { nodeType(of: $0)?.description == type.id }
            return nodes.map { ItemKey($0) } + detailed.map { ItemKey($0) }
        case .edgeType:
            let id = EdgeType.Id(rawValue: type.id)
            let edges = (typedGraph.edgeTypeMapping.getMany(one: id) ?? []).map { ItemKey($0) }
            return edges + derivedEdgeTypes.filter { $0.value == id }.map { ItemKey($0.key) }
        case .groupType:
            return groups.filter { groupType(of: $0)?.description == type.id }.map { ItemKey($0) }
        case .node, .edge, .group, .root:
            return []
        }
    }
}

/// The key an element's or a type's values are stored under, and its place in
/// the declaration order.
extension ItemKey {
    public init(_ node: Node) { self.init(.node, node.description) }
    public init(_ edge: Edge.Id) { self.init(.edge, edge.description) }
    /// The root group is the diagram itself, whose values live on the root key.
    public init(_ group: Group) { self = group == .root ? .root : ItemKey(.group, group.id.description) }
    public init(_ nodeType: NodeType) { self.init(.nodeType, nodeType.description) }
    public init(_ edgeType: EdgeType.Id) { self.init(.edgeType, edgeType.description) }
    public init(_ groupType: GroupType) { self.init(.groupType, groupType.description) }
}
