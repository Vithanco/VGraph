// Ids for elements a VCommand creates. See ADR-0013.

extension VGraph {
    /// An unused id of the form `concept_1`. Synthetic rather than slugged from
    /// the label — see ADR-0013.
    func newNodeId(for nodeType: NodeType) -> Node {
        return Node(rawValue: firstFreeId(prefix: nodeType.id.lowercased(), countingFrom: count(ofNodeType: nodeType) + 1))

        func count(ofNodeType nodeType: NodeType) -> Int {
            typedGraph.nodeTypeMapping.getMany(one: nodeType)?.count ?? 0
        }
    }

    func newGroupId() -> Group {
        Group(rawValue: firstFreeId(prefix: "group", countingFrom: groups.count + 1))
    }

    func newEdge(from: Node, to: Node) -> Edge {
        Edge(id: newEdgeId(from: from, to: to), from: from, to: to)
    }

    /// An unused id of the form `a_b`, or `a_b_2` when that is taken. Edge ids
    /// never reach the VGL, but they share the node/edge/group keyspace.
    private func newEdgeId(from: Node, to: Node) -> Edge.Id {
        Edge.Id(rawValue: Self.freeId(near: "\(from.id)_\(to.id)") { isTaken($0) })
    }

    public static func freeId(near base: String, isTaken: (String) -> Bool) -> String {
        isTaken(base) ? firstFreeId(prefix: base, countingFrom: 2, isTaken: isTaken) : base
    }

    /// Counting only picks where the probe starts: ids are not dense and all
    /// three kinds share one keyspace, so the count routinely lands on a taken
    /// id. See `NewNodeIdTests` for what that does and does not guarantee.
    private func firstFreeId(prefix: String, countingFrom start: Int) -> String {
        Self.firstFreeId(prefix: prefix, countingFrom: start) { isTaken($0) }
    }

    private static func firstFreeId(
        prefix: String, countingFrom start: Int, isTaken: (String) -> Bool
    ) -> String {
        var index = start
        while isTaken("\(prefix)_\(index)") { index += 1 }
        return "\(prefix)_\(index)"
    }

    private func isTaken(_ id: String) -> Bool {
        resolveCommandTarget(id: id) != nil
    }
}
