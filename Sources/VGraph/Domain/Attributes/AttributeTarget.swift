public enum AttributeTarget: HasReadableNames {
    case node
    case edge
    case group

    public var readableName: String {
        switch self {
        case .node: return "Node"
        case .edge: return "Edge"
        case .group: return "Group"
        }
    }

    public var toolTip: String {
        switch self {
        case .node: return "An Attribute for a Node"
        case .group: return "An Attribute for a Group of Nodes, or the diagram"
        case .edge: return "An Attribute for an Edge"
        }
    }

    // Explicit per-case strings — no enum-case reflection under Embedded Swift.
    public var value: String {
        switch self {
        case .node: return "node"
        case .edge: return "edge"
        case .group: return "group"
        }
    }

    public static let typeName: String = "AttributeTarget"
}
