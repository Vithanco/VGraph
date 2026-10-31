////
////  SemanticColor.swift
////  VGraph
////
////  A theme-aware colour token: an explicit light + dark hex pair resolved to a
////  concrete `VColor` at render time, once `darkMode` is known.
////

import MathUtils

public struct SemanticColor: Hashable, Sendable {
    public let id: String
    public let lightHex: String
    public let darkHex: String

    public init(id: String, lightHex: String, darkHex: String) {
        self.id = id
        self.lightHex = lightHex
        self.darkHex = darkHex
    }

    public init(id: String, lightHex: String) {
        self.id = id
        self.lightHex = lightHex
        self.darkHex = ColorMath.darkHex(of: lightHex)
    }

    public static func literal(lightHex: String) -> SemanticColor {
        SemanticColor(id: "literal", lightHex: lightHex)
    }

    public static func literal(_ color: VColor) -> SemanticColor {
        // Keep alpha: lifting via the alpha-less `hexString` would silently turn a
        // transparent colour opaque on round-trip (a boundary's clear fill would
        // render as solid black).
        SemanticColor.literal(lightHex: color.hexStringWithAlpha)
    }

    public func resolve(darkMode: Bool) -> VColor {
        VColor(hexString: darkMode ? darkHex : lightHex) ?? .black
    }

    /// Named to match the old `VColor.hexString`, so notation tests and assertion
    /// call sites kept compiling through the move to tokens.
    public var hexString: String { lightHex }

    // MARK: - Derivations

    public func darken(to factor: Double) -> SemanticColor {
        let light = (VColor(hexString: lightHex) ?? .black).darken(to: factor).hexString
        let dark = (VColor(hexString: darkHex) ?? .black).darken(to: factor).hexString
        return SemanticColor(id: "\(id).darken(\(factor))", lightHex: light, darkHex: dark)
    }

    /// `bwContrastColor`'s judgement without its answer, so a recolour can ask
    /// whether text still reads before deciding to overwrite it.
    public var isLight: Bool {
        (VColor(hexString: lightHex) ?? .black).bwContrastColor.hexString.lowercased() == "#000000"
    }

    public var bwContrastColor: SemanticColor {
        let light = (VColor(hexString: lightHex) ?? .black).bwContrastColor.hexString
        let dark = (VColor(hexString: darkHex) ?? .black).bwContrastColor.hexString
        return SemanticColor(id: "\(id).bwContrast", lightHex: light, darkHex: dark)
    }
}

// MARK: - Structural tokens
//
// Pairs from §11 of the Vithanco Diagram Style Guide v2 (`CHROME_DARK`). Chrome
// keeps its dark hexes explicit rather than derived, so the design intent stays
// auditable 1:1 against the style guide.

extension SemanticColor {
    /// The canvas a diagram sits on (Rule 4: dark is `#0e0d0a`, not black). The
    /// SVG leaves it to the host, so the host must use this.
    public static let page = SemanticColor(id: "page", lightHex: "#faf9f6", darkHex: "#0e0d0a")
    public static let edge = SemanticColor(id: "edge", lightHex: "#b0a898", darkHex: "#6e6a60")
    public static let edgeBold = SemanticColor(id: "edge.bold", lightHex: "#5a564e", darkHex: "#a8a49a")
    public static let junctor = SemanticColor(id: "junctor", lightHex: "#303030", darkHex: "#e8e3db")
    /// The hole in an [[Edge end]] handle's ring. Canvas rather than a colour of
    /// its own: the ring reads as a hole in the diagram and takes its stroke from
    /// the edge it belongs to, so it cannot contradict the notation (ADR-0021).
    public static let edgeEndFill = SemanticColor(id: "edge.end.fill", lightHex: page.lightHex, darkHex: page.darkHex)

    // Headings, axis labels, generic text inside SVGs
    public static let ink = SemanticColor(id: "ink", lightHex: "#1a1816", darkHex: "#ecebe5")
    public static let ink2 = SemanticColor(id: "ink.2", lightHex: "#5a564e", darkHex: "#a8a49a")
    public static let ink3 = SemanticColor(id: "ink.3", lightHex: "#9a9690", darkHex: "#6e6a62")

