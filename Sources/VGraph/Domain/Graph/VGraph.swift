public struct VGraph {
    public struct Counts: VProtocol {
        let graphCount: TypedGraph.Counts
        let adsCount: AttributeStore.Counts
        let groupCount: GroupStructure.Counts
    }

    private let graph: TypedGraph
    let ads: AttributeStore
    public let groupStructure: GroupStructure
    private let declarationOrder: DeclarationOrder
    public let notationDefinition: NotationDefinition
    /// Display edge types and the type each stands for (ADR-0030).
    let derivedEdgeTypes: [EdgeType.Id: EdgeType.Id]
    /// Declaration order is the export order; each view is a layer of `ads`.
    public let views: [ViewDeclaration]
    let readLayer: AttributeLayer

    public var typedGraph: TypedGraph {
        return graph
    }

    public var attributeDefinitions: AttributeDefContainer {
        return ads.definitions
    }

    public init(
        graph: TypedGraph,
        ads: AttributeStore,
        groupStructure: GroupStructure,
        declarationOrder: DeclarationOrder = DeclarationOrder(),
        notationDefinition: NotationDefinition = NotationDefinition(),
        derivedEdgeTypes: [EdgeType.Id: EdgeType.Id] = [:],
        views: [ViewDeclaration] = [],
        readLayer: AttributeLayer = .model
    ) {
        self.graph = graph
        self.ads = ads
        self.groupStructure = groupStructure
        self.declarationOrder = declarationOrder
        self.notationDefinition = notationDefinition
        self.derivedEdgeTypes = derivedEdgeTypes
        self.views = views
        self.readLayer = readLayer
    }

    /// Adds a display edge type standing for `original` between other node
    /// types, as a folded edge needs. It holds no values: its chain continues
    /// to the original, so the original's styling reaches it.
    public func deriving(edgeType: EdgeType, from original: EdgeType.Id) throws(VError) -> VGraph {
        var derived = derivedEdgeTypes
        derived[edgeType.id] = original
        let added = try add(edgeType: edgeType)
        return VGraph(
            graph: added.graph, ads: added.ads, groupStructure: added.groupStructure,
            declarationOrder: added.declarationOrder, notationDefinition: added.notationDefinition,
            derivedEdgeTypes: derived, views: added.views, readLayer: added.readLayer)
    }

    public func update(edge: Edge.Id, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(edge))
    }

    public func delete(edge: Edge.Id, attribute: Attribute.Id) -> VGraph {
        erasing(attribute, for: Self.key(edge))
    }

    public func update(node: Node, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(node))
    }

    public func delete(edge: Edge.Id, attribute: Attribute) -> VGraph {
        return delete(edge: edge, attribute: attribute.definition.id)
    }

    public func delete(node: Node, attribute: Attribute.Id) -> VGraph {
        let result = erasing(attribute, for: Self.key(node))
        return result.updatedSelfWith(subgraphStructure: groupStructure.removeFromGroup(node: node))
    }

    public func delete(group: Group, attribute: Attribute.Id) -> VGraph {
        erasing(attribute, for: Self.key(group))
    }

    public func define(attribute: AttributeDefinition) throws(VError) -> VGraph {
        let newAds = try ads.define(attribute)
        return updatedSelfWith(ads: newAds)
    }

    public func define<T: AttributeType>(attribute: TypedAttributeDefinition<T>) throws(VError) -> VGraph {
        return try define(attribute: attribute.asDefinition)
    }

    public func defineAll(_ definitions: AttributeDefContainer) throws(VError) -> VGraph {
        let newAds = ads.define(definitions)
        return updatedSelfWith(ads: newAds)
    }

    public func defineStandardAttributes() throws(VError) -> VGraph {
        return try defineAll(Attributes.Node.definitions).defineAll(Attributes.Edge.definitions).defineAll(
            Attributes.Group.definitions)
    }

    public func delete(node: Node) throws(VError) -> VGraph {
        let newGraph = try graph.delete(node: node)
        let newAds = ads.removeKey(Self.key(node))
        let newGroupStructure = groupStructure.removeFromGroup(node: node)
        return updatedSelfWith(
            graph: newGraph, ads: newAds, subgraphStructure: newGroupStructure,
            declarationOrder: declarationOrder.removing(ItemKey(.node, node.description)))
    }

    public func delete(edge: Edge.Id) throws(VError) -> VGraph {
        let newGraph = try graph.delete(edge: edge)
        let newAds = ads.removeKey(Self.key(edge))
        return updatedSelfWith(
            graph: newGraph, ads: newAds, declarationOrder: declarationOrder.removing(ItemKey(.edge, edge.description)))
    }

    public func add(nodeType: String) throws(VError) -> VGraph {
        return try add(nodeType: NodeType(rawValue: nodeType))
    }

    public func add(nodeType: NodeType) throws(VError) -> VGraph {
        return try add(nodeType: nodeType, addTo: Notation(rawValue: "change me"))
    }

    public func add(nodeType: NodeType, addTo: Notation) throws(VError) -> VGraph {
        let newGraph = try graph.add(nodeType: nodeType, notation: addTo)
        return updatedSelfWith(graph: newGraph)
    }

    public func add(groupType: GroupType) throws(VError) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.registering(groupType))
    }

    public func add(icon name: String, artwork: IconArtwork) throws(VError) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(icon: name, artwork: artwork))
    }

    private var declaredIconRegistry: IconRegistry { notationDefinition.icons }

    public var notationName: String { notationDefinition.name }

    public func using(notation name: String) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.named(name))
    }

    public func extending(notation name: String?) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.extending(name))
    }

    public func using(extensions: [String]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.with(extensions: extensions))
    }

    /// A `vnotation`'s own quality checks, in place of the built-in notation's.
    public func declaring(qualityChecks: [QualityCheckSpec]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(qualityChecks: qualityChecks))
    }

    /// A `vnotation`'s own transform steps, in place of the built-in notation's.
    public func declaring(transforms: [String]) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.declaring(transforms: transforms))
    }

    /// The exporter re-emits exactly these, and nothing VGraph ships.
    public var declaredIcons: [String: IconArtwork] {
        declaredIconRegistry.entries
    }

    /// Declared wins, so a built-in added in a later release cannot change a
    /// document that already draws its own mark under that name (ADR-0022).
    public func artwork(forIcon name: String) -> IconArtwork? {
        declaredIconRegistry[name] ?? BuiltinIcons.artwork(for: name)
    }

    /// Includes the synthetic unknown type when a document needed one; callers
    /// offering a choice filter it out, as they do for node types.
    public var groupTypes: [GroupType] { notationDefinition.groupTypes }

    public func has(groupTypeName: String) -> Bool {
        notationDefinition.groupTypes.contains { $0.description == groupTypeName }
    }

    /// Styled as it is registered, so a mistyped boundary carries its red chrome
    /// wherever `resolvedGroupStyle` reaches it. Mirrors `ensureUnknownNodeType`.
    public func ensureUnknownGroupType() throws(VError) -> VGraph {
        if has(groupTypeName: GroupType.unknownPrefix) {
            return self
        }
        let style = GroupStyle(folded: .empty, unfolded: GroupType.unknownChrome)
        return try placing(
            NotationContent(groupTypes: [.unknown], values: [.groupType(.unknown, [Attributes.Group.groupStyle(style)])]),
            in: .engine)
    }

    public func add(edgeType: String, from: String, to: String) throws(VError) -> VGraph {
        let et = EdgeType(string: edgeType, from: from, to: to)
        return try add(edgeType: et)
    }

    public func add(edgeType: EdgeType) throws(VError) -> VGraph {
        let newGraph = try graph.add(edgeType: edgeType, notation: Notation(rawValue: "change me"))
        return updatedSelfWith(graph: newGraph)
    }

    public func ensureUnknownNodeType() throws(VError) -> VGraph {
        let unknownType = NodeType.unknown
        if has(nodeType: unknownType) {
            return self
        }
        let newGraph = try graph.ensureUnknownNodeType()
        return updatedSelfWith(graph: newGraph)
    }

    public func ensureUnknownEdgeType(from: NodeType, to: NodeType) throws(VError) -> (VGraph, EdgeType) {
        let unknownEdgeType = EdgeType.unknown(from: from, to: to)

        if let existing = get(edgeType: unknownEdgeType.id) {
            return (self, existing)
        }

        let (newGraph, edgeType) = try graph.ensureUnknownEdgeType(from: from, to: to)
        let styled = try updatedSelfWith(graph: newGraph).placing(
            NotationContent(values: [.edgeType(edgeType, [Attributes.Edge.color(VColor.red), Attributes.Edge.penwidth(3.0)])]),
            in: .engine)
        return (styled, edgeType)
    }

    /// Nodes, edges and groups are looked up by bare id — by edges, the editor
    /// and folding — so none may take an id another of them holds.
    func ensureElementIdFree(_ id: String) throws(VError) {
        if has(node: Node(string: id)) || has(edge: Edge.Id(string: id)) || has(group: Group(rawValue: id)) {
            throw VError.idCollision(id: id)
        }
    }

    public func add(node: Node, type: NodeType, group: Group? = nil) throws(VError) -> VGraph {
        if !has(node: node) { try ensureElementIdFree(node.description) }
        let newGraph = try graph.add(node: node, type: type)
        let result = updatedSelfWith(
            graph: newGraph, declarationOrder: declarationOrder.appending(ItemKey(.node, node.description)))
        if let group = group {
            return try result.addTo(group: group, node: node)
        }
        return result
    }

    public func add(edge: Edge, edgeType: EdgeType) throws(VError) -> VGraph {
        let fromAsGroup = Group(rawValue: edge.from.id)
        if has(group: fromAsGroup) {
            throw VError.edgeEndpointIsGroup(edge: edge.id, endpoint: fromAsGroup)
        }
        let toAsGroup = Group(rawValue: edge.to.id)
        if has(group: toAsGroup) {
            throw VError.edgeEndpointIsGroup(edge: edge.id, endpoint: toAsGroup)
        }
        let fromNt = try nodeType(for: edge.from)
        let toNt = try nodeType(for: edge.to)
        try ensureEdgeTypeFits(edgeType: edgeType, fromType: fromNt, toType: toNt)
        if !has(edge: edge.id) { try ensureElementIdFree(edge.id.description) }
        let newGraph = try graph.add(edge: edge, type: edgeType.id)
        return updatedSelfWith(
            graph: newGraph,
            declarationOrder: declarationOrder.appending(ItemKey(.edge, edge.id.description)))
    }

    func ensureEdgeTypeFits(edgeType: EdgeType, fromType: NodeType, toType: NodeType) throws(VError) {
        try ensureExists(nodeType: fromType)
        try ensureExists(nodeType: toType)
        try ensureExists(edgeType: edgeType.id)
        guard holds(edgeType, from: fromType, to: toType) else {
            throw VError.EdgeTypeWrong(edgeType.id, from: fromType, to: toType)
        }
    }

    public func delete(nodeType: NodeType) throws(VError) -> VGraph {
        let newGraph = try graph.delete(nodeType: nodeType)
        let newAds = ads.removeKey(Self.key(nodeType))
        return updatedSelfWith(graph: newGraph, ads: newAds)
    }

    public func delete(edgeType: EdgeType.Id) throws(VError) -> VGraph {
        let newGraph = try graph.delete(edgeType: edgeType)
        let newAds = ads.removeKey(Self.key(edgeType))
        return updatedSelfWith(graph: newGraph, ads: newAds)
    }

    public func setNodeType(node: Node, type: NodeType) throws(VError) -> VGraph {
        let newGraph = try graph.setNodeType(node: node, type: type)
        return updatedSelfWith(graph: newGraph).repruning(Self.key(node))
    }

    public func setEdgeType(edge: Edge.Id, type: EdgeType.Id) throws(VError) -> VGraph {
        let newGraph = try graph.setEdgeType(edge: edge, type: type)
        return updatedSelfWith(graph: newGraph).repruning(Self.key(edge))
    }

    /// Move an edge's endpoints, keeping its type and **dropping its own
    /// attributes**. Display-pipeline use only; see `TypedGraph.redirect(edge:)`.
    public func redirect(edge: Edge) throws(VError) -> VGraph {
        try ensureEdgeTypeFits(
            edgeType: try edgeType(for: edge.id), fromType: try nodeType(for: edge.from), toType: try nodeType(for: edge.to))
        let newGraph = try graph.redirect(edge: edge)
        return updatedSelfWith(graph: newGraph)
    }

    public func removeFromSubgraph(node: Node) -> VGraph {
        let newGroupStructure = groupStructure.removeFromGroup(node: node)
        return updatedSelfWith(subgraphStructure: newGroupStructure)
    }

    public func removeFromSubgraph(group: Group) -> VGraph {
        let newGroupStructure = groupStructure.removeFromGroup(subGroup: group)
        return updatedSelfWith(subgraphStructure: newGroupStructure)
    }

    public func addTo(group: Group?, node: Node) throws(VError) -> VGraph {
        guard let subgraph = group else {
            return removeFromSubgraph(node: node)
        }
        try ensureExists(node: node)
        try ensureExists(group: subgraph)
        do {
            let newGroupStructure = try groupStructure.addTo(group: subgraph, node: node)
            return updatedSelfWith(subgraphStructure: newGroupStructure)
        } catch VError.nodeAlreadyInGroup(group: _, node: _) {
            return self
        }
    }

    public func addTo(group: Group?, childGroup: Group) throws(VError) -> VGraph {
        guard let subgraph = group else {
            return removeFromSubgraph(group: childGroup)
        }
        try ensureExists(group: subgraph)
        try ensureExists(group: childGroup)
        let newGroupStructure = try groupStructure.addTo(group: subgraph, childGroup: childGroup)
        return updatedSelfWith(subgraphStructure: newGroupStructure)
    }

    public func delete(group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        let newGroupStructure = try groupStructure.remove(group: group)
        var newGroups = groups
        newGroups.remove(object: group)
        let newAds = ads.removeKey(Self.key(group))
        return updatedSelfWith(
            ads: newAds, subgraphStructure: newGroupStructure,
            declarationOrder: declarationOrder.removing(ItemKey(.group, group.id.description)))
    }

    public func add(group: Group, childOf: Group? = nil) throws(VError) -> VGraph {
        if !has(group: group) { try ensureElementIdFree(group.id.description) }
        let newGroupStructure = try groupStructure.add(group: group)
        let result = updatedSelfWith(
            subgraphStructure: newGroupStructure,
            declarationOrder: declarationOrder.appending(ItemKey(.group, group.id.description)))
        if let childOf = childOf {
            return try result.addTo(group: childOf, childGroup: group)
        }
        return result
    }

    public func add(notation: Notation) throws(VError) -> VGraph {
        return self  // might change in the future
    }

    public func ensureExists(node: Node) throws(VError) {
        guard graph.has(node: node) else {
            throw VError.nodeNotFound(node)
        }
    }

    public func ensureExists(group: Group) throws(VError) {
        guard has(group: group) else {
            throw VError.groupNotFound(group)
        }
    }

    public func ensureExists(nodeType: NodeType) throws(VError) {
        guard graph.has(nodeType: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
        }
    }

    public func ensureExists(edge id: Edge.Id) throws(VError) {
        guard graph.has(edge: id) else {
            throw VError.edgeNotFound(id)
        }
    }

    public func ensureExists(edgeType id: EdgeType.Id) throws(VError) {
        guard graph.has(edgeType: id) else {
            throw VError.edgeTypeNotFound(id)
        }
    }

    public func sort(nodes: [Node], by attr: Attribute) throws(VError) -> [Node] {
        let definition = attr.definition
        var keyed: [(node: Node, value: String)] = []
        for node in nodes {
            keyed.append((node: node, value: try resolvedValue(definition, for: Self.key(node))))
        }
        return keyed.sorted { left, right in
            (try? definition.isLessThan(left.value, right.value)) ?? false
        }.map { $0.node }
    }
}

