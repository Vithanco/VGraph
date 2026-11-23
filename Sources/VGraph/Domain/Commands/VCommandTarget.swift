// The element a VCommand acts on, resolved against the OriginGraph.

public enum VItemKind: Hashable, Sendable {
    case node
    case edge
    case group
}

public enum VCommandTarget: Sendable, Equatable {
    case node(Node)
    case edge(Edge.Id)
    case group(Group)

    public var kind: VItemKind {
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

extension VGraph {
    /// `id` is a rendered element's SVG id minus its `node-`/`edge-`/`group-`
    /// prefix. Nodes, edges and groups share one keyspace, so at most one kind
    /// matches; a folded group renders as a node with the group's id and
    /// resolves to `.group`.
    public func resolveCommandTarget(id: String) -> VCommandTarget? {
        let node = Node(rawValue: id)
        if has(node: node) { return .node(node) }
        let group = Group(rawValue: id)
        if has(group: group) { return .group(group) }
        let edge = Edge.Id(rawValue: id)
        if has(edge: edge) { return .edge(edge) }
        return nil
    }
}
