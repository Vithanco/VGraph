public struct TypedGraph: VProtocol {
    public typealias NodeTypeMapping = OneToManyLookup<NodeType, Node>
    public typealias EdgeTypeMapping = OneToManyLookup<EdgeType.Id, Edge.Id>
    public typealias Graph = WeightedGraph<_Node>
    public typealias MetaGraph = WeightedGraph<_NodeType>

    public let graph: Graph
    public let metagraph: MetaGraph
    public let nodeTypeMapping: NodeTypeMapping
    public let edgeTypeMapping: EdgeTypeMapping

    fileprivate init(graph: Graph, metagraph: MetaGraph, nodeTypes: NodeTypeMapping, edgeTypes: EdgeTypeMapping) {
        self.graph = graph
        self.metagraph = metagraph
        nodeTypeMapping = nodeTypes
        edgeTypeMapping = edgeTypes
    }

    public var nodes: [Node] {
        return graph.vertices
    }

    public var edges: [Edge] {
        return graph.getEdges()
    }

    public var nodeTypes: [NodeType] {
        return metagraph.vertices
    }

    public var edgeTypes: [EdgeType] {
        return metagraph.getEdges()
    }

    public func get(edge id: Edge.Id) -> Edge? {
        return graph.get(edge: id)
    }

    func getFirstEdge(from: Node, to: Node) -> Edge? {
        return graph.getEdges(from: from, to: to)?.first
    }

    public func nodeType(for id: Node) -> NodeType? {
        if let nt = nodeTypeMapping.getOne(many: id), metagraph.has(node: nt) {
            return nt
        }
        return nil
    }

    public func edgeType(for id: Edge.Id) -> EdgeType? {
        if let et = edgeTypeMapping.getOne(many: id) {
            return metagraph.get(edge: et)
        }
        return nil
    }

    public func has(node: Node) -> Bool {
        return graph.has(node: node)
    }

    public func has(nodeType: NodeType) -> Bool {
        return metagraph.has(node: nodeType)
    }

    public func has(edge id: Edge.Id) -> Bool {
        return graph.has(edge: id)
    }

    public func has(edgeType id: EdgeType.Id) -> Bool {
        return metagraph.has(edge: id)
    }

    public func get(edgeType id: EdgeType.Id) -> EdgeType? {
        return metagraph.get(edge: id)
    }

    public func has(nodeTypeName: String) -> Bool {
        return has(nodeType: NodeType(string: nodeTypeName))
    }

    public func has(edgeTypeId: String) -> Bool {
        return has(edgeType: EdgeType.Id(string: edgeTypeId))
    }

    public func delete(nodeType: NodeType) throws(VError) -> TypedGraph {
        // nil, not empty, is what an unused type answers — see delete(edgeType:).
        if !(nodeTypeMapping.getMany(one: nodeType) ?? []).isEmpty {
            throw VError.nodeTypeStillInUse(nodeType)
        }
        guard metagraph.has(node: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
        }
        let newMetagraph = metagraph.removeVertex(nodeType)
        let newNodeTypeMapping = nodeTypeMapping.remove(one: nodeType)

        return updatedSelfWith(metagraph: newMetagraph, nodeTypes: newNodeTypeMapping)
    }

    /// Remove a type no edge wears any more.
    ///
    /// `getMany` answers **nil** for a type nothing references — which is
    /// exactly the type that may be deleted — so nil and empty mean the same
    /// thing here. Reading nil as "not found" made this refuse every unused
    /// type, and there is no other kind it would accept.
    public func delete(edgeType: EdgeType.Id) throws(VError) -> TypedGraph {
        guard metagraph.get(edge: edgeType) != nil else {
            throw VError.edgeTypeNotFound(edgeType)
        }
        if let wearing = (edgeTypeMapping.getMany(one: edgeType) ?? []).first {
            throw VError.edgeTypeStillInUse(wearing)
        }
        let newMetagraph = metagraph.removeEdge(id: edgeType)
        let newEdgeTypeMapping = edgeTypeMapping.remove(one: edgeType)
        return updatedSelfWith(metagraph: newMetagraph, edgeTypes: newEdgeTypeMapping)
    }

    public func delete(node: Node) throws(VError) -> TypedGraph {
        guard graph.has(node: node) else {
            throw VError.nodeNotFound(node)
        }
        let newGraph = graph.removeVertex(node)

        guard nodeTypeMapping.getOne(many: node) != nil else {
            throw VError.nodeWithoutNodeType(node)
        }
        let newNodeTypeMapping = nodeTypeMapping.remove(many: node)
        return updatedSelfWith(graph: newGraph, nodeTypes: newNodeTypeMapping)
    }

    public func delete(edge id: Edge.Id) throws(VError) -> TypedGraph {
        guard let edge = graph.get(edge: id) else {
            throw VError.edgeNotFound(id)
        }
        let newGraph = graph.removeEdge(id: edge.id)
        let newEdgeTypeMapping = edgeTypeMapping.remove(many: id)
        return updatedSelfWith(graph: newGraph, edgeTypes: newEdgeTypeMapping)
    }

    public func add(notation: Notation) throws(VError) -> TypedGraph {
        return self
    }

    public func delete(notation: Notation) throws(VError) -> TypedGraph {
        return self
    }

    /// Move an edge's endpoints, keeping its type. **Drops the edge's own
    /// attributes** — the delete takes the whole attribute item with it — so this
    /// is for derived graphs only. `VGraph.reattach(edge:from:to:edgeType:)` is
    /// the OriginGraph version, which carries them across.
    public func redirect(edge: Edge) throws(VError) -> TypedGraph {
        guard let ed = edgeTypeMapping.getOne(many: edge.id) else {
            throw VError.edgeTypeNotFoundForEdge(edge.id)
        }
        return try delete(edge: edge.id).add(edge: edge, type: ed)
    }

    public func add(edge: Edge, type: EdgeType.Id) throws(VError) -> TypedGraph {
        guard !graph.has(edge: edge.id) else {
            throw VError.edgeAlreadyExists(edge.id)
        }
        guard graph.has(node: edge.from) else {
            throw VError.nodeNotFound(edge.from)
        }
        guard graph.has(node: edge.to) else {
            throw VError.nodeNotFound(edge.to)
        }
        // Whether the type holds the pair depends on detailings, which only VGraph knows.
        guard metagraph.has(edge: type) else {
            throw VError.edgeTypeNotFound(type)
        }

        let newGraph = graph.addEdge(edge)
        let newEdgeTypeMapping = edgeTypeMapping.add(many: edge.id, one: type)
        return updatedSelfWith(graph: newGraph, edgeTypes: newEdgeTypeMapping)
    }

    public func add(node: Node, type: NodeType) throws(VError) -> TypedGraph {
        try ensureExists(nodeType: type)
        guard !graph.has(node: node) else {
            throw VError.nodeAlreadyExists(node)
        }
        let newGraph = graph.addVertex(node)
        let newNodeTypeMapping = nodeTypeMapping.add(many: node, one: type)
        return updatedSelfWith(graph: newGraph, nodeTypes: newNodeTypeMapping)
    }

    public func add(nodeType: NodeType, notation: Notation) throws(VError) -> Self {
        if metagraph.vertices.contains(nodeType) {
            throw VError.nodeTypeAlreadyExists(nodeType)
        }
        let newMetagraph = metagraph.addVertex(nodeType)
        return updatedSelfWith(metagraph: newMetagraph)
    }

    public func add(edgeType: EdgeType, notation: Notation) throws(VError) -> TypedGraph {
        if metagraph.has(edge: edgeType.id) {
            throw VError.edgeTypeAlreadyExists(edgeType.id)
        }

        guard metagraph.has(node: edgeType.from) else {
            throw VError.nodeTypeNotFound(edgeType.from)
        }
        guard metagraph.has(node: edgeType.to) else {
            throw VError.nodeTypeNotFound(edgeType.to)
        }
        let newMetagraph = metagraph.addEdge(edgeType)
        return updatedSelfWith(metagraph: newMetagraph)
    }

    public func setNodeType(node: Node, type: NodeType) throws(VError) -> TypedGraph {
        try ensureExists(nodeType: type)

        let newNodeTypeMapping = nodeTypeMapping.add(many: node, one: type)
        return updatedSelfWith(nodeTypes: newNodeTypeMapping)
    }

    public func setEdgeType(edge: Edge.Id, type: EdgeType.Id) throws(VError) -> TypedGraph {
        try ensureExists(edgeType: type)
        let newEdgeTypeMapping = edgeTypeMapping.add(many: edge, one: type)
        return updatedSelfWith(edgeTypes: newEdgeTypeMapping)
    }

    public func ensureUnknownNodeType() throws(VError) -> TypedGraph {
        let unknownType = NodeType.unknown
        if has(nodeType: unknownType) {
            return self
        }
        return try add(nodeType: unknownType, notation: Notation(rawValue: "__UNKNOWN__"))
    }

    public func ensureUnknownEdgeType(from: NodeType, to: NodeType) throws(VError) -> (TypedGraph, EdgeType) {
        let unknownEdgeType = EdgeType.unknown(from: from, to: to)

        if let existing = get(edgeType: unknownEdgeType.id) {
            return (self, existing)
        }

        var result = self
        if !has(nodeType: from) {
            result = try result.add(nodeType: from, notation: Notation(rawValue: "__UNKNOWN__"))
        }
        if !has(nodeType: to) {
            result = try result.add(nodeType: to, notation: Notation(rawValue: "__UNKNOWN__"))
        }

        result = try result.add(edgeType: unknownEdgeType, notation: Notation(rawValue: "__UNKNOWN__"))
        return (result, unknownEdgeType)
    }

    func findLoops() -> Graph.LoopSearch {
        graph.findLoops()
    }

    public func ensureExists(node: Node) throws(VError) {
        guard graph.has(node: node) else {
            throw VError.nodeNotFound(node)
        }
    }

    public func ensureExists(nodeType: NodeType) throws(VError) {
        guard metagraph.has(node: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
        }
    }

    public func ensureExists(edge id: Edge.Id) throws(VError) {
        guard graph.has(edge: id) else {
            throw VError.edgeNotFound(id)
        }
    }

    public func ensureExists(edgeType id: EdgeType.Id) throws(VError) {
        guard metagraph.has(edge: id) else {
            throw VError.edgeTypeNotFound(id)
        }
    }
}