extension VGraph {
    public init() {
        self.graph = TypedGraph()
        self.groupStructure = GroupStructure()
        // VGraph's own vocabulary; anything else is defined before it is written.
        self.ads = AttributeStore().define(Attributes.Node.definitions).define(Attributes.Edge.definitions)
            .define(Attributes.Group.definitions)
        self.declarationOrder = DeclarationOrder()
        self.notationDefinition = NotationDefinition()
        self.derivedEdgeTypes = [:]
        self.views = []
        self.readLayer = .model
    }

    public init(withMetaGraphAndAttributesFrom old: VGraph) {
        self.graph = TypedGraph(withMetagraphFrom: old.graph)
        self.ads = old.ads
        self.groupStructure = GroupStructure()
        self.declarationOrder = DeclarationOrder()
        self.notationDefinition = old.notationDefinition
        self.derivedEdgeTypes = old.derivedEdgeTypes
        self.views = []
        self.readLayer = .model
    }

    public init(
        base old: VGraph,
        graph: TypedGraph? = nil,
        ads: AttributeStore? = nil,
        groupStructure: GroupStructure? = nil,
        declarationOrder: DeclarationOrder? = nil,
        notationDefinition: NotationDefinition? = nil,
        views: [ViewDeclaration]? = nil,
        readLayer: AttributeLayer? = nil
    ) {
        self.init(
            graph: graph ?? old.graph,
            ads: ads ?? old.ads,
            groupStructure: groupStructure ?? old.groupStructure,
            declarationOrder: declarationOrder ?? old.declarationOrder,
            notationDefinition: notationDefinition ?? old.notationDefinition,
            derivedEdgeTypes: old.derivedEdgeTypes,
            views: views ?? old.views,
            readLayer: readLayer ?? old.readLayer)
    }

