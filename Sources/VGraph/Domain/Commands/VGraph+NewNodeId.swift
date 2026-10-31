// Ids for elements a VCommand creates. See ADR-0013.

extension VGraph {
    /// An unused id of the form `a_b`, or `a_b_2` when that is taken. Edge ids
    /// never reach the VGL, but they share the node/edge/group keyspace.
    public func newEdgeId(from: Node, to: Node) -> Edge.Id {
        let base = "\(from.id)_\(to.id)"
        if resolveCommandTarget(id: base) == nil { return Edge.Id(string: base) }
        var index = 2
        while true {
            let candidate = "\(base)_\(index)"
            if resolveCommandTarget(id: candidate) == nil { return Edge.Id(string: candidate) }
            index += 1
        }
    }

    /// An unused id of the form `concept_1`. Synthetic rather than slugged from
    /// the label — see ADR-0013. Counting only picks where to start; see
    /// `NewNodeIdTests` for what that does and does not guarantee.
    public func newNodeId(for nodeType: NodeType) -> Node {
        let prefix = nodeType.id.lowercased()
        var index = count(ofNodeType: nodeType) + 1
        while true {
            let candidate = "\(prefix)_\(index)"
            if resolveCommandTarget(id: candidate) == nil {
                return Node(string: candidate)
            }
            index += 1
        }
    }

    func count(ofNodeType nodeType: NodeType) -> Int {
        typedGraph.nodeTypeMapping.getMany(one: nodeType)?.count ?? 0
    }
}
