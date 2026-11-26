public struct VGraph {
    private let graph: TypedGraph
    let attributeStore: AttributeStore
    public let groupStructure: GroupStructure
    private let declarationOrder: DeclarationOrder
    public let notationDefinition: NotationDefinition
    /// Display edge types and the type each stands for (ADR-0030).
    let derivedEdgeTypes: [EdgeType.Id: EdgeType.Id]
    /// Declaration order is the export order; each view is a layer of `attributeStore`.
    public let views: [ViewDeclaration]
    /// Kept from loading for the quality report, as `NotationDefinition.keysGivenTwice` is.
    let attributesGivenTwice: [AttributeGivenTwice]
    let readLayer: AttributeLayer

    public var typedGraph: TypedGraph {
        return graph
    }

    public var attributeDefinitions: AttributeDefContainer {
        return attributeStore.definitions
    }

    public init(
        graph: TypedGraph,
        attributeStore: AttributeStore,
        groupStructure: GroupStructure,
        declarationOrder: DeclarationOrder = DeclarationOrder(),
        notationDefinition: NotationDefinition = NotationDefinition(),
        derivedEdgeTypes: [EdgeType.Id: EdgeType.Id] = [:],
        views: [ViewDeclaration] = [],
        attributesGivenTwice: [AttributeGivenTwice] = [],
        readLayer: AttributeLayer = .model
    ) {
        self.graph = graph
        self.attributeStore = attributeStore
        self.groupStructure = groupStructure
        self.declarationOrder = declarationOrder
        self.notationDefinition = notationDefinition
        self.derivedEdgeTypes = derivedEdgeTypes
        self.views = views
        self.attributesGivenTwice = attributesGivenTwice
        self.readLayer = readLayer
    }

    /// Adds a display edge type standing for `original` between other node
    /// types, as a folded edge needs. It holds no values: its chain continues
    /// to the original, so the original's styling reaches it.
    public func deriving(edgeType: EdgeType, from original: EdgeType.Id) throws(VError) -> VGraph {
        let added = try adding(edgeType: edgeType)
        return VGraph(
            graph: added.graph, attributeStore: added.attributeStore, groupStructure: added.groupStructure,
            declarationOrder: added.declarationOrder, notationDefinition: added.notationDefinition,
            derivedEdgeTypes: derivedEdgeTypes.merging([edgeType.id: original]) { _, new in new },
            views: added.views, attributesGivenTwice: added.attributesGivenTwice, readLayer: added.readLayer)
    }

    /// Its edges go first, through `deleting(edge:)`: an edge left in the store or
    /// the declaration order would hand its label to the next edge given its id.
    public func deleting(node: Node) throws(VError) -> VGraph {
        let withoutEdges = try edges(at: node).folding(self) { (result, edge) throws(VError) in
            try result.deleting(edge: edge.id)
        }
        return withoutEdges.updatedSelfWith(
            graph: try withoutEdges.graph.deleting(node: node),
            attributeStore: withoutEdges.attributeStore.removingKey(ItemKey(node)),
            groupStructure: withoutEdges.groupStructure.removingFromGroup(node: node),
            declarationOrder: withoutEdges.declarationOrder.removing(ItemKey(node)))
    }

    public func deleting(edge: Edge.Id) throws(VError) -> VGraph {
        let newGraph = try graph.deleting(edge: edge)
        let newAttributeStore = attributeStore.removingKey(ItemKey(edge))
        return updatedSelfWith(
            graph: newGraph, attributeStore: newAttributeStore, declarationOrder: declarationOrder.removing(ItemKey(edge)))
    }

    public func adding(nodeType: String) throws(VError) -> VGraph {
        return try adding(nodeType: NodeType(rawValue: nodeType))
    }

    public func adding(nodeType: NodeType) throws(VError) -> VGraph {
        updatedSelfWith(graph: try graph.adding(nodeType: nodeType))
    }

    public func adding(groupType: GroupType) -> VGraph {
        updatedSelfWith(notationDefinition: notationDefinition.registering(groupType))
    }

    public func adding(icon name: String, artwork: IconArtwork) -> VGraph {
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

    /// Styled as it is registered, so a mistyped group carries its red frame
    /// wherever `resolvedGroupStyle` reaches it. Mirrors `ensuringUnknownNodeType`.
    public func ensuringUnknownGroupType() throws(VError) -> VGraph {
        if has(groupTypeName: GroupType.unknownPrefix) {
            return self
        }
        let style = GroupStyle(folded: .empty, unfolded: GroupType.unknownFrame)
        return try placing(
            NotationContent(groupTypes: [.unknown], values: [.groupType(.unknown, [Attributes.Group.groupStyle(style)])]),
            in: .engine)
    }

    public func adding(edgeType: String, from: String, to: String) throws(VError) -> VGraph {
        return try adding(edgeType: EdgeType(string: edgeType, from: from, to: to))
    }

    public func adding(edgeType: EdgeType) throws(VError) -> VGraph {
        let newGraph = try graph.adding(edgeType: edgeType)
        return updatedSelfWith(graph: newGraph)
    }

    public func ensuringUnknownNodeType() throws(VError) -> VGraph {
        updatedSelfWith(graph: try graph.ensuringUnknownNodeType())
    }

    public func ensuringUnknownEdgeType(from: NodeType, to: NodeType) throws(VError) -> (VGraph, EdgeType) {
        let unknownEdgeType = EdgeType.unknown(from: from, to: to)

        if let existing = get(edgeType: unknownEdgeType.id) {
            return (self, existing)
        }

        let (newGraph, edgeType) = try graph.ensuringUnknownEdgeType(from: from, to: to)
        let styled = try updatedSelfWith(graph: newGraph).placing(
            NotationContent(values: [.edgeType(edgeType, [Attributes.Edge.color(VColor.red), Attributes.Edge.penwidth(3.0)])]),
            in: .engine)
        return (styled, edgeType)
    }

    /// Nodes, edges and groups are looked up by bare id — by edges, the editor
    /// and folding — so none may take an id another of them holds.
    func ensureElementIdFree(_ id: String) throws(VError) {
        if has(node: Node(rawValue: id)) || has(edge: Edge.Id(rawValue: id)) || has(group: Group(rawValue: id)) {
            throw VError.idCollision(id: id)
        }
    }

    public func adding(node: Node, type: NodeType, group: Group? = nil) throws(VError) -> VGraph {
        if !has(node: node) { try ensureElementIdFree(node.description) }
        let newGraph = try graph.adding(node: node, type: type)
        let result = updatedSelfWith(
            graph: newGraph, declarationOrder: declarationOrder.appending(ItemKey(node)))
        if let group = group {
            return try result.addingTo(group: group, node: node)
        }
        return result
    }

    public func adding(edge: Edge, edgeType: EdgeType) throws(VError) -> VGraph {
        for end in [edge.from, edge.to] where has(group: Group(rawValue: end.id)) {
            throw VError.edgeEndpointIsGroup(edge: edge.id, endpoint: Group(rawValue: end.id))
        }
        try ensureEdgeTypeFits(edgeType: edgeType, fromType: try nodeType(for: edge.from), toType: try nodeType(for: edge.to))
        if !has(edge: edge.id) { try ensureElementIdFree(edge.id.description) }
        let newGraph = try graph.adding(edge: edge, type: edgeType.id)
        return updatedSelfWith(
            graph: newGraph,
            declarationOrder: declarationOrder.appending(ItemKey(edge.id)))
    }

    func ensureEdgeTypeFits(edgeType: EdgeType, fromType: NodeType, toType: NodeType) throws(VError) {
        try ensureExists(nodeType: fromType)
        try ensureExists(nodeType: toType)
        try ensureExists(edgeType: edgeType.id)
        guard holds(edgeType, from: fromType, to: toType) else {
            throw VError.edgeTypeDoesNotFit(edgeType.id, from: fromType, to: toType)
        }
    }

    public func deleting(nodeType: NodeType) throws(VError) -> VGraph {
        let newGraph = try graph.deleting(nodeType: nodeType)
        let newAttributeStore = attributeStore.removingKey(ItemKey(nodeType))
        return updatedSelfWith(graph: newGraph, attributeStore: newAttributeStore)
    }

    public func deleting(edgeType: EdgeType.Id) throws(VError) -> VGraph {
        let newGraph = try graph.deleting(edgeType: edgeType)
        let newAttributeStore = attributeStore.removingKey(ItemKey(edgeType))
        return updatedSelfWith(graph: newGraph, attributeStore: newAttributeStore)
    }

    public func settingNodeType(node: Node, type: NodeType) throws(VError) -> VGraph {
        let newGraph = try graph.settingNodeType(node: node, type: type)
        return updatedSelfWith(graph: newGraph).repruning(ItemKey(node))
    }

    public func settingEdgeType(edge: Edge.Id, type: EdgeType.Id) throws(VError) -> VGraph {
        let newGraph = try graph.settingEdgeType(edge: edge, type: type)
        return updatedSelfWith(graph: newGraph).repruning(ItemKey(edge))
    }

    /// Move an edge's endpoints, keeping its id, type, values and place.
    /// Display-pipeline use only; a command uses `reattaching(edge:from:to:edgeType:)`,
    /// which goes through `adding(edge:)` and its checks.
    public func redirecting(edge: Edge) throws(VError) -> VGraph {
        try ensureEdgeTypeFits(
            edgeType: try edgeType(for: edge.id), fromType: try nodeType(for: edge.from), toType: try nodeType(for: edge.to))
        let newGraph = try graph.redirecting(edge: edge)
        return updatedSelfWith(graph: newGraph)
    }

    public func addingTo(group: Group, node: Node) throws(VError) -> VGraph {
        try ensureExists(node: node)
        try ensureExists(group: group)
        return updatedSelfWith(groupStructure: try groupStructure.addingTo(group: group, node: node))
    }

    public func addingTo(group: Group, childGroup: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        try ensureExists(group: childGroup)
        return updatedSelfWith(groupStructure: try groupStructure.addingTo(group: group, childGroup: childGroup))
    }

    public func deleting(group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        let newGroupStructure = try groupStructure.removing(group: group)
        let newAttributeStore = attributeStore.removingKey(ItemKey(group))
        return updatedSelfWith(
            attributeStore: newAttributeStore, groupStructure: newGroupStructure,
            declarationOrder: declarationOrder.removing(ItemKey(group)))
    }

    public func adding(group: Group, childOf: Group? = nil) throws(VError) -> VGraph {
        if !has(group: group) { try ensureElementIdFree(group.id.description) }
        let newGroupStructure = groupStructure.adding(group: group)
        let result = updatedSelfWith(
            groupStructure: newGroupStructure,
            declarationOrder: declarationOrder.appending(ItemKey(group)))
        if let childOf = childOf {
            return try result.addingTo(group: childOf, childGroup: group)
        }
        return result
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

    /// For an edit of an edge that is not there: refused, not skipped, since a
    /// graph handed back unchanged reads as success.
    func existingEdge(_ id: Edge.Id) throws(VError) -> Edge {
        guard let edge = graph.get(edge: id) else {
            throw VError.edgeNotFound(id)
        }
        return edge
    }

    public func ensureExists(edgeType id: EdgeType.Id) throws(VError) {
        guard graph.has(edgeType: id) else {
            throw VError.edgeTypeNotFound(id)
        }
    }

}

extension VGraph {
    public init() {
        self.graph = TypedGraph()
        self.groupStructure = GroupStructure()
        // Anything beyond VGraph's own vocabulary is defined before it is written.
        self.attributeStore = AttributeStore(definitions: Attributes.standard)
        self.declarationOrder = DeclarationOrder()
        self.notationDefinition = NotationDefinition()
        self.derivedEdgeTypes = [:]
        self.views = []
        self.attributesGivenTwice = []
        self.readLayer = .model
    }

    public init(
        base old: VGraph,
        graph: TypedGraph? = nil,
        attributeStore: AttributeStore? = nil,
        groupStructure: GroupStructure? = nil,
        declarationOrder: DeclarationOrder? = nil,
        notationDefinition: NotationDefinition? = nil,
        views: [ViewDeclaration]? = nil,
        attributesGivenTwice: [AttributeGivenTwice]? = nil,
        readLayer: AttributeLayer? = nil
    ) {
        self.init(
            graph: graph ?? old.graph,
            attributeStore: attributeStore ?? old.attributeStore,
            groupStructure: groupStructure ?? old.groupStructure,
            declarationOrder: declarationOrder ?? old.declarationOrder,
            notationDefinition: notationDefinition ?? old.notationDefinition,
            derivedEdgeTypes: old.derivedEdgeTypes,
            views: views ?? old.views,
            attributesGivenTwice: attributesGivenTwice ?? old.attributesGivenTwice,
            readLayer: readLayer ?? old.readLayer)
    }

    public func updatedSelfWith(
        graph: TypedGraph? = nil,
        attributeStore: AttributeStore? = nil,
        groupStructure: GroupStructure? = nil,
        declarationOrder: DeclarationOrder? = nil,
        notationDefinition: NotationDefinition? = nil
    ) -> VGraph {
        return VGraph(
            base: self,
            graph: graph,
            attributeStore: attributeStore,
            groupStructure: groupStructure,
            declarationOrder: declarationOrder,
            notationDefinition: notationDefinition)
    }
}

extension VGraph {
    /// Where the element was declared among all nodes, edges and groups.
    public func declarationPosition(of node: Node) -> Int {
        declarationOrder.position(of: ItemKey(node)) ?? 0
    }

    public func declarationPosition(of edge: Edge.Id) -> Int {
        declarationOrder.position(of: ItemKey(edge)) ?? 0
    }

    public func declarationPosition(of group: Group) -> Int {
        declarationOrder.position(of: ItemKey(group)) ?? 0
    }

    /// Export and drawing follow the document, not the store's own order.
    public func inDeclarationOrder(_ nodes: [Node]) -> [Node] {
        sortedByDeclaration(nodes) { declarationPosition(of: $0) }
    }

    public func inDeclarationOrder(_ edges: [Edge]) -> [Edge] {
        sortedByDeclaration(edges) { declarationPosition(of: $0.id) }
    }

    public func inDeclarationOrder(_ groups: [Group]) -> [Group] {
        sortedByDeclaration(groups) { declarationPosition(of: $0) }
    }

    private func sortedByDeclaration<Element>(_ elements: [Element], position: (Element) -> Int) -> [Element] {
        elements.map { (element: $0, position: position($0)) }.sorted { $0.position < $1.position }.map { $0.element }
    }

    func edges(at node: Node) -> [Edge] {
        graph.edges(at: node)
    }

    func edgesInDeclarationOrder(at node: Node) -> [Edge] {
        inDeclarationOrder(edges(at: node))
    }

    /// The group's own type; a plain group has none, whatever it sits inside.
    public func groupType(of group: Group) -> GroupType? {
        groupStructure.type(of: group)
    }

    public func typing(group: Group, as type: GroupType?) throws(VError) -> VGraph {
        updatedSelfWith(groupStructure: try groupStructure.typing(group, as: type))
            .repruning(ItemKey(group))
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
        isDetailed(group) ? [.node, .group] : [.group]
    }

    /// Makes the group a detailed node of `type`, dropping any group type.
    public func typing(group: Group, as type: NodeType) throws(VError) -> VGraph {
        try updatedSelfWith(groupStructure: try groupStructure.typing(group, as: type))
            .startingFolded(type)
            .repruning(ItemKey(group))
    }

    /// A detailed node starts folded, so decomposing changes no other view
    /// (ADR-0032). The default sits on the node type in the engine layer, where
    /// a notation, the model or a view can override it like any type value.
    /// Written when a detailing installs, so a view value on the type is
    /// judged against it before any node of the type is detailed.
    func startingFolded(_ type: NodeType) throws(VError) -> VGraph {
        let isFolded = Attributes.Group.isFolded
        guard attributeStore.definitions[isFolded.id] != nil,
            (try attributes(in: .engine, of: ItemKey(type)))[isFolded.id] == nil
        else { return self }
        return updatedSelfWith(
            attributeStore: try attributeStore.merging([(key: ItemKey(type), attribute: isFolded(true))], into: .engine, chains: self))
    }

    func placing(edge: Edge.Id, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(edge), at: position))
    }

    func placing(node: Node, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(node), at: position))
    }

    func placing(group: Group, at position: Int) -> VGraph {
        updatedSelfWith(declarationOrder: declarationOrder.placing(ItemKey(group), at: position))
    }
}