    public func updatedSelfWith(
        graph: TypedGraph? = nil,
        ads: AttributeStore? = nil,
        subgraphStructure: GroupStructure? = nil,
        declarationOrder: DeclarationOrder? = nil,
        notationDefinition: NotationDefinition? = nil
    ) -> VGraph {
        return VGraph(
            base: self,
            graph: graph,
            ads: ads,
            groupStructure: subgraphStructure,
            declarationOrder: declarationOrder,
            notationDefinition: notationDefinition)
    }
}

extension VGraph {
    /// Where the element was declared among all nodes, edges and groups.
    public func declarationPosition(of node: Node) -> Int {
        declarationOrder.position(of: ItemKey(.node, node.description)) ?? 0
    }

    public func declarationPosition(of edge: Edge.Id) -> Int {
        declarationOrder.position(of: ItemKey(.edge, edge.description)) ?? 0
    }

    public func declarationPosition(of group: Group) -> Int {
        declarationOrder.position(of: ItemKey(.group, group.id.description)) ?? 0
    }

    /// The group's own type; a plain group has none, whatever it sits inside.
    public func groupType(of group: Group) -> GroupType? {
        groupStructure.type(of: group)
    }

    public func typing(group: Group, as type: GroupType?) throws(VError) -> VGraph {
        updatedSelfWith(subgraphStructure: try groupStructure.typing(group, as: type))
            .repruning(Self.key(group))
    }