    public static let groupFill = SemanticColor(id: "group.fill", lightHex: "#f4f3f0", darkHex: "#1c1a16")
    public static let groupBorder = SemanticColor(id: "group.border", lightHex: "#909088", darkHex: "#7a766e")
    public static let groupText = SemanticColor(id: "group.text", lightHex: "#505048", darkHex: "#c8c4bc")
    public static let groupNestedFill = SemanticColor(id: "group.nested.fill", lightHex: "#efefef", darkHex: "#22201c")
    public static let groupStack = SemanticColor(id: "group.stack", lightHex: "#e8e7e4", darkHex: "#1a1814")

    // Ghost / count badges
    public static let pillBg = SemanticColor(id: "pill.bg", lightHex: "#eeece8", darkHex: "#262420")
    public static let pillText = SemanticColor(id: "pill.text", lightHex: "#807870", darkHex: "#a8a49a")

    public static let loopIndicator = SemanticColor(id: "loop.indicator", lightHex: "#808078", darkHex: "#a8a49a")

    /// An icon on a node type badge's coloured background. Dark mode brightens that
    /// background, and white on it falls below 3:1 for most types.
    public static let badgeIcon = SemanticColor(id: "badge.icon", lightHex: "#ffffff", darkHex: "#14120f")
    public static let watermark = SemanticColor(id: "watermark", lightHex: "#c8c4bc", darkHex: "#4a4842")

    // Plain black and white stay theme-fixed; `labelText` is the one that flips.
    public static let white = SemanticColor(id: "white", lightHex: "#ffffff", darkHex: "#ffffff")
    public static let black = SemanticColor(id: "black", lightHex: "#000000", darkHex: "#000000")
    public static let labelText = SemanticColor(id: "label.text", lightHex: "#000000", darkHex: "#ffffff")

    // Meta-node tokens: light hexes carried over from the inline literals that used
    // to sit in PredefinedStyles.swift, dark hexes derived.
    public static let annotationFill = SemanticColor(id: "annotation.fill", lightHex: "#fefce8")
    public static let annotationBorder = SemanticColor(id: "annotation.border", lightHex: "#b8980a")
    public static let annotationText = SemanticColor(id: "annotation.text", lightHex: "#4a3c08")
    public static let warningFill = SemanticColor(id: "warning.fill", lightHex: "#fff1f2")
    public static let warningBorder = SemanticColor(id: "warning.border", lightHex: "#c02838")
    public static let warningText = SemanticColor(id: "warning.text", lightHex: "#7a0810")
    public static let ghostPillFill = SemanticColor(id: "ghost.pill.fill", lightHex: "#eeece8", darkHex: "#262420")
    public static let ghostPillText = SemanticColor(id: "ghost.pill.text", lightHex: "#807870", darkHex: "#a8a49a")
    public static let foldedBadgeFill = SemanticColor(id: "folded.badge.fill", lightHex: "#909088", darkHex: "#7a766e")
    /// The link badge, in the same grey as the folded-group badge — it is the same
    /// visual language (a small chip clipped to a corner), for a different fact.
    public static let linkBadgeFill = SemanticColor(id: "link.badge.fill", lightHex: "#909088", darkHex: "#7a766e")
}

// MARK: - Serialisation
//
// Only the light hex goes on the wire, so a round-tripped colour comes back as a
// literal: it loses its semantic identity but keeps visual fidelity in both themes,
// the dark side re-derived by `ColorMath.darkOf`.

extension SemanticColor {
    public var asString: String {
        resolve(darkMode: false).asString
    }

    public static func fromString(_ string: String) throws(VError) -> SemanticColor {
        let color = try VColor.fromString(string)
        return .literal(color)
    }
}

extension SemanticColor: CustomStringConvertible {
    public var description: String {
        "\(id)(\(lightHex)/\(darkHex))"
    }
}
