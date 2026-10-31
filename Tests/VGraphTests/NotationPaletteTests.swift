import Testing

@testable import VGraph

/// What `StyleGuideSyncTests` cannot see: the guide gives Desirable Effect only to
/// FRT/TRT, so CRT's copy is held to theirs here.
struct NotationPaletteTests {

    private func expectTriple(
        _ fill: SemanticColor, _ border: SemanticColor, _ text: SemanticColor, _ expected: (String, String, String),
        _ name: String
    ) {
        #expect(fill.lightHex == expected.0, "\(name) fill")
        #expect(border.lightHex == expected.1, "\(name) border")
        #expect(text.lightHex == expected.2, "\(name) text")
    }

    /// The guide defines one Desirable Effect palette; CRT shares it with FRT and TRT.
    @Test func desirableEffectIsTheSameAcrossRealityTrees() {
        let guide = ("#d8fce0", "#18a848", "#085028")
        typealias CRT = Notations.CurrentRealityTree
        typealias FRT = Notations.FutureRealityTree
        typealias TRT = Notations.TransitionTree
        expectTriple(CRT.deFill, CRT.deBorder, CRT.deText, guide, "CRT Desirable Effect")
        expectTriple(FRT.deFill, FRT.deBorder, FRT.deText, guide, "FRT Desirable Effect")
        expectTriple(TRT.deFill, TRT.deBorder, TRT.deText, guide, "TRT Desirable Effect")
    }
}
