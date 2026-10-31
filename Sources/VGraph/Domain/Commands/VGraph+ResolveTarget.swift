// Resolve a rendered-element id back to its OriginGraph target.

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