extension TypedGraph {
    public init() {
        graph = .init()
        metagraph = .init()
        nodeTypeMapping = .init()
        edgeTypeMapping = .init()
    }

    public init(withMetagraphFrom: TypedGraph) {
        graph = .init()
        metagraph = withMetagraphFrom.metagraph
        nodeTypeMapping = .init()
        edgeTypeMapping = .init()
    }

    public init(
        previous: TypedGraph, graph: Graph? = nil, metagraph: MetaGraph? = nil, nodeTypes: NodeTypeMapping? = nil,
        edgeTypes: EdgeTypeMapping? = nil
    ) {
        self.init(
            graph: graph ?? previous.graph, metagraph: metagraph ?? previous.metagraph,
            nodeTypes: nodeTypes ?? previous.nodeTypeMapping, edgeTypes: edgeTypes ?? previous.edgeTypeMapping)
    }

    public func updatedSelfWith(
        graph: Graph? = nil, metagraph: MetaGraph? = nil, nodeTypes: NodeTypeMapping? = nil,
        edgeTypes: EdgeTypeMapping? = nil
    ) -> Self {
        return TypedGraph(
            previous: self, graph: graph, metagraph: metagraph, nodeTypes: nodeTypes, edgeTypes: edgeTypes)
    }

    #if DEBUG
        var _countsViaGraph: Counts {
            return Counts(graph: graph, metagraph: metagraph)
        }

        var _countsViaMapping: Counts {
            return Counts(nodes: nodeTypeMapping.counts(), edges: edgeTypeMapping.counts())
        }
    #endif
}