extension VGraph {
    /// A type's values across the notation layers.
    public func attributes(nodeType: NodeType) -> AttributeContainer {
        resolvedValues(for: ItemKey(nodeType))
    }

    public func attributes(edgeType: EdgeType.Id) -> AttributeContainer {
        resolvedValues(for: ItemKey(edgeType))
    }

    /// Everything set along the node's chain: itself, then its type.
    public func attributes(node: Node) throws(VError) -> AttributeContainer {
        guard graph.nodeType(for: node) != nil else {
            throw VError.nodeTypeNotFoundForNode(node)
        }
        return resolvedValues(for: ItemKey(node))
    }

    /// What the model holds for the node, and nothing it inherits.
    public func ownAttributes(node: Node) -> AttributeContainer {
        ownValues(of: ItemKey(node))
    }

    public func ownAttributes(edge: Edge.Id) -> AttributeContainer {
        ownValues(of: ItemKey(edge))
    }

    public func attributes(edge: Edge.Id) throws(VError) -> AttributeContainer {
        guard graph.edgeType(for: edge) != nil else {
            throw VError.edgeTypeNotFoundForEdge(edge)
        }
        return resolvedValues(for: ItemKey(edge))
    }

    /// The group's own values in the model; for the root group, the diagram's.
    public func attributes(group: Group) -> AttributeContainer {
        let key = ItemKey(group)
        return key == .root ? resolvedValues(for: .root) : ownValues(of: key)
    }