    public func nodeType(of group: Group) -> NodeType? {
        groupStructure.nodeType(of: group)
    }

    public func isDetailed(_ group: Group) -> Bool {
        nodeType(of: group) != nil
    }

    /// The namespaces a group's attributes come from, most specific first: a
    /// detailed node is a node before it is a group.
    public func attributeTargets(of group: Group) -> [AttributeTarget] {
        isDetailed(group) ? [.node, .graph] : [.graph]
    }

    /// Makes the group a detailed node of `type`, dropping any group type.
    public func typing(group: Group, as type: NodeType) throws(VError) -> VGraph {
        try updatedSelfWith(subgraphStructure: try groupStructure.typing(group, as: type))
            .startingFolded(type)
            .repruning(Self.key(group))
    }

    /// A detailed node starts folded, so decomposing changes no other view
    /// (ADR-0032). The default sits on the node type in the engine layer, where
    /// a notation, the model or a view can override it like any type value.
    /// Written when a detailing installs, so a view value on the type is
    /// judged against it before any node of the type is detailed.
    func startingFolded(_ type: NodeType) throws(VError) -> VGraph {
        let isFolded = Attributes.Group.isFolded
        guard ads.definitions[isFolded.id] != nil,
            (try attributes(in: .engine, of: Self.key(type)))[isFolded.id] == nil
        else { return self }
        return updatedSelfWith(
            ads: try ads.merging([(key: Self.key(type), attribute: isFolded(true))], into: .engine, chains: self))
    }

