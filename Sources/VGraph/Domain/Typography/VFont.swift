/// Font family for use in node and edge text.
/// Limited to web-safe fonts that work across platforms.
public enum FontFamily: String, CaseIterable, VProtocol {
    case helvetica = "Helvetica"
    case arial = "Arial"
    case verdana = "Verdana"
    case times = "Times"
    case timesNewRoman = "Times New Roman"
    case courier = "Courier"
    case courierNew = "Courier New"
    case georgia = "Georgia"
    case dmSans = "DM Sans"

    public static let `default`: FontFamily = .dmSans

    /// Font name for SVG rendering — DM Sans uses a quoted stack with sans-serif fallback
    public var svgName: String {
        switch self {
        case .dmSans: return "'DM Sans', Helvetica, sans-serif"
        default: return rawValue
        }
    }

    /// Average character width ratio (relative to font size)
    public var charWidthRatio: Double {
        switch self {
        case .helvetica: return 0.55
        case .arial: return 0.55
        case .verdana: return 0.60
        case .times: return 0.50
        case .timesNewRoman: return 0.50
        case .courier: return 0.60  // Monospace
        case .courierNew: return 0.60  // Monospace
        case .georgia: return 0.52
        case .dmSans: return 0.54
        }
    }

    public var isMonospace: Bool {
        switch self {
        case .courier, .courierNew:
            return true
        default:
            return false
        }
    }

}

public struct VFont: VProtocol, Identifiable, CustomStringConvertible {

    public var id: String {
        return "\(family.rawValue)-\(size)"
    }

    public var family: FontFamily
    public var size: Double

    public init(family: FontFamily = .default, size: Double) {
        self.family = family
        self.size = size
    }

    public var description: String {
        return "\(family.rawValue)-\(size)"
    }

    public var svgName: String {
        return family.svgName
    }

    public var charWidthRatio: Double {
        return family.charWidthRatio
    }

    static public func systemFont(ofSize: Double) -> VFont {
        return VFont(family: .default, size: ofSize)
    }
    public static let defaultSize: Double = 11
    public static let `default` = VFont(family: .default, size: defaultSize)
}

extension VFont: AttributeType {
    public static var typeName: String {
        return "VFont"
    }

    public static func fromString(_ string: String) throws(VError) -> VFont {
        let parts = string.split(separator: ";", maxSplits: 1).map(String.init)

        if parts.count == 1 {
            // Just size, use default family
            guard let size = Double(parts[0]) else {
                throw VError.conversionError(from: string, to: typeName)
            }
            return VFont(family: .default, size: size)
        } else if parts.count == 2 {
            guard let family = FontFamily(rawValue: parts[0]) else {
                throw VError.conversionError(from: string, to: typeName)
            }
            guard let size = Double(parts[1]) else {
                throw VError.conversionError(from: string, to: typeName)
            }
            return VFont(family: family, size: size)
        }

        throw VError.conversionError(from: string, to: typeName)
    }

    public var asString: String {
        return "\(family.rawValue);\(size)"
    }
}

extension FontFamily: AttributeType {
    public static var typeName: String {
        return "FontFamily"
    }
    public static func fromString(_ string: String) throws(VError) -> FontFamily {
        guard let family = FontFamily(rawValue: string) else {
            throw VError.conversionError(from: string, to: typeName)
        }
        return family
    }

    public var asString: String {
        return rawValue
    }
}