    public func graphAttributes() -> AttributeContainer {
        resolvedValues(for: .root)
    }

    public var nodes: [Node] {
        return graph.nodes
    }

    /// In the order `nodes` lists them, so whatever reports on them is stable.
    func nodes(ofType type: NodeType) -> [Node] {
        nodes.filter { (try? nodeType(for: $0)) == type }
    }

    public var edges: [Edge] {
        return graph.edges
    }

    public var nodeTypes: [NodeType] {
        return graph.nodeTypes
    }

    /// In declaration order, so whatever reports on them is stable.
    public var usedNodeTypes: [NodeType] {
        nodeTypes.filter { graph.nodeTypeMapping.getMany(one: $0) != nil }
    }

    /// Without the root group, which is the diagram rather than a group in it.
    public var groups: [Group] {
        groupStructure.allGroups.filter { $0 != Group.root }
    }

    public var edgeTypes: [EdgeType] {
        return graph.edgeTypes
    }

    public func directContent(of group: Group) throws(VError) -> (groups: [Group], nodes: [Node]) {
        return try groupStructure.directContent(of: group)
    }

    public func allContent(of group: Group) throws(VError) -> (groups: [Group], nodes: [Node]) {
        return try groupStructure.allContent(of: group)
    }

    public func nodeType(for node: Node) throws(VError) -> NodeType {
        guard let type = graph.nodeType(for: node) else {
            throw VError.nodeTypeNotFoundForNode(node)
        }
        return type
    }