    func placing(edge: Edge.Id, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(.edge, edge.description), at: position))
    }

    func placing(node: Node, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(.node, node.description), at: position))
    }

    func placing(group: Group, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(.group, group.id.id), at: position))
    }
}

extension VGraph {
    /// A type's values across the notation layers.
    public func getAllAttributes(nodeType: NodeType) -> AttributeContainer {
        resolvedValues(for: Self.key(nodeType))
    }

    public func getAllAttributes(edgeType: EdgeType.Id) -> AttributeContainer {
        resolvedValues(for: Self.key(edgeType))
    }

    /// Everything set along the node's chain: itself, then its type.
    public func getAttributes(node: Node) throws(VError) -> AttributeContainer {
        guard graph.nodeType(for: node) != nil else {
            throw VError.nodeTypeNotFoundForNode(node)
        }
        return resolvedValues(for: Self.key(node))
    }

    /// What the model holds for the node, and nothing it inherits.
    public func getOwnAttributes(node: Node) -> AttributeContainer {
        ownValues(of: Self.key(node))
    }

    public func getOwnAttributes(edge: Edge.Id) -> AttributeContainer {
        ownValues(of: Self.key(edge))
    }

    public func getAttributes(edge: Edge.Id) throws(VError) -> AttributeContainer {
        guard graph.edgeType(for: edge) != nil else {
            throw VError.edgeTypeNotFoundForEdge(edge)
        }
        return resolvedValues(for: Self.key(edge))
    }

