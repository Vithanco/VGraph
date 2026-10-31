// Design-token resolution (Vithanco Diagram Style Guide §11), shared by both SVG
// backends. The attribute system stores one concrete `VColor`, so "did the author
// choose this, or is it just the design default?" can only be answered by
// comparing against the token's light hex.

import VGraph

enum SVGThemeColor {

    /// Group chrome. The attribute's own static default *is* the design's light
    /// hex, so any group rendered without an explicit override flips to the dark
    /// hex in dark mode. An explicit override to a different color is honored
    /// as-is in both themes — the caller chose that exact color.
    static func group(_ raw: VColor, semantic: SemanticColor, darkMode: Bool) -> VColor {
        if raw.hexString.lowercased() == semantic.lightHex.lowercased() {
            return semantic.resolve(darkMode: darkMode)
        }
        return raw
    }

    /// Edge and arrowhead colors are read back from the colors Graphviz echoes in
    /// its draw ops. An edge we emit *without* an explicit color comes back as
    /// Graphviz's default black (`#000000`); map that to the `--edge` token
    /// (#b0a898 light / #6e6a60 dark) so default edges read correctly in both
    /// themes. Any explicit (non-black) color the model chose is honored unchanged.
    static func edge(_ hex: String, darkMode: Bool) -> VColor {
        guard let raw = try? VColor.fromString(hex), raw.hexString.lowercased() != "#000000" else {
            return SemanticColor.edge.resolve(darkMode: darkMode)
        }
        return raw
    }

    /// `IconInfo` stores one concrete colour, so — as with groups — an icon in the
    /// junctor's light hex is the junctor token and flips with the theme.
    static func icon(_ raw: VColor, darkMode: Bool) -> VColor {
        group(raw, semantic: SemanticColor.junctor, darkMode: darkMode)
    }
}