    public func edgeType(for edge: Edge.Id) throws(VError) -> EdgeType {
        guard let type = graph.edgeType(for: edge) else {
            throw VError.edgeTypeNotFoundForEdge(edge)
        }
        return type
    }

    public func edgeType(for edge: Edge) throws(VError) -> EdgeType {
        return try edgeType(for: edge.id)
    }
}

extension VGraph {
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

extension VGraph {

    public func get(node: Node, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(node: node) else {
            throw VError.nodeNotFound(node)
        }
        return try resolvedValue(attribute, for: ItemKey(node))
    }

    public func get(nodeType: NodeType, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(nodeType: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
        }
        return try resolvedValue(attribute, for: ItemKey(nodeType))
    }

    public func get(edge: Edge.Id, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(edge: edge) else {
            throw VError.edgeNotFound(edge)
        }
        return try resolvedValue(attribute, for: ItemKey(edge))
    }

    public func get(edgeType: EdgeType.Id, attribute: AttributeDefinition) throws(VError) -> String {
        guard has(edgeType: edgeType) else {
            throw VError.edgeTypeNotFound(edgeType)
        }
        return try resolvedValue(attribute, for: ItemKey(edgeType))
    }

    public func get(group: Group, attribute: AttributeDefinition) throws(VError) -> String {
        try resolvedValue(attribute, for: ItemKey(group))
    }

