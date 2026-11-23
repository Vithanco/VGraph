////  SemanticColor behaviour. The token hexes themselves are held to the
////  design guide by StyleGuideSyncTests.
////

import Testing

@testable import VGraph

struct SemanticColorTests {

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

    @Test func aChromeLightHexKeepsTheChromeDarkHex() throws {
        let parsed = try SemanticColor.fromString(SemanticColor.groupFill.asString)
        #expect(parsed.darkHex == SemanticColor.groupFill.darkHex)
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
