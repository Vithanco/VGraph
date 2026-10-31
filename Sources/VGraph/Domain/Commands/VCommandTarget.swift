// The element a VCommand acts on, resolved against the OriginGraph.

public enum VElementKind: Hashable, Sendable {
    case node
    case edge
    case group
}

public enum VCommandTarget: Sendable, Equatable {
    case node(Node)
    case edge(Edge.Id)
    case group(Group)

    public var kind: VElementKind {
        switch self {
        case .node: return .node
        case .edge: return .edge
        case .group: return .group
        }
    }

    /// The element's id. Unique across all three kinds within a valid graph, which
    /// is what lets `resolveCommandTarget(id:)` round-trip it.
    public var elementId: String {
        switch self {
        case .node(let node): return node.id
        case .edge(let edge): return edge.id
        case .group(let group): return group.id.id
        }
    }
}
