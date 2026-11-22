// One relationship offered at a node, and resolving an answer against the
// offers. See ADR-0013.

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

extension Array where Element == EdgeType {
    public func named(_ id: EdgeType.Id) -> EdgeType? {
        first { $0.id == id }
    }
}

extension Array where Element == VCandidate {
    /// A candidate is named by its *relationship* — the node type follows from it.
    public func named(_ id: EdgeType.Id) -> VCandidate? {
        first { $0.edgeType.id == id }
    }
}
