public enum Attributes {}

extension Attributes {
    /// VGraph's own vocabulary. The three sets share no id, so none hides another.
    static let standard = AttributeDefContainer(
        Array(Node.definitions.values) + Array(Edge.definitions.values) + Array(Group.definitions.values))
}
