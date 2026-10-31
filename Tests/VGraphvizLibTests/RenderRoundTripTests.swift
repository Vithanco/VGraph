// Rendered output must carry its own source, so a saved SVG can be reopened.

import App
import TestSupport
import Testing
import VGraph

struct RenderRoundTripTests {
    /// Spelled out rather than reached for through `SVGBuilder`, so that a
    /// change to the envelope has to be made deliberately here too.
    let vglEnvelopeOpen =
        #"<metadata><vithanco:vgl xmlns:vithanco="https://vithanco.com/ns/vgl" version="1"><![CDATA["#

    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          node b: Concept "B";
          edge a -> b;
        }
        """

    @Test func renderedSVGCarriesItsSource() throws {
        let svg = try VGraphTestApp().renderGraph(vgl).svg

        #expect(svg.contains(vglEnvelopeOpen))
        #expect(svg.contains("node a: Concept \"A\";"))
    }

    /// The session renders from the in-memory OriginGraph, so its embedded VGL
    /// comes from re-export rather than the original text — it must still be
    /// there, and must still reparse.
    @Test func sessionRenderCarriesReExportedSource() throws {
        let session = try VGraphTestApp().makeSession(vgl: vgl)
        let svg = try session.render().svg

        #expect(svg.contains(vglEnvelopeOpen))
        #expect(svg.contains("Concept"))
    }
}
