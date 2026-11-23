/// The colour and icon a `vnotation` node type's attributes name, as the
/// author spelled them. The parser hands them over as opaque strings.
public enum VNotationTypeAttributes {

    /// User-provided colour from VGL `nodeStyle:` attributes. Returned as a
    /// literal `SemanticColor` — semantic identity is unknown, dark variant is
    /// algorithmically derived. Matches the trade-off VGL round-trip already makes.
    public static func color(from attributes: [String: String], default defaultHex: String = "#888888") -> SemanticColor {
        if let raw = value(of: "backgroundColor", in: attributes) ?? value(of: "color", in: attributes),
            let color = try? VColor.fromString(raw)
        {
            return .literal(color)
        }
        return .literal(lightHex: defaultHex)
    }

    /// `vnotation` keys arrive as the author spelled them: they never pass through
    /// `find(attributeByName:)`, which is what normalises everywhere else.
    static func value(of key: String, in attributes: [String: String]) -> String? {
        let wanted = key.lowercased()
        return attributes[key] ?? attributes.first { $0.key.lowercased() == wanted }?.value
    }

    static func iconColor(from attributes: [String: String], default defaultHex: String) -> VColor {
        attributes["iconColor"].flatMap { try? VColor.fromString($0) } ?? VColor(hexString: defaultHex) ?? VColor.black
    }

    static func iconSize(from attributes: [String: String]) -> Double {
        attributes["iconSize"].flatMap { Double($0) } ?? 24
    }

    public static func makeIcon(
        from attributes: [String: String],
        defaultIconColorHex: String
    ) -> IconInfo {
        IconInfo(
            iconPosition: .top,
            // Naming no icon means the author did not choose one — not the same
            // as naming one nobody has, which draws the missing-icon placeholder (ADR-0022).
            iconName: attributes["icon"] ?? "default",
            iconColor: iconColor(from: attributes, default: defaultIconColorHex),
            iconSize: iconSize(from: attributes)
        )
    }
}
