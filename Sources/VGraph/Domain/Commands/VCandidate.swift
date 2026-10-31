// What the notation permits at a node: the relationships that may leave or
// arrive, and the types the node itself may take. See ADR-0013.

/// A relationship the notation permits from (or to) a given node type, together
/// with the node type it would create.
///
/// A candidate is an **edge type**, not a node type: the notation decides which
/// relationships may leave or arrive, and the new node's type follows from the
/// edge type's far end.
public struct VCandidate: Sendable, Equatable {
    public let edgeType: EdgeType
    public let nodeType: NodeType
    public let title: String

    public init(edgeType: EdgeType, nodeType: NodeType, title: String) {
        self.edgeType = edgeType
        self.nodeType = nodeType
        self.title = title
    }
}

// MARK: - Resolving an answer against what was offered

// Every command that takes an edge-type answer does the same two things: find
// the offered item the id names, and refuse when there is none
// (`commandOptionNotOffered`). Written once here so the refusal cannot be
// forgotten at a fifth site the way it was at the first four.

extension Array where Element == EdgeType {
    public func named(_ id: EdgeType.Id) -> EdgeType? {
        first { $0.id == id }
    }
}

extension Array where Element == VCandidate {
    /// The offered candidate reached by this edge type, or `nil`. A candidate is
    /// identified by its *relationship* — the node type follows from it.
    public func joined(by id: EdgeType.Id) -> VCandidate? {
        first { $0.edgeType.id == id }
    }
}

extension VGraph {
    public func successorCandidates(of nodeType: NodeType) -> [VCandidate] {
        candidates(of: nodeType, outgoing: true)
    }

    public func predecessorCandidates(of nodeType: NodeType) -> [VCandidate] {
        candidates(of: nodeType, outgoing: false)
    }

    /// So a menu never offers what the check would flag the instant it is picked
    /// (ADR-0011).
    public func successorCandidates(from source: Node) -> [VCandidate] {
        withinBounds(candidates(ofNodeAt: source, outgoing: true), at: source, outgoing: true)
    }

    public func predecessorCandidates(to target: Node) -> [VCandidate] {
        withinBounds(candidates(ofNodeAt: target, outgoing: false), at: target, outgoing: false)
    }

    private func candidates(ofNodeAt node: Node, outgoing: Bool) -> [VCandidate] {
        guard let type = try? nodeType(for: node) else { return [] }
        return candidates(of: type, outgoing: outgoing)
    }

    private func withinBounds(_ all: [VCandidate], at node: Node, outgoing: Bool) -> [VCandidate] {
        guard let type = try? nodeType(for: node) else { return [] }

        let totalMax = bound(outgoing ? Attributes.Node.totalOutDegreeMax : Attributes.Node.totalInDegreeMax, of: type)
        if Bound.isStated(totalMax), degree(of: node, leaving: outgoing) >= totalMax { return [] }

        var result: [VCandidate] = []
        for candidate in all {
            let atThisEnd = bound(
                outgoing ? Attributes.Edge.outDegreeMax : Attributes.Edge.inDegreeMax,
                of: candidate.edgeType)
            if Bound.isStated(atThisEnd),
                count(edgesOf: candidate.edgeType, at: node, leaving: outgoing) >= atThisEnd
            {
                continue
            }

            let atFarEnd = bound(
                outgoing ? Attributes.Node.totalInDegreeMax : Attributes.Node.totalOutDegreeMax,
                of: candidate.nodeType)
            if Bound.isStated(atFarEnd), atFarEnd < 1 { continue }

            result.append(candidate)
        }
        return result
    }

    private func bound(_ definition: TypedAttributeDefinition<Int>, of nodeType: NodeType) -> Int {
        (try? get(nodeType: nodeType, attribute: definition)) ?? Bound.unbounded
    }

    private func bound(_ definition: TypedAttributeDefinition<Int>, of edgeType: EdgeType) -> Int {
        (try? get(edgeType: edgeType.id, attribute: definition)) ?? Bound.unbounded
    }

    /// Shared with `connectCandidates(from:to:)`.
    func degree(of node: Node, leaving: Bool) -> Int {
        var total = 0
        for edge in edges where (leaving ? edge.from : edge.to) == node { total += 1 }
        return total
    }

    /// The new node takes the declared far type, so each relationship is one
    /// candidate; the near end may be a detail of the declared one (ADR-0032).
    private func candidates(of nodeType: NodeType, outgoing: Bool) -> [VCandidate] {
        var matching: [EdgeType] = []
        for edgeType in edgeTypes where !edgeType.isUnknown {
            let held =
                outgoing
                ? holds(edgeType, from: nodeType, to: edgeType.to)
                : holds(edgeType, from: edgeType.from, to: nodeType)
            if held { matching.append(edgeType) }
        }

        var occurrences: [String: Int] = [:]
        for edgeType in matching {
            let far = outgoing ? edgeType.to : edgeType.from
            occurrences[far.id] = (occurrences[far.id] ?? 0) + 1
        }

        var result: [VCandidate] = []
        for edgeType in matching {
            let far = outgoing ? edgeType.to : edgeType.from
            let ambiguous = (occurrences[far.id] ?? 0) > 1
            result.append(
                VCandidate(
                    edgeType: edgeType,
                    nodeType: far,
                    title: ambiguous ? "\(far.id) (\(edgeType.id.id))" : far.id))
        }
        return result
    }

    /// The types `node` may become with every one of its edges still carried by a
    /// declared edge type, and standing where it stands (ADR-0032) — the allowed
    /// substitutions.
    public func retypeCandidates(for node: Node) -> [NodeType] {
        guard let current = try? nodeType(for: node) else { return [] }
        let attached = edges(at: node)
        let enclosing = group(of: node)

        var result: [NodeType] = []
        for candidate in nodeTypes {
            guard candidate != current, !candidate.id.hasPrefix(NodeType.unknownPrefix),
                allows(candidate, in: enclosing)
            else { continue }
            var carried = true
            for edge in attached where edgeTypeOptions(for: edge, at: node, as: candidate).isEmpty {
                carried = false
                break
            }
            if carried { result.append(candidate) }
        }
        return result
    }

    /// The types a detailed node may become: allowed where it stands, and
    /// detailed by every type it already holds (ADR-0032). It has no edges of its
    /// own, since edges end at its details, so none constrain it.
    public func retypeCandidates(for detailedNode: Group) -> [NodeType] {
        guard let current = nodeType(of: detailedNode) else { return [] }
        let enclosing = parentGroup(of: detailedNode)
        let held = detailTypesHeld(by: detailedNode)

        var result: [NodeType] = []
        for candidate in nodeTypes {
            guard candidate != current, !candidate.id.hasPrefix(NodeType.unknownPrefix),
                allows(candidate, in: enclosing)
            else { continue }
            let admitted = detailTypes(of: candidate)
            if held.allSatisfy({ admitted.contains($0) }) { result.append(candidate) }
        }
        return result
    }

    func edges(at node: Node) -> [Edge] {
        var result: [Edge] = []
        for edge in edges where edge.from == node || edge.to == node {
            result.append(edge)
        }
        return result
    }

    func edgeTypeOptions(for edge: Edge, at node: Node, as candidate: NodeType) -> [EdgeType] {
        guard let from = endType(edge.from, at: node, as: candidate),
            let to = endType(edge.to, at: node, as: candidate)
        else { return [] }
        return knownEdgeTypes(from: from, to: to)
    }

    func endType(_ end: Node, at node: Node, as candidate: NodeType) -> NodeType? {
        end == node ? candidate : try? nodeType(for: end)
    }
}
