public struct TypedGraph: VProtocol {
    public typealias NodeTypeMapping = OneToManyLookup<NodeType, Node>
    public typealias EdgeTypeMapping = OneToManyLookup<EdgeType.Id, Edge.Id>
    public typealias Graph = DirectedMultigraph<_Node>
    public typealias MetaGraph = DirectedMultigraph<_NodeType>

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
        guard let type = nodeTypeMapping.getOne(many: id), metagraph.has(node: type) else { return nil }
        return type
    }

    public func edgeType(for id: Edge.Id) -> EdgeType? {
        edgeTypeMapping.getOne(many: id).flatMap { metagraph.get(edge: $0) }
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
        return has(nodeType: NodeType(rawValue: nodeTypeName))
    }

    public func has(edgeTypeId: String) -> Bool {
        return has(edgeType: EdgeType.Id(rawValue: edgeTypeId))
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

    /// Its edges go first, through `delete(edge:)`, so none keeps a type it no longer wears.
    public func delete(node: Node) throws(VError) -> TypedGraph {
        guard graph.has(node: node) else {
            throw VError.nodeNotFound(node)
        }
        guard nodeTypeMapping.getOne(many: node) != nil else {
            throw VError.nodeWithoutNodeType(node)
        }
        let withoutEdges = try edges(at: node).folding(self) { (result, edge) throws(VError) in
            try result.delete(edge: edge.id)
        }
        return withoutEdges.updatedSelfWith(
            graph: withoutEdges.graph.removeVertex(node), nodeTypes: nodeTypeMapping.remove(many: node))
    }

    func edges(at node: Node) -> [Edge] {
        edges.filter { $0.from == node || $0.to == node }
    }

    public func delete(edge id: Edge.Id) throws(VError) -> TypedGraph {
        guard let edge = graph.get(edge: id) else {
            throw VError.edgeNotFound(id)
        }
        let newGraph = graph.removeEdge(id: edge.id)
        let newEdgeTypeMapping = edgeTypeMapping.remove(many: id)
        return updatedSelfWith(graph: newGraph, edgeTypes: newEdgeTypeMapping)
    }

    /// Move an edge's endpoints, keeping its id and type.
    public func redirect(edge: Edge) throws(VError) -> TypedGraph {
        guard let type = edgeTypeMapping.getOne(many: edge.id) else {
            throw VError.edgeTypeNotFoundForEdge(edge.id)
        }
        return try delete(edge: edge.id).add(edge: edge, type: type)
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

    public func add(nodeType: NodeType) throws(VError) -> Self {
        if metagraph.vertices.contains(nodeType) {
            throw VError.nodeTypeAlreadyExists(nodeType)
        }
        let newMetagraph = metagraph.addVertex(nodeType)
        return updatedSelfWith(metagraph: newMetagraph)
    }

    public func add(edgeType: EdgeType) throws(VError) -> TypedGraph {
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
        guard has(node: node) else { throw VError.nodeNotFound(node) }
        try ensureExists(nodeType: type)

        let newNodeTypeMapping = nodeTypeMapping.add(many: node, one: type)
        return updatedSelfWith(nodeTypes: newNodeTypeMapping)
    }

    public func setEdgeType(edge: Edge.Id, type: EdgeType.Id) throws(VError) -> TypedGraph {
        guard has(edge: edge) else { throw VError.edgeNotFound(edge) }
        try ensureExists(edgeType: type)
        let newEdgeTypeMapping = edgeTypeMapping.add(many: edge, one: type)
        return updatedSelfWith(edgeTypes: newEdgeTypeMapping)
    }

    public func ensureUnknownNodeType() throws(VError) -> TypedGraph {
        let unknownType = NodeType.unknown
        if has(nodeType: unknownType) {
            return self
        }
        return try add(nodeType: unknownType)
    }

    public func ensureUnknownEdgeType(from: NodeType, to: NodeType) throws(VError) -> (TypedGraph, EdgeType) {
        let unknownEdgeType = EdgeType.unknown(from: from, to: to)

        if let existing = get(edgeType: unknownEdgeType.id) {
            return (self, existing)
        }

        let withEndTypes = try [from, to].folding(self) { (graph, type) throws(VError) in
            graph.has(nodeType: type) ? graph : try graph.add(nodeType: type)
        }
        return (try withEndTypes.add(edgeType: unknownEdgeType), unknownEdgeType)
    }

    func findLoops() -> Graph.LoopSearch {
        graph.findLoops()
    }

    public func ensureExists(nodeType: NodeType) throws(VError) {
        guard metagraph.has(node: nodeType) else {
            throw VError.nodeTypeNotFound(nodeType)
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
}
