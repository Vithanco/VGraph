// How a `vnotation` spells a frame. Reading and export both go through this
// table, so their spellings cannot drift apart.
extension GroupFrame {
    static let dashKey = "frameDash"
    static let colorKey = "frameColor"
    static let fillKey = "frameFill"
    static let radiusKey = "frameRadius"

    /// In the order export writes them.
    static let vnotationKeys = [dashKey, colorKey, fillKey, radiusKey]

    static func declaredKeys(in attributes: [String: String]) -> [String] {
        vnotationKeys.filter { attributes[$0] != nil }
    }

    /// A type's own frame, else the unfolded face of its `GroupStyle`.
    public static func inherited(own: GroupFrame?, style: GroupStyle?) -> GroupFrame? {
        own ?? style?.unfolded
    }

    /// `base` with the fields `attributes` names replaced, or `nil` when it names none.
    /// A key left out keeps the inherited look rather than resetting it.
    public static func declared(in attributes: [String: String], over base: GroupFrame) throws(VError) -> GroupFrame? {
        guard !declaredKeys(in: attributes).isEmpty else { return nil }
        return GroupFrame(
            cornerRadius: try attributes[radiusKey].map(radius) ?? base.cornerRadius,
            borderDash: try attributes[dashKey].map(dash) ?? base.borderDash,
            borderColor: try attributes[colorKey].map { (hex) throws(VError) in try color(hex, colorKey) } ?? base.borderColor,
            fill: try attributes[fillKey].map { (hex) throws(VError) in try color(hex, fillKey) } ?? base.fill)
    }

    /// This frame's value for one of `vnotationKeys`, as a vnotation writes it.
    func vnotationValue(of key: String) -> String? {
        switch key {
        case Self.dashKey: return borderDash
        case Self.colorKey: return Self.hex(borderColor)
        case Self.fillKey: return Self.hex(fill)
        case Self.radiusKey: return cornerRadius.vglSpelling
        default: return nil
        }
    }

    private static func radius(_ raw: String) throws(VError) -> Double {
        guard let value = Double(raw), value >= 0 else {
            throw VError.parsingError("Invalid \(radiusKey) '\(raw)': expected a number of at least 0")
        }
        return value
    }

    /// An SVG dash pattern: empty for a solid line, else non-negative lengths.
    private static func dash(_ raw: String) throws(VError) -> String {
        let lengths = raw.split(whereSeparator: { $0 == "," || $0 == " " }).map { Double(String($0)) }
        guard lengths.allSatisfy({ ($0 ?? -1) >= 0 }) else {
            throw VError.parsingError(
                "Invalid \(dashKey) '\(raw)': expected lengths separated by commas, or \"\" for a solid line")
        }
        return raw
    }

    private static func color(_ hex: String, _ key: String) throws(VError) -> SemanticColor {
        guard let color = try? VColor.fromString(hex) else {
            throw VError.parsingError("Invalid \(key) '\(hex)': expected a hex colour such as \"#7a7a7a\"")
        }
        return SemanticColor.literal(color)
    }

    private static func hex(_ color: SemanticColor) -> String {
        let light = color.resolve(darkMode: false)
        let withAlpha = light.hexStringWithAlpha
        return withAlpha.lowercased().hasSuffix("ff") ? light.hexString : withAlpha
    }
}