    /// The group's own values in the model; for the root group, the diagram's.
    public func getAttributes(group: Group) throws(VError) -> AttributeContainer {
        let key = Self.key(group)
        return key == .root ? resolvedValues(for: .root) : ownValues(of: key)
    }

    public func getGraphAttributes() throws(VError) -> AttributeContainer {
        resolvedValues(for: .root)
    }

    public var nodes: [Node] {
        return graph.nodes
    }

    public var edges: [Edge] {
        return graph.edges
    }

    public var nodeTypes: [NodeType] {
        return graph.nodeTypes
    }

    /// Uses the nodeTypeMapping directly for O(k) performance where k = number of distinct types.
    public var usedNodeTypes: [NodeType] {
        return graph.nodeTypeMapping.getAllOnes
    }

    public var groups: [Group] {
        // Filter out the internal root group from the public API
        let rootGroupId = Group(rawValue: rootGroup)
        return groupStructure.subGroups.filter { $0 != rootGroupId }
    }

    public var edgeTypes: [EdgeType] {
        return graph.edgeTypes
    }

    public func getDirectContent(group: Group) throws(VError) -> ([Group], [Node]) {
        return try groupStructure.getDirectContent(group: group)
    }

    public func getRootContent() throws(VError) -> ([Group], [Node]) {
        return try groupStructure.getDirectContent(group: Group(rawValue: rootGroup))
    }

    public func getDirectNodes(group: Group) throws(VError) -> [Node] {
        return try groupStructure.getDirectContent(group: group).1
    }

    public func getAllContent(group: Group) throws(VError) -> ([Group], [Node]) {
        return try groupStructure.getAllContent(group: group)
    }

    public func nodeType(for node: Node) throws(VError) -> NodeType {
        guard let nt = graph.nodeType(for: node) else {
            throw VError.nodeTypeNotFoundForNode(node)
        }
        return nt
    }

    public func edgeType(for edge: Edge.Id) throws(VError) -> EdgeType {
        guard let et = graph.edgeType(for: edge) else {
            throw VError.edgeTypeNotFoundForEdge(edge)
        }
        return et
    }

    public func edgeType(for edge: Edge) throws(VError) -> EdgeType {
        return try edgeType(for: edge.id)
    }

    public var counts: Counts {
        return Counts(graphCount: graph.counts, adsCount: ads.counts, groupCount: groupStructure.counts)
    }
}

extension VGraph: GetElement {
    public func has(node: Node) -> Bool {
        return graph.has(node: node)
    }

    public func has(edge: Edge.Id) -> Bool {
        return graph.has(edge: edge)
    }

    public func has(edgeType: EdgeType.Id) -> Bool {
        return graph.has(edgeType: edgeType)
    }

    public func get(edge: Edge.Id) -> Edge? {
        return graph.get(edge: edge)
    }

    public func has(nodeType: NodeType) -> Bool {
        return graph.has(nodeType: nodeType)
    }

    public func get(edgeType: EdgeType.Id) -> EdgeType? {
        return graph.edgeTypes.first { $0.id == edgeType }
    }

    public func get(edgeType: String) -> EdgeType? {
        return graph.edgeTypes.first { $0.id.description == edgeType }
    }

    public func has(nodeTypeName: String) -> Bool {
        return graph.has(nodeTypeName: nodeTypeName)
    }

