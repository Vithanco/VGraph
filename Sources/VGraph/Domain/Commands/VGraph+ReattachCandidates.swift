//
//  VGraph+ReattachCandidates.swift
//  VGraph
//
//  What the notation permits when one end of an existing edge moves. See ADR-0021.
//

extension VGraph {
    /// The edge types that may join the pair an [[Edge end]] would make by moving
    /// to `node` — the far end staying where it is.
    ///
    /// **Asked of the graph minus this edge**, which is the whole reason this is
    /// not `connectCandidates(from:to:)`. An edge about to move must not count
    /// against the [[Bound]] budget it is about to vacate: under
    /// `samePairMax: 1`, moving `A→B`'s head would otherwise be refused because
    /// `A→B` still occupies the one slot. `reattach` deletes before it adds, so
    /// the command validates against the same reduced graph this counts (ADR-0011).
    public func reattachCandidates(edge: Edge.Id, end: VEdgeEnd, to node: Node) -> [EdgeType] {
        guard let existing = get(edge: edge), let without = try? delete(edge: edge) else {
            return []
        }
        switch end {
        case .from: return without.connectCandidates(from: node, to: existing.to)
        case .to: return without.connectCandidates(from: existing.from, to: node)
        }
    }
}
