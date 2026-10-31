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

        if exhausted(Attributes.Node.totalOutDegreeMax, of: sourceType, at: from, leaving: true) { return [] }
        if exhausted(Attributes.Node.totalInDegreeMax, of: targetType, at: to, leaving: false) { return [] }
        if Notations.criteria(of: self).contains(.noParallelEdges), typedGraph.graph.edgeExists(from: from, to: to) {
            return []
        }

        var result: [EdgeType] = []
        for edgeType in knownEdgeTypes(from: sourceType, to: targetType) {
            if exhausted(
                Attributes.Edge.outDegreeMax, of: edgeType,
                count: count(edgesOf: edgeType, at: from, leaving: true))
            {
                continue
            }
            if exhausted(
                Attributes.Edge.inDegreeMax, of: edgeType,
                count: count(edgesOf: edgeType, at: to, leaving: false))
            {
                continue
            }
            if exhausted(
                Attributes.Edge.samePairMax, of: edgeType,
                count: count(edgesOf: edgeType, from: from, to: to))
            {
                continue
            }
            result.append(edgeType)
        }
        return result
    }

    private func exhausted(
        _ definition: TypedAttributeDefinition<Int>, of nodeType: NodeType, at node: Node, leaving: Bool
    ) -> Bool {
        let max = (try? get(nodeType: nodeType, attribute: definition)) ?? Bound.unbounded
        return Bound.isStated(max) && degree(of: node, leaving: leaving) >= max
    }

    private func exhausted(
        _ definition: TypedAttributeDefinition<Int>, of edgeType: EdgeType, count: Int
    ) -> Bool {
        let max = (try? get(edgeType: edgeType.id, attribute: definition)) ?? Bound.unbounded
        return Bound.isStated(max) && count >= max
    }
}