    public func has(edgeTypeId: String) -> Bool {
        return graph.has(edgeTypeId: edgeTypeId)
    }

    public func has(group: Group) -> Bool {
        return groupStructure.has(group: group)
    }
}

extension VGraph: GetAttribute {

    public func get(node: Node, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(node: node) else {
            throw VError.nodeNotFound(node)
        }
        return try resolvedValue(attribute, for: Self.key(node))
    }

    public func get(nodeType: NodeType, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(nodeType: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
        }
        return try resolvedValue(attribute, for: Self.key(nodeType))
    }

    public func get(edge: Edge.Id, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(edge: edge) else {
            throw VError.edgeNotFound(edge)
        }
        return try resolvedValue(attribute, for: Self.key(edge))
    }

    public func get(edgeType: EdgeType.Id, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(edgeType: edgeType) else {
            throw VError.edgeTypeNotFound(edgeType)
        }
        return try resolvedValue(attribute, for: Self.key(edgeType))
    }

    public func get(group: Group, attribute: AttributeDefinition) throws(VError) -> String {
        try resolvedValue(attribute, for: Self.key(group))
    }

    /// The value set on the group or its type, or `nil` when only the default
    /// applies — which lets callers tell "someone set this" from "unset".
    public func explicitGroupAttribute(_ group: Group, _ attribute: AttributeDefinition) -> String? {
        explicitValue(attribute, for: Self.key(group))
    }

    public func explicitGroupTypeAttribute(_ groupType: GroupType, _ attribute: AttributeDefinition) -> String? {
        explicitValue(attribute, for: Self.key(groupType))
    }

    /// The group's `GroupStyle` as set on it or its type, else `nil` (caller
    /// uses its default).
    public func resolvedGroupStyle(_ group: Group) -> GroupStyle? {
        guard let raw = explicitGroupAttribute(group, Attributes.Group.groupStyle.asDefinition) else { return nil }
        return try? GroupStyle.fromString(raw)
    }

    /// The boundary an unfolded group draws, else `nil` (caller uses the generic
    /// cluster look). A detailed node has no `GroupStyle`: its look is its node type's.
    public func resolvedBoundaryChrome(_ group: Group) -> BoundaryChrome? {
        BoundaryChrome.inherited(
            boundary: explicitGroupAttribute(group, Attributes.Group.boundaryChrome.asDefinition)
                .flatMap { try? BoundaryChrome.fromString($0) },
            style: isDetailed(group) ? nil : resolvedGroupStyle(group))
    }

    public func get(graphAttribute: AttributeDefinition) throws(VError) -> String {
        try resolvedValue(graphAttribute, for: .root)
    }

    public func get<T: AttributeType>(graphAttribute: TypedAttributeDefinition<T>) throws(VError) -> String {
        return try get(graphAttribute: graphAttribute.asDefinition)
    }
}

extension VGraph: SetAttribute {

    public func set(node: Node, attribute: Attribute) throws(VError) -> VGraph {
        guard attribute.definition.target == .node else {
            throw VError.wrongTarget(is: attribute.definition.target, insteadOf: .node)
        }
        return try writing(attribute, for: Self.key(node))
    }

