/// Helpers that turn `vnotation` `nodeStyle:` attributes into colours and icons for `NodeStyleLayout`.
/// The parser treats `nodeStyle:` values as opaque strings.
public enum StyleFactories {

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
