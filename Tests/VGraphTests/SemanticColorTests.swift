////  Verifies the SemanticColor catalogue: structural tokens match the v2
////  Diagram Style Guide `CHROME_DARK` mapping verbatim; literal / derived
////  tokens go through `ColorMath.darkOf` consistently.
////

import Testing

@testable import VGraph

struct SemanticColorTests {

    /// Structural tokens (edges, ink, groups, watermark…) carry **explicit**
    /// light + dark hex pairs from the v2 design system. The dark side must
    /// match the CHROME_DARK mapping exactly, not be derived.
    @Test func structuralTokensMatchDesignSystem() {
        // Each tuple: (token, expected lightHex, expected darkHex).
        // Values lifted from `Diagram Style Guide v2.html` lines 284–300.
        let cases: [(SemanticColor, String, String)] = [
            (.edge, "#b0a898", "#6e6a60"),
            (.edgeBold, "#5a564e", "#a8a49a"),
            (.junctor, "#303030", "#e8e3db"),
            (.ink, "#1a1816", "#ecebe5"),
            (.ink2, "#5a564e", "#a8a49a"),
            (.ink3, "#9a9690", "#6e6a62"),
            (.groupFill, "#f4f3f0", "#1c1a16"),
            (.groupBorder, "#909088", "#7a766e"),
            (.groupText, "#505048", "#c8c4bc"),
            (.groupNestedFill, "#efefef", "#22201c"),
            (.groupStack, "#e8e7e4", "#1a1814"),
            (.pillBg, "#eeece8", "#262420"),
            (.pillText, "#807870", "#a8a49a"),
            (.loopIndicator, "#808078", "#a8a49a"),
            (.watermark, "#c8c4bc", "#4a4842"),
        ]
        for (token, light, dark) in cases {
            #expect(token.lightHex == light, "Token \(token.id) light mismatch")
            #expect(token.darkHex == dark, "Token \(token.id) dark mismatch")
        }
    }

    /// Style guide Key Rule 1: dark mode is keyed on the light hex. White and
    /// black are the documented exceptions — they serve both as theme-fixed
    /// glyph colours and as canvas/label colours that flip.
    @Test func tokensSharingALightHexShareTheirDarkHex() {
        let tokens: [SemanticColor] = [
            .page, .edgeEndFill, .edge, .edgeBold, .junctor, .ink, .ink2, .ink3, .groupFill, .groupBorder,
            .groupText,
            .groupNestedFill, .groupStack, .pillBg, .pillText, .loopIndicator, .watermark,
            .ghostPillFill, .ghostPillText, .foldedBadgeFill, .linkBadgeFill,
        ]
        let byLight = Dictionary(grouping: tokens) { $0.lightHex.lowercased() }
        for (light, group) in byLight {
            let darks = Set(group.map { $0.darkHex.lowercased() })
            #expect(darks.count == 1, "Tokens with light \(light) disagree in dark: \(group)")
        }
    }

    /// `.literal(lightHex:)` derives the dark side via `ColorMath.darkOf`.
    /// Verify the round-trip: a light hex becomes a SemanticColor whose dark
    /// equivalent matches what darkOf would produce.
    @Test func literalConstructorUsesDarkOf() {
        let light = "#f0ebff"
        let token = SemanticColor.literal(lightHex: light)
        let expectedDark = ColorMath.darkHex(of: light)
        #expect(token.lightHex == light)
        #expect(token.darkHex == expectedDark)
        #expect(token.id == "literal")
    }

    /// The two-arg `init(id:lightHex:)` (no explicit dark) defers to `darkOf`.
    /// Used for per-notation tokens where only the light side is in the spec.
    @Test func derivedDarkConstructor() {
        let token = SemanticColor(id: "ibis.question.fill", lightHex: "#f0ebff")
        #expect(token.darkHex == ColorMath.darkHex(of: "#f0ebff"))
    }

    /// `darken(to:)` must apply per side so the resulting token stays theme-aware.
    @Test func darkenAppliesPerSide() {
        let blue = SemanticColor(id: "test.blue", lightHex: "#6038d0", darkHex: "#a08fe8")
        let darker = blue.darken(to: 0.3)
        let expectedLight = (VColor(hexString: "#6038d0") ?? .black).darken(to: 0.3).hexString
        let expectedDark = (VColor(hexString: "#a08fe8") ?? .black).darken(to: 0.3).hexString
        #expect(darker.lightHex == expectedLight)
        #expect(darker.darkHex == expectedDark)
    }

    /// `resolve(darkMode:)` returns the right side of the pair.
    @Test func resolvePicksTheRightSide() {
        let token = SemanticColor.watermark
        #expect(token.resolve(darkMode: false).hexString == "#c8c4bc")
        #expect(token.resolve(darkMode: true).hexString == "#4a4842")
    }

    /// VGL wire format round-trip: a SemanticColor serialised via `asString`
    /// and re-read via `fromString` produces a `.literal` token whose visual
    /// value matches the original light side.
    @Test func vglWireFormatRoundTrip() throws {
        let original = SemanticColor.watermark
        let wire = original.asString
        let parsed = try SemanticColor.fromString(wire)
        // Light side is preserved; dark side may differ (derived vs explicit),
        // which is the documented trade-off — semantic identity does not survive.
        #expect(
            parsed.resolve(darkMode: false).hexString
                == original.resolve(darkMode: false).hexString)
        #expect(parsed.id == "literal")
    }
}