    public func get<T>(node: Node, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        try T.fromString(get(node: node, attribute: attribute.asDefinition))
    }

    public func get<T>(edge: Edge.Id, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        try T.fromString(get(edge: edge, attribute: attribute.asDefinition))
    }

    public func get<T>(nodeType: NodeType, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        try T.fromString(get(nodeType: nodeType, attribute: attribute.asDefinition))
    }

    public func get<T>(edgeType: EdgeType.Id, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        try T.fromString(get(edgeType: edgeType, attribute: attribute.asDefinition))
    }

    public func get<T>(group: Group, attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        try T.fromString(get(group: group, attribute: attribute.asDefinition))
    }

    /// The value set on the group or its type, or `nil` when only the default
    /// applies — which lets callers tell "someone set this" from "unset".
    func explicitGroupAttribute(_ group: Group, _ attribute: AttributeDefinition) -> String? {
        explicitValue(attribute, for: ItemKey(group))
    }

    /// The group's `GroupStyle` as set on it or its type, else `nil` (caller
    /// uses its default).
    public func resolvedGroupStyle(_ group: Group) -> GroupStyle? {
        guard let raw = explicitGroupAttribute(group, Attributes.Group.groupStyle.asDefinition) else { return nil }
        return try? GroupStyle.fromString(raw)
    }

