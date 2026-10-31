//
//  VEdgeCandidates.swift
//  VGraph
//
//  What the notation permits when an existing edge is flipped, split or retyped.
//

/// One way to split an edge. A **pair** of edge types, not a node type: in a
/// Causal Loop Diagram the sign of each link is the whole point, so the two
/// halves are separate choices — see `namesTheRelationshipsWhenTheNodeTypeIsNotEnough`.
public struct VSplitCandidate: Sendable, Equatable {
    /// Source → inserted node.
    public let incoming: EdgeType
    /// Inserted node → target.
    public let outgoing: EdgeType
    public let title: String

    public init(incoming: EdgeType, outgoing: EdgeType, title: String) {
        self.incoming = incoming
        self.outgoing = outgoing
        self.title = title
    }

    public var nodeType: NodeType { incoming.to }

    /// Stable within one conversation, which is all replay needs (ADR-0013).
    public var id: String { "\(incoming.id.id)>\(outgoing.id.id)" }
}

extension VGraph {
    /// The edge types that could carry `edge` the other way round. Empty means
    /// flipping it breaks the notation.
    public func reverseCandidates(for edge: Edge.Id) -> [EdgeType] {
        guard let existing = get(edge: edge),
            let sourceType = try? nodeType(for: existing.from),
            let targetType = try? nodeType(for: existing.to)
        else { return [] }
        return knownEdgeTypes(from: targetType, to: sourceType)
    }

    /// The edge types `edge` could become between the endpoints it already has.
    /// Empty means the notation offers no alternative.
    ///
    /// **Asked of the graph minus this edge**, exactly as `reattachCandidates`
    /// is and for the same reason: an edge about to be replaced must not count
    /// against the [[Bound]] budget it is about to vacate. A `Step` bounded
    /// at `totalOutDegreeMax: 1` closes its source outright, so a plain
    /// `connectCandidates` would answer *nothing at all* for the pair being
    /// retyped — the bound is spent by the edge in hand (ADR-0011, ADR-0021).
    ///
    /// The current type is dropped, as `retypeCandidates(for node:)` drops it:
    /// "change it to what it already is" is not an offer. Unknown types need no
    /// filtering here — `connectCandidates` reads `knownEdgeTypes`, which has
    /// already excluded them.
    public func retypeCandidates(edge: Edge.Id) -> [EdgeType] {
        guard let existing = get(edge: edge),
            let current = try? edgeType(for: edge),
            let without = try? delete(edge: edge)
        else { return [] }

        var result: [EdgeType] = []
        for candidate in without.connectCandidates(from: existing.from, to: existing.to)
        where candidate.id != current.id {
            result.append(candidate)
        }
        return result
    }

    /// The node types the notation allows between `edge`'s endpoints, each paired
    /// with the relationships that would attach it. Empty means splitting it
    /// breaks the notation.
    public func splitCandidates(for edge: Edge.Id) -> [VSplitCandidate] {
        guard let existing = get(edge: edge),
            let sourceType = try? nodeType(for: existing.from),
            let targetType = try? nodeType(for: existing.to)
        else { return [] }

        // The inserted node takes the incoming relationship's declared far type, as
        // an added successor does; either outer end may be a detail (ADR-0032).
        let known = edgeTypes.filter { !$0.isUnknown }
        var pairs: [(incoming: EdgeType, outgoing: EdgeType)] = []
        var occurrences: [String: Int] = [:]
        for incoming in known where holds(incoming, from: sourceType, to: incoming.to) {
            for outgoing in known where holds(outgoing, from: incoming.to, to: targetType) {
                pairs.append((incoming, outgoing))
                occurrences[incoming.to.id] = (occurrences[incoming.to.id] ?? 0) + 1
            }
        }

        // A type reachable more than one way is named by its relationships,
        // rather than appearing twice under the same title.
        var result: [VSplitCandidate] = []
        for pair in pairs {
            let middle = pair.incoming.to
            let ambiguous = (occurrences[middle.id] ?? 0) > 1
            result.append(
                VSplitCandidate(
                    incoming: pair.incoming,
                    outgoing: pair.outgoing,
                    title: ambiguous
                        ? "\(middle.id) (\(pair.incoming.id.id) → \(pair.outgoing.id.id))" : middle.id))
        }
        return result
    }
}
