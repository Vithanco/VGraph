extension TypedGraph {

    public struct Counts: VProtocol {
        let nodes: Int
        let edges: Int
        let nodeTypes: Int
        let edgeTypes: Int
    }

    public var counts: Counts {
        return Counts(graph: self.graph, metagraph: self.metagraph)
    }
}

extension TypedGraph.Counts {

    init(nodes: TypedGraph.NodeTypeMapping.Counts, edges: TypedGraph.EdgeTypeMapping.Counts) {
        self.nodes = nodes.manys
        self.edges = edges.manys
        self.nodeTypes = nodes.ones
        self.edgeTypes = edges.ones
    }

    init(graph: TypedGraph.Graph, metagraph: TypedGraph.MetaGraph) {
        nodes = graph.vertexCount
        edges = graph.edgeCount
        nodeTypes = metagraph.vertexCount
        edgeTypes = metagraph.edgeCount
    }
}
