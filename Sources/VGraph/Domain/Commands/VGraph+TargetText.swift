// Reading and writing an element's label or link regardless of its kind, so
// an inline editor is seeded from the graph rather than from what was
// rendered (ADR-0009).

extension VGraph {
    /// The authority for an inline edit — the rendered text is not always the
    /// label, and an unlabelled element renders nothing to read back.
    public func label(of target: VCommandTarget) -> String? {
        text(.label, of: target)
    }

    public func setting(label: String, on target: VCommandTarget) throws(VError) -> VGraph {
        try setting(.label, to: label, on: target)
    }

    /// The link attached to an element, or nil when there is none — including the
    /// empty string, which is what removal leaves behind.
    public func url(of target: VCommandTarget) -> String? {
        guard let stored = text(.url, of: target), !stored.isEmpty else { return nil }
        return stored
    }

    /// Attach `url` to an element, or detach it by passing "".
    public func setting(url: String, on target: VCommandTarget) throws(VError) -> VGraph {
        try setting(.url, to: url, on: target)
    }

    private func text(_ field: ElementText, of target: VCommandTarget) -> String? {
        switch target {
        case .node(let node): return try? get(node: node, attribute: field.node)
        case .edge(let edge): return try? get(edge: edge, attribute: field.edge)
        case .group(let group): return try? get(group: group, attribute: definition(of: field, for: group))
        }
    }

    private func setting(_ field: ElementText, to value: String, on target: VCommandTarget) throws(VError) -> VGraph {
        switch target {
        case .node(let node):
            let textAttribute = field.node
            return try setting(node: node, attribute: textAttribute(value))
        case .edge(let edge):
            let textAttribute = field.edge
            return try setting(edge: edge, attribute: textAttribute(value))
        case .group(let group):
            let textAttribute = definition(of: field, for: group)
            return try setting(group: group, attribute: textAttribute(value))
        }
    }

    /// A detailed node is a node first, so its text is the node's (ADR-0032).
    private func definition(of field: ElementText, for group: Group) -> TypedAttributeDefinition<String> {
        isDetailed(group) ? field.node : field.group
    }
}

extension VGraph {
    /// How to name an element to the user: by its label, or its id where it has none.
    /// An edge is "A → B".
    func name(of edge: Edge) -> String {
        "\(name(of: edge.from)) → \(name(of: edge.to))"
    }

    func name(of node: Node) -> String {
        guard let label = label(of: .node(node)), !label.isEmpty else { return node.id }
        return label
    }

    func name(of group: Group) -> String {
        guard let label = label(of: .group(group)), !label.isEmpty else { return group.id.id }
        return label
    }
}

private struct ElementText {
    let node: TypedAttributeDefinition<String>
    let edge: TypedAttributeDefinition<String>
    let group: TypedAttributeDefinition<String>

    static let label = ElementText(
        node: Attributes.Node.label, edge: Attributes.Edge.label, group: Attributes.Group.label)
    static let url = ElementText(node: Attributes.Node.url, edge: Attributes.Edge.url, group: Attributes.Group.url)
}
