//  Tests for `ColorMath.darkOf`, the algorithmic dark-palette derivation from
//  §11 of the Vithanco Diagram Style Guide v2.

import Testing

@testable import VGraph

struct ColorMathTests {

    /// Light tints (>70% L) must collapse to a dark fill (~13% L) — same hue,
    /// desaturated. Verified against the spec example `#fdeef1` → `#2b1115` band.
    @Test func darkOfLightTintProducesDarkFill() {
        let light = VColor(hexString: "#fdeef1")!
        let dark = ColorMath.darkOf(light)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l < 20, "Light tint should drop to ~13% lightness, got \(l)")
    }

    /// Deep texts (<30% L) must rise to a pastel (~86% L) — same hue.
    @Test func darkOfDeepTextProducesLightPastel() {
        let deep = VColor(hexString: "#301878")!  // IBIS Question text
        let dark = ColorMath.darkOf(deep)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l > 80, "Deep text should rise to ~86% lightness, got \(l)")
    }

    /// Mid-band colors (30-70% L) stay vibrant — lightness lifted to at least 62%.
    @Test func darkOfMidBandStaysVibrant() {
        let mid = VColor(hexString: "#6038d0")!  // IBIS Question border
        let dark = ColorMath.darkOf(mid)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l >= 62, "Mid-band border should be lifted to ≥62% lightness, got \(l)")
    }

    /// Near-neutral colors (<8% S) just mirror lightness — keeps grays gray.
    @Test func darkOfNeutralGrayMirrorsLightness() {
        let gray = VColor(hexString: "#909090")!
        let dark = ColorMath.darkOf(gray)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        // 100 - 56.5 ≈ 43.5
        #expect(abs(l - 43.5) < 2, "Neutral gray should mirror lightness, got \(l)")
    }

    /// Hue must be preserved across the transform — that's what keeps each notation
    /// recognisable in dark mode.
    @Test func darkOfPreservesHue() {
        let light = VColor(hexString: "#ebfff2")!  // IBIS Pro fill
        let dark = ColorMath.darkOf(light)
        let (h1, _, _) = ColorMath.rgbToHSL(r: light.redComponent, g: light.greenComponent, b: light.blueComponent)
        let (h2, _, _) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(abs(h1 - h2) < 1, "Hue must be preserved, got \(h1) vs \(h2)")
    }
}
