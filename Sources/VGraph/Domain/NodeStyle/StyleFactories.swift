/// Maps `nodeStyle:` string values from `vnotation` declarations to `NodeStyleLayout` instances.
///
/// Adding a new `PredefinedStyle` requires one new `case` in `buildStyle` — no other file changes.
/// The parser treats `nodeStyle:` values as opaque strings; this is the single semantic layer
/// that validates them and constructs the corresponding `NodeStyleLayout`.
public enum StyleFactories {

    // MARK: - Public API

    /// Throws `VError.parsingError` if `spec.nodeStyle` is not a known value.
    public static func buildStyle(for spec: NodeTypeSpec) throws(VError) -> NodeStyleLayout {
        switch spec.nodeStyle {
        case "iconWithText":
            return .iconWithText(
                backgroundColor: color(from: spec.rawAttrs),
                icon: makeIcon(from: spec.rawAttrs, defaultIconColorHex: "#ffffff")
            )
        case "simpleRoundedText":
            return .simpleRoundedText(color: color(from: spec.rawAttrs))
        case "roundedBox":
            return .simpleRoundedBox(color: color(from: spec.rawAttrs))
        case "withCategory":
            return .withCategory(
                category: spec.rawAttrs["category"] ?? spec.name,
                categoryColor: color(from: spec.rawAttrs)
            )
        case "withCategoryAndIcon":
            return .withCategoryAndIcon(
                category: spec.rawAttrs["category"] ?? spec.name,
                categoryColor: color(from: spec.rawAttrs),
                icon: makeIcon(from: spec.rawAttrs, defaultIconColorHex: "#ffffff")
            )
        case "iconOnly":
            return .iconOnly(icon: makeIcon(from: spec.rawAttrs, defaultIconColorHex: "#000000"))
        case "circle":
            return .circle(color: color(from: spec.rawAttrs))
        case "bareText":
            return .bareText
        case "hidden":
            return .hidden
        // `custom` is an explicit escape hatch: falls back to bareText in v1.
        // Reserved for when full NodeStyleLayout expressions become VGL-expressible.
        case "custom":
            return .bareText
        default:
            throw VError.parsingError(
                "Unknown nodeStyle '\(spec.nodeStyle ?? "unknown")' for node type '\(spec.name)'. "
                    + "Valid values: iconWithText, simpleRoundedText, roundedBox, withCategory, "
                    + "withCategoryAndIcon, iconOnly, circle, bareText, hidden, custom"
            )
        }
    }

    // MARK: - Helpers (used by DynamicNotation)

    /// User-provided colour from VGL `nodeStyle:` attributes. Returned as a
    /// literal `SemanticColor` — semantic identity is unknown, dark variant is
    /// algorithmically derived. Matches the trade-off VGL round-trip already makes.
    public static func color(from attrs: [String: String], default defaultHex: String = "#888888") -> SemanticColor {
        if let raw = value(of: "backgroundColor", in: attrs) ?? value(of: "color", in: attrs),
            let color = try? VColor.fromString(raw)
        {
            return .literal(color)
        }
        return .literal(lightHex: defaultHex)
    }

    /// `vnotation` keys arrive as the author spelled them: they never pass through
    /// `find(attributeByName:)`, which is what normalises everywhere else.
    static func value(of key: String, in attrs: [String: String]) -> String? {
        if let exact = attrs[key] { return exact }
        let wanted = key.lowercased()
        for (k, v) in attrs where k.lowercased() == wanted { return v }
        return nil
    }

    static func iconColor(from attrs: [String: String], default defaultHex: String) -> VColor {
        if let raw = attrs["iconColor"], let c = try? VColor.fromString(raw) { return c }
        return VColor(hexString: defaultHex) ?? VColor.black
    }

    static func iconSize(from attrs: [String: String]) -> Double {
        if let s = attrs["iconSize"], let d = Double(s) { return d }
        return 24
    }

    public static func makeIcon(
        from attrs: [String: String],
        defaultIconColorHex: String
    ) -> IconInfo {
        IconInfo(
            iconPosition: .top,
            // Naming no icon means the author did not choose one — not the same
            // as naming one nobody has, which draws the missing-icon placeholder (ADR-0022).
            iconName: attrs["icon"] ?? "default",
            iconColor: iconColor(from: attrs, default: defaultIconColorHex),
            iconSize: iconSize(from: attrs)
        )
    }
}
