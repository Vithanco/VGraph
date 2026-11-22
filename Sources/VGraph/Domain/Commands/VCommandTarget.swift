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

extension VGraph {
    /// Resolve an element id — as stamped on rendered elements by the display
    /// pipeline (the SVG `node-`/`edge-`/`group-` id minus its prefix) — to the
    /// concrete OriginGraph element it names.
    ///
    /// Element ids are globally unique within a valid graph (nodes, edges and
    /// groups share one attribute keyspace; a duplicate fails the parse), so at
    /// most one kind matches. A folded group renders as a node whose id equals
    /// the group id, so `resolveCommandTarget(id:)` correctly returns `.group`.
    /// Returns nil for an unknown id (e.g. a stale menu / a synthesized element
    /// with no OriginGraph counterpart).
    public func resolveCommandTarget(id: String) -> VCommandTarget? {
        let node = Node(string: id)
        if has(node: node) { return .node(node) }
        let group = Group(rawValue: id)
        if has(group: group) { return .group(group) }
        let edge = Edge.Id(string: id)
        if has(edge: edge) { return .edge(edge) }
        return nil
    }
}
