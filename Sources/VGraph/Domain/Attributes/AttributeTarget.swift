public enum AttributeTarget: HasReadableNames {
    case node
    case edge
    case graph

    var isGraph: Bool {
        switch self {
        case .graph: return true
        default: return false
        }
    }

    var isNode: Bool {
        switch self {
        case .node: return true
        default: return false
        }
    }

    var isEdge: Bool {
        switch self {
        case .edge: return true
        default: return false
        }
    }

    public var readableName: String {
        switch self {
        case .node: return "Node"
        case .edge: return "Edge"
        case .graph: return "Graph"
        }
    }

    public var toolTip: String {
        switch self {
        case .node: return "An Attribute for a Node"
        case .graph: return "An Attribute for a Group of Nodes"
        case .edge: return "An Attributes for an Edge"
        }
    }

    // Explicit per-case strings — no enum-case reflection under Embedded Swift.
    public var value: String {
        switch self {
        case .node: return "node"
        case .edge: return "edge"
        case .graph: return "graph"
        }
    }

    public static let typeName: String = "AttributeTarget"
}