    public func set(nodeType: NodeType, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(nodeType))
    }

    public func set(groupType: GroupType, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(groupType))
    }

    public func set(edge: Edge.Id, attribute: Attribute) throws(VError) -> VGraph {
        guard attribute.definition.target == .edge else {
            throw VError.wrongTarget(is: attribute.definition.target, insteadOf: .edge)
        }
        return try writing(attribute, for: Self.key(edge))
    }

    public func set(edge: Edge, attribute: Attribute) throws(VError) -> VGraph {
        return try set(edge: edge.id, attribute: attribute)
    }

    public func set(group: Group?, attribute: Attribute) throws(VError) -> VGraph {
        guard let group = group else {
            return try set(graphAttribute: attribute)
        }
        try admit(attribute.definition, on: group)
        return try writing(attribute, for: Self.key(group))
    }

    /// The boundary the pipeline draws around an unfolded group, in the view
    /// graph. A detailed node's `backgroundcolor` is its card's, so its boundary
    /// fill is stamped past the namespace guard; nobody writes it in VGL.
    func stamping(group: Group, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(group))
    }

    /// A detailed node is a node first: a group attribute that a node attribute
    /// shadows would be stored where nothing reads it.
    private func admit(_ definition: AttributeDefinition, on group: Group) throws(VError) {
        guard isDetailed(group) else {
            guard definition.target == .graph else {
                throw VError.wrongTarget(is: definition.target, insteadOf: .graph)
            }
            return
        }
        switch definition.target {
        case .node: return
        case .edge: throw VError.wrongTarget(is: .edge, insteadOf: .node)
        case .graph:
            let key = definition.vglKey
            if ads.definitions.values.contains(where: { $0.target == .node && $0.vglKey == key }) {
                throw VError.wrongTarget(is: .graph, insteadOf: .node)
            }
        }
    }

    public func set(edgeType: EdgeType.Id, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: Self.key(edgeType))
    }

    public func set(edgeType: EdgeType, attribute: Attribute) throws(VError) -> VGraph {
        return try set(edgeType: edgeType.id, attribute: attribute)
    }

    public func set(graphAttribute: Attribute) throws(VError) -> VGraph {
        try writing(graphAttribute, for: .root)
    }

    /// The graph's loops, shortest first and capped (ADR-0028).
    ///
    /// A derived edge is drawing, not the model: it could close a loop that the
    /// model does not have.
    public func findLoops() -> TypedGraph.Graph.LoopSearch {
        var judged = graph
        for edge in edges where (try? edgeType(for: edge))?.isDerived == true {
            if let without = try? judged.delete(edge: edge.id) { judged = without }
        }
        return judged.findLoops()
    }
}

extension VGraph: AttributeRegistry {
    public func define(_ attribute: AttributeDefinition) throws(VError) -> Self {
        let newAds = try ads.define(attribute)
        return updatedSelfWith(ads: newAds)
    }

    public func define<T: AttributeType>(_ attribute: TypedAttributeDefinition<T>) throws(VError) -> Self {
        return try define(attribute.asDefinition)
    }

    public func find(attributeByName: String, for target: AttributeTarget) -> (AttributeDefinition)? {
        find(attributeAmong: [(name: attributeByName, target: target)])
    }

    /// Tries each name in its namespace, in order. An exact name in a later
    /// namespace beats a loose match in an earlier one.
    public func find(attributeAmong candidates: [(name: String, target: AttributeTarget)]) -> AttributeDefinition? {
        for candidate in candidates {
            if let exact = findExactly(attributeByName: candidate.name, for: candidate.target) { return exact }
        }
        for candidate in candidates {
            if let loose = ads.definitions.values.first(where: {
                $0.name.containsCaseInsensitive(candidate.name) && $0.target == candidate.target
            }) {
                return loose
            }
        }
        return nil
    }

    private func findExactly(attributeByName: String, for target: AttributeTarget) -> AttributeDefinition? {
        let lowered = attributeByName.lowercased()
        if let exact = ads.definitions.values.first(where: {
            $0.name.lowercased() == lowered && $0.target == target
        }) {
            return exact
        }
        return ads.definitions.values.first { $0.vglKey == lowered && $0.target == target }
    }

    public func find(attributeId: Attribute.Id) -> (AttributeDefinition)? {
        ads.definitions[attributeId]
    }
}

extension VGraph {

    public func calculateNodeSize(_ node: Node) throws(VError) -> VGraph {
        // Get text size (should have been computed by NodeTextDimensionStep)
        let nodeTextSize = (try? get(node: node, attribute: Attributes.Node.nodeTextSize)) ?? VSize.zero

        // Get node type and its style — try? form (untyped `catch` restricted in Embedded).
        let style: NodeStyleLayout = {
            guard let nt = try? nodeType(for: node),
                let s: NodeStyleLayout = try? get(nodeType: nt, attribute: Attributes.Node.style)
            else { return NodeStyleLayout.bareText }
            return s
        }()

        let nodeSize = style.calculateSizeWithText(nodeTextSize)

        var result = try set(
            node: node,
            attribute: Attributes.Node.width.attribute(nodeSize.width)
        )
        result = try result.set(
            node: node,
            attribute: Attributes.Node.height.attribute(nodeSize.height)
        )
        return result
    }

    public func calculateNodeSizes() throws(VError) -> VGraph {
        var result = self
        for node in result.nodes {
            result = try result.calculateNodeSize(node)
        }
        return result
    }
}
