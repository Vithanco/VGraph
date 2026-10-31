public enum NodeShape: VProtocol, AttributeType {
    case box
    case circle
    case point
    /// A database cylinder (rounded top/bottom caps). Native Graphviz shape.
    case cylinder
    /// A C4 "person": a box with a head. No Graphviz equivalent — laid out as a box.
    case person

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "NodeShape"
    }

    public static func fromString(_ string: String) throws(VError) -> NodeShape {
        switch string {
        case "box": return .box
        case "circle": return .circle
        case "point": return .point
        case "cylinder": return .cylinder
        case "person": return .person
        default:
            throw VError.conversionError(from: string, to: "NodeShape")
        }
    }

    public var asString: String {
        switch self {
        case .box: return "box"
        case .circle: return "circle"
        case .point: return "point"
        case .cylinder: return "cylinder"
        case .person: return "person"
        }
    }
}
