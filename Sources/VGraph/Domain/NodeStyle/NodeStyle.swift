/// Each case corresponds to a factory method in `PredefinedStyles.swift`.
public enum NodeStyle: VProtocol, AttributeType, CaseIterable {
    case iconWithText
    case simpleRoundedText
    case simpleRoundedBox
    case withCategory
    case withCategoryAndIcon
    case iconOnly
    case circle
    case bareText
    case hidden
    /// The NodeStyleLayout was set directly on Attributes.Node.style — don't overwrite it.
    case presetLayout

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "NodeStyle"
    }

    public static func fromString(_ string: String) throws(VError) -> NodeStyle {
        switch string {
        case "iconWithText": return .iconWithText
        case "simpleRoundedText": return .simpleRoundedText
        case "simpleRoundedBox", "roundedBox": return .simpleRoundedBox
        case "withCategory": return .withCategory
        case "withCategoryAndIcon": return .withCategoryAndIcon
        case "iconOnly": return .iconOnly
        case "circle": return .circle
        case "bareText": return .bareText
        case "hidden": return .hidden
        case "presetLayout": return .presetLayout
        case "custom": return .bareText
        default:
            throw VError.conversionError(from: string, to: "NodeStyle")
        }
    }

    public var asString: String {
        switch self {
        case .iconWithText: return "iconWithText"
        case .simpleRoundedText: return "simpleRoundedText"
        case .simpleRoundedBox: return "simpleRoundedBox"
        case .withCategory: return "withCategory"
        case .withCategoryAndIcon: return "withCategoryAndIcon"
        case .iconOnly: return "iconOnly"
        case .circle: return "circle"
        case .bareText: return "bareText"
        case .hidden: return "hidden"
        case .presetLayout: return "presetLayout"
        }
    }

    public var needsIcon: Bool {
        switch self {
        case .iconWithText, .withCategoryAndIcon, .iconOnly: return true
        default: return false
        }
    }

    public var needsCategory: Bool {
        switch self {
        case .withCategory, .withCategoryAndIcon: return true
        default: return false
        }
    }
}