    /// The frame an unfolded group draws, else `nil` (caller uses the plain-group
    /// look). A detailed node has no `GroupStyle`: its look is its node type's.
    public func resolvedFrame(_ group: Group) -> GroupFrame? {
        GroupFrame.inherited(
            own: explicitGroupAttribute(group, Attributes.Group.frame.asDefinition)
                .flatMap { try? GroupFrame.fromString($0) },
            style: isDetailed(group) ? nil : resolvedGroupStyle(group))
    }

    public func get(graphAttribute: AttributeDefinition) throws(VError) -> String {
        try resolvedValue(graphAttribute, for: .root)
    }

    public func get<T: AttributeType>(graphAttribute: TypedAttributeDefinition<T>) throws(VError) -> String {
        return try get(graphAttribute: graphAttribute.asDefinition)
    }

    public func get<T: AttributeType>(attribute: TypedAttributeDefinition<T>) throws(VError) -> T {
        return try T.fromString(get(graphAttribute: attribute.asDefinition))
    }
}

extension VGraph {

    public func setting(node: Node, attribute: Attribute) throws(VError) -> VGraph {
        guard attribute.definition.target == .node else {
            throw VError.wrongTarget(is: attribute.definition.target, insteadOf: .node)
        }
        return try writing(attribute, for: ItemKey(node))
    }

    public func setting(nodeType: NodeType, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: ItemKey(nodeType))
    }

