// Reading an element's label regardless of its kind, so an inline editor can be
// seeded from the graph rather than from what was rendered. See ADR-0009.

extension VGraph {
    /// The authority for an inline edit — the rendered text is not always the
    /// label, and an unlabelled element renders nothing to read back.
    public func label(of target: VCommandTarget) -> String? {
        switch target {
        case .node(let node):
            return try? get(node: node, attribute: Attributes.Node.label)
        case .edge(let edge):
            return try? get(edge: edge, attribute: Attributes.Edge.label)
        case .group(let group) where isDetailed(group):
            return try? get(group: group, attribute: Attributes.Node.label)
        case .group(let group):
            return try? get(group: group, attribute: Attributes.Group.label)
        }
    }

    public func set(label: String, on target: VCommandTarget) throws(VError) -> VGraph {
        switch target {
        case .node(let node):
            return try set(node: node, attribute: Attributes.Node.label.attribute(label))
        case .edge(let edge):
            return try set(edge: edge, attribute: Attributes.Edge.label.attribute(label))
        case .group(let group) where isDetailed(group):
            return try set(group: group, attribute: Attributes.Node.label.attribute(label))
        case .group(let group):
            return try set(group: group, attribute: Attributes.Group.label.attribute(label))
        }
    }
}
