// How a `vnotation` spells a boundary. Reading and export both go through this
// table, so their spellings cannot drift apart.
extension BoundaryChrome {
    private static let dashKey = "boundaryDash"
    private static let colorKey = "boundaryColor"
    private static let fillKey = "boundaryFill"
    private static let radiusKey = "boundaryRadius"

    /// In the order export writes them.
    static let vnotationKeys = [dashKey, colorKey, fillKey, radiusKey]

    static func declaredKeys(in attrs: [String: String]) -> [String] {
        vnotationKeys.filter { attrs[$0] != nil }
    }

    /// A type's own boundary, else the unfolded face of its `GroupStyle`.
    public static func inherited(boundary: BoundaryChrome?, style: GroupStyle?) -> BoundaryChrome? {
        boundary ?? style?.unfolded
    }

    /// `base` with the fields `attrs` names replaced, or `nil` when it names none.
    /// A key left out keeps the inherited look rather than resetting it.
    public static func declared(in attrs: [String: String], over base: BoundaryChrome) throws(VError) -> BoundaryChrome? {
        guard !declaredKeys(in: attrs).isEmpty else { return nil }
        return BoundaryChrome(
            cornerRadius: try attrs[radiusKey].map(radius) ?? base.cornerRadius,
            borderDash: try attrs[dashKey].map(dash) ?? base.borderDash,
            borderColor: try attrs[colorKey].map { (hex) throws(VError) in try color(hex, colorKey) } ?? base.borderColor,
            fill: try attrs[fillKey].map { (hex) throws(VError) in try color(hex, fillKey) } ?? base.fill)
    }

    /// This boundary's value for one of `vnotationKeys`, as a vnotation writes it.
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