    public func setting(groupType: GroupType, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: ItemKey(groupType))
    }

    public func setting(edge: Edge.Id, attribute: Attribute) throws(VError) -> VGraph {
        guard attribute.definition.target == .edge else {
            throw VError.wrongTarget(is: attribute.definition.target, insteadOf: .edge)
        }
        return try writing(attribute, for: ItemKey(edge))
    }

    public func setting(edge: Edge, attribute: Attribute) throws(VError) -> VGraph {
        return try setting(edge: edge.id, attribute: attribute)
    }

    public func setting(edge: Edge.Id, def: AttributeDefinition, value: String) throws(VError) -> VGraph {
        return try setting(edge: edge, attribute: Attribute(definition: def, value: value))
    }

    public func setting(group: Group, attribute: Attribute) throws(VError) -> VGraph {
        try admit(attribute.definition, on: group)
        return try writing(attribute, for: ItemKey(group))
    }

    /// The frame the pipeline draws around an unfolded group, in the view
    /// graph. A detailed node's `backgroundcolor` is its card's, so its frame
    /// fill is stamped past the namespace guard; nobody writes it in VGL.
    func stamping(group: Group, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: ItemKey(group))
    }

    /// A detailed node is a node first: a group attribute that a node attribute
    /// shadows would be stored where nothing reads it.
    private func admit(_ definition: AttributeDefinition, on group: Group) throws(VError) {
        guard isDetailed(group) else {
            guard definition.target == .group else {
                throw VError.wrongTarget(is: definition.target, insteadOf: .group)
            }
            return
        }
        switch definition.target {
        case .node: return
        case .edge: throw VError.wrongTarget(is: .edge, insteadOf: .node)
        case .group:
            let key = definition.vglKey
            if attributeStore.definitions.values.contains(where: { $0.target == .node && $0.vglKey == key }) {
                throw VError.wrongTarget(is: .group, insteadOf: .node)
            }
        }
    }

    public func setting(edgeType: EdgeType.Id, attribute: Attribute) throws(VError) -> VGraph {
        try writing(attribute, for: ItemKey(edgeType))
    }

    public func setting(edgeType: EdgeType, attribute: Attribute) throws(VError) -> VGraph {
        return try setting(edgeType: edgeType.id, attribute: attribute)
    }

    public func setting(graphAttribute: Attribute) throws(VError) -> VGraph {
        try writing(graphAttribute, for: .root)
    }
}

extension VGraph {
    /// The graph's loops, shortest first and capped (ADR-0028).
    ///
    /// A derived edge is drawing, not the model: it could close a loop that the
    /// model does not have.
    public func findLoops() -> TypedGraph.Graph.LoopSearch {
        let derived = edges.filter { (try? edgeType(for: $0))?.isDerived == true }
        let modelOnly = derived.reduce(graph) { judged, edge in (try? judged.deleting(edge: edge.id)) ?? judged }
        return modelOnly.findLoops()
    }
}

extension VGraph {
    public func defining(_ attribute: AttributeDefinition) throws(VError) -> Self {
        let newAttributeStore = try attributeStore.defining(attribute)
        return updatedSelfWith(attributeStore: newAttributeStore)
    }

    public func defining<T: AttributeType>(_ attribute: TypedAttributeDefinition<T>) throws(VError) -> Self {
        return try defining(attribute.asDefinition)
    }

    public func find(attributeByName: String, for target: AttributeTarget) -> AttributeDefinition? {
        find(attributeAmong: [(name: attributeByName, target: target)])
    }

    /// Tries each name in its namespace, in order. An exact name in a later
    /// namespace beats a loose match in an earlier one.
    public func find(attributeAmong candidates: [(name: String, target: AttributeTarget)]) -> AttributeDefinition? {
        for candidate in candidates {
            if let exact = findExactly(attributeByName: candidate.name, for: candidate.target) { return exact }
        }
        for candidate in candidates {
            if let loose = findLoosely(attributeByName: candidate.name, for: candidate.target) { return loose }
        }
        return nil
    }

    /// Only a name that fits one attribute: picking among several would pick by
    /// the dictionary's order, which changes from run to run.
    private func findLoosely(attributeByName name: String, for target: AttributeTarget) -> AttributeDefinition? {
        let fitting = attributeStore.definitions.values.filter {
            $0.target == target && $0.name.containsCaseInsensitive(name)
        }
        return fitting.count == 1 ? fitting.first : nil
    }

    private func findExactly(attributeByName: String, for target: AttributeTarget) -> AttributeDefinition? {
        let lowered = attributeByName.lowercased()
        if let exact = attributeStore.definitions.values.first(where: {
            $0.name.lowercased() == lowered && $0.target == target
        }) {
            return exact
        }
        return attributeStore.definitions.values.first { $0.vglKey == lowered && $0.target == target }
    }
}
