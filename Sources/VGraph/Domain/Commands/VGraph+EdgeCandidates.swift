// What the notation permits when an existing edge is flipped, split, retyped,
// or has one end moved (ADR-0021).

extension VGraph {
    /// The edge types that could carry `edge` the other way round. Empty means
    /// flipping it breaks the notation.
    public func reverseCandidates(for edge: Edge.Id) -> [EdgeType] {
        guard let ends = endTypes(of: edge) else { return [] }
        return knownEdgeTypes(from: ends.to, to: ends.from)
    }

    /// The edge types `edge` could become between the endpoints it already has.
    /// Empty means the notation offers no alternative.
    ///
    /// Asked of the graph minus this edge: a `Step` bounded at
    /// `totalOutDegreeMax: 1` closes its source outright, so a plain
    /// `connectCandidates` would answer *nothing at all* for the pair being
    /// retyped — the bound is spent by the edge in hand.
    ///
    /// The current type is dropped, as `retypeCandidates(for node:)` drops it:
    /// "change it to what it already is" is not an offer. Unknown types need no
    /// filtering here — `connectCandidates` reads `knownEdgeTypes`, which has
    /// already excluded them.
    public func retypeCandidates(for edge: Edge.Id) -> [EdgeType] {
        guard let current = try? edgeType(for: edge) else { return [] }
        return connectCandidates(replacing: edge).filter { $0.id != current.id }
    }

    /// The node types the notation allows between `edge`'s endpoints, each paired
    /// with the relationships that would attach it. Empty means splitting it
    /// breaks the notation.
    public func splitCandidates(for edge: Edge.Id) -> [VSplitCandidate] {
        guard let ends = endTypes(of: edge) else { return [] }
        let pairs = splitPairs(between: ends)
        let titles = Self.menuTitles(
            pairs.map { (nodeType: $0.incoming.to, relationships: "\($0.incoming.id.id) → \($0.outgoing.id.id)") })
        return zip(pairs, titles).map { pair, title in
            VSplitCandidate(incoming: pair.incoming, outgoing: pair.outgoing, title: title)
        }

        /// The inserted node takes the incoming relationship's declared far type,
        /// as an added successor does; either outer end may be a detail (ADR-0032).
        func splitPairs(between ends: (from: NodeType, to: NodeType)) -> [(incoming: EdgeType, outgoing: EdgeType)] {
            let known = edgeTypes.filter { !$0.isUnknown }
            return known.filter { holds($0, from: ends.from, to: $0.to) }.flatMap { incoming in
                known.filter { holds($0, from: incoming.to, to: ends.to) }.map { (incoming: incoming, outgoing: $0) }
            }
        }
    }

    /// The edge types that may join the pair an [[Edge end]] would make by moving
    /// to `node` — the far end staying where it is.
    ///
    /// Asked of the graph minus this edge, which is the whole reason this is not
    /// `connectCandidates(from:to:)`: under `samePairMax: 1`, moving `A→B`'s `to`
    /// end would otherwise be refused because `A→B` still occupies the one slot.
    public func reattachCandidates(for edge: Edge.Id, end: VEdgeEnd, to node: Node) -> [EdgeType] {
        switch end {
        case .from: return connectCandidates(replacing: edge, from: node)
        case .to: return connectCandidates(replacing: edge, to: node)
        }
    }

    private func endTypes(of edge: Edge.Id) -> (from: NodeType, to: NodeType)? {
        guard let existing = get(edge: edge),
            let from = try? nodeType(for: existing.from),
            let to = try? nodeType(for: existing.to)
        else { return nil }
        return (from, to)
    }
}
