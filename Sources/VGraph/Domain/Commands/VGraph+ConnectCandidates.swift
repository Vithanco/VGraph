//
//  VGraph+ConnectCandidates.swift
//  VGraph
//
//  What the notation permits between two *existing* nodes. See ADR-0012.
//

extension VGraph {
    /// The edge types that may join `from` to `to` right now, still under every
    /// [[Bound]] maximum (ADR-0011) and, where the notation declares it, never
    /// beside an edge that already joins them that way.
    ///
    /// Separate from `successorCandidates(from:)` because with both ends known it
    /// can ask what that one cannot: `samePairMax` has a pair to count, and the far
    /// end has a real degree rather than a hypothetical one.
    public func connectCandidates(from: Node, to: Node) -> [EdgeType] {
        guard let sourceType = try? nodeType(for: from), let targetType = try? nodeType(for: to)
        else { return [] }

        if exhausted(Attributes.Node.totalOutDegreeMax, of: sourceType, at: from, end: .from) { return [] }
        if exhausted(Attributes.Node.totalInDegreeMax, of: targetType, at: to, end: .to) { return [] }
        if wouldBeForbiddenParallelEdge(from: from, to: to) { return [] }

        return knownEdgeTypes(from: sourceType, to: targetType).filter { !isSpent($0) }

        func isSpent(_ edgeType: EdgeType) -> Bool {
            exhausted(
                Attributes.Edge.outDegreeMax, of: edgeType, count: count(edgesOf: edgeType, at: from, end: .from))
                || exhausted(
                    Attributes.Edge.inDegreeMax, of: edgeType, count: count(edgesOf: edgeType, at: to, end: .to))
                || exhausted(
                    Attributes.Edge.samePairMax, of: edgeType, count: count(edgesOf: edgeType, from: from, to: to))
        }

        func wouldBeForbiddenParallelEdge(from: Node, to: Node) -> Bool {
            Notations.criteria(of: self).contains(.noParallelEdges) && typedGraph.getFirstEdge(from: from, to: to) != nil
        }
    }

    /// `connectCandidates` for the pair `edge` would join once changed — a `nil`
    /// end staying where it is — **asked of the graph minus `edge`**. An edge
    /// about to move or be retyped must not count against the [[Bound]] budget
    /// it is about to vacate; the command deletes before it adds, so it
    /// validates against the same reduced graph (ADR-0011, ADR-0021).
    func connectCandidates(replacing edge: Edge.Id, from: Node? = nil, to: Node? = nil) -> [EdgeType] {
        guard let existing = get(edge: edge), let withoutEdge = try? delete(edge: edge) else { return [] }
        return withoutEdge.connectCandidates(from: from ?? existing.from, to: to ?? existing.to)
    }
}
