import VGraph

/// The attributes holding VGL comments, named once so the parser and the
/// exporter cannot disagree about which they are. They are ordinary persistent
/// attributes, so every generic `key: value` emit site has to exclude them.
enum CommentAttributes {
    static let node: Set<Attribute.Id> = [Attributes.Node.comment.id, Attributes.Node.trailingComment.id]
    static let edge: Set<Attribute.Id> = [Attributes.Edge.comment.id, Attributes.Edge.trailingComment.id]
    static let group: Set<Attribute.Id> = [Attributes.Group.comment.id, Attributes.Group.trailingComment.id]

    static func holdsAComment(_ id: Attribute.Id) -> Bool {
        node.contains(id) || edge.contains(id) || group.contains(id)
    }

    /// A value that arrived through the `[comment: "..."]` alias has no marker;
    /// it gets one here, at the door, so nothing downstream has to ask.
    static func canonical(_ value: String) -> String {
        value.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let text = String(line)
                if text.isEmpty || text.hasPrefix("//") { return text }
                return "// \(text)"
            }
            .joined(separator: "\n")
    }
}
