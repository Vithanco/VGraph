import Testing

@testable import VGraphSVG

struct EmbedVGLTests {

    // MARK: - SVGBuilder.embedVGL unit tests

    @Test func embedVGLInsertsMetadataAfterSVGOpeningTag() {
        let svg = #"<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><rect/></svg>"#
        let vgl = #"vgraph g: IBIS "test" { }"#

        let result = SVGBuilder.embedVGL(vgl, in: svg)

        #expect(
            result.contains(
                #"<metadata><vithanco:vgl xmlns:vithanco="https://vithanco.com/ns/vgl" version="1"><![CDATA["#
            ))
        #expect(result.contains("]]></vithanco:vgl></metadata>"))
        #expect(result.contains(vgl))
    }

    /// The prefix has to be declared on the element itself: the Graphviz backend
    /// mints its own root tag, so a declaration left up there would not be in
    /// every SVG the envelope lands in.
    @Test func embedVGLDeclaresItsOwnNamespaceOnTheWrapper() {
        let result = SVGBuilder.embedVGL("x", in: #"<svg width="100"><rect/></svg>"#)

        let declaration = result.range(of: #"xmlns:vithanco="https://vithanco.com/ns/vgl""#)!
        let payload = result.range(of: "<![CDATA[x]]>")!
        #expect(declaration.lowerBound < payload.lowerBound)
    }

    @Test func embeddedVGLAppearsBeforeContent() {
        let svg = #"<svg width="100" height="100"><rect/></svg>"#
        let vgl = "some vgl"

        let result = SVGBuilder.embedVGL(vgl, in: svg)

        let metadataRange = result.range(of: "<metadata>")!
        let rectRange = result.range(of: "<rect/>")!
        #expect(metadataRange.lowerBound < rectRange.lowerBound)
    }

    @Test func embeddedVGLPreservesSVGStructure() {
        let svg = #"<svg width="200" height="300" viewBox="0 0 200 300" xmlns="http://www.w3.org/2000/svg"><g><text>hello</text></g></svg>"#
        let vgl = "test"

        let result = SVGBuilder.embedVGL(vgl, in: svg)

        #expect(result.hasPrefix("<svg"))
        #expect(result.hasSuffix("</svg>"))
        #expect(result.contains("<g><text>hello</text></g>"))
    }

    @Test func embeddedVGLHandlesSpecialCharacters() {
        let svg = #"<svg width="100" height="100"><rect/></svg>"#
        let vgl = """
            vgraph g: IBIS "test & <demo>" {
                node n1: Question "What's this?";
            }
            """

        let result = SVGBuilder.embedVGL(vgl, in: svg)

        // CDATA should preserve special characters as-is (no XML escaping needed)
        #expect(result.contains("test & <demo>"))
        #expect(result.contains("What's this?"))
    }

    @Test func embedVGLWithEmptyStringProducesEmptyCDATA() {
        let svg = #"<svg width="100" height="100"><rect/></svg>"#

        let result = SVGBuilder.embedVGL("", in: svg)

        #expect(result.contains("<![CDATA[]]></vithanco:vgl>"))
    }

    @Test func embedVGLWithMultilineVGL() {
        let svg = #"<svg width="100" height="100"><rect/></svg>"#
        let vgl = """
            vgraph g: IBIS "My Graph" {
                node q1: Question "First?";
                node a1: Answer "Yes";
                edge q1 -> a1;
            }
            """

        let result = SVGBuilder.embedVGL(vgl, in: svg)

        #expect(result.contains(vgl))
        #expect(result.hasPrefix("<svg"))
        #expect(result.hasSuffix("</svg>"))
    }

    @Test func embedVGLReturnsOriginalIfNoClosingAngle() {
        let malformed = "<svg no closing angle"
        let result = SVGBuilder.embedVGL("vgl", in: malformed)
        #expect(result == malformed)
    }

    // MARK: - SVGBuilder.extractVGL unit tests

    @Test func extractVGLRecoversWhatEmbedVGLPutIn() {
        let vgl = """
            vgraph g: IBIS "My Graph" {
                node q1: Question "First?";
                edge q1 -> a1;
            }
            """
        let svg = #"<svg width="100" height="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    // The round trip is what makes a saved diagram re-openable, so the payload
    // has to survive exactly what CDATA is there to protect.
    @Test func extractVGLRecoversSpecialCharacters() {
        let vgl = #"vgraph g: IBIS "test & <demo>" { node n1: Question "What's this?"; }"#
        let svg = #"<svg width="100" height="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    @Test func extractVGLRecoversAcrossNonASCIIContent() {
        let vgl = #"vgraph g: IBIS "Größe — 日本語" { node n1: Question "π?"; }"#
        let svg = #"<svg width="100"><text>Größe — 日本語</text></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    @Test func extractVGLIsNilWhenTheSVGCarriesNone() {
        let plain = #"<svg width="100" height="100"><metadata><title>not vgl</title></metadata></svg>"#

        #expect(SVGBuilder.extractVGL(from: plain) == nil)
    }

    @Test func extractVGLIsNilOnAnUnterminatedEnvelope() {
        let truncated = #"<svg><metadata><vgl><![CDATA[vgraph g: IBIS "cut off""#

        #expect(SVGBuilder.extractVGL(from: truncated) == nil)
    }

    // MARK: - CDATA terminators in the payload

    /// A label carrying `]]>` used to end the CDATA section early, leaving an
    /// SVG that no XML parser — a browser opening the file included — will read.
    @Test func embedVGLSplitsCDATATerminatorsInThePayload() {
        let vgl = #"vgraph g: IBIS "a]]>b" { }"#

        let result = SVGBuilder.embedVGL(vgl, in: #"<svg width="100"><rect/></svg>"#)

        #expect(result.contains(#"a]]]]><![CDATA[>b"#))
        #expect(!result.contains(#"a]]>b"#))
    }

    @Test func extractVGLRejoinsASplitCDATATerminator() {
        let vgl = #"vgraph g: IBIS "a]]>b" { }"#
        let svg = #"<svg width="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    /// The escape is itself made of characters the escape looks for, so a payload
    /// that spells one out is the case where a leftmost-first rewrite could eat
    /// its own tail.
    @Test func extractVGLSurvivesAPayloadThatSpellsOutTheEscape() {
        let vgl = #"]]]]><![CDATA[>"#
        let svg = #"<svg width="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    @Test func extractVGLRejoinsEveryTerminatorNotJustTheFirst() {
        let vgl = "a]]>b]]>c"
        let svg = #"<svg width="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL(vgl, in: svg)) == vgl)
    }

    // MARK: - Reading what earlier versions wrote

    /// Diagrams saved before the envelope was namespaced are documents too.
    @Test func extractVGLReadsTheLegacyUnnamespacedEnvelope() {
        let legacy =
            #"<svg width="100"><metadata><vgl><![CDATA[vgraph g: IBIS "old" { }]]></vgl></metadata><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: legacy) == #"vgraph g: IBIS "old" { }"#)
    }

    @Test func extractVGLOfAnEmptyPayloadIsEmpty() {
        let svg = #"<svg width="100" height="100"><rect/></svg>"#

        #expect(SVGBuilder.extractVGL(from: SVGBuilder.embedVGL("", in: svg)) == "")
    }
}
