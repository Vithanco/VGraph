// The `loopmarkers` setting is a graph attribute, so it has to round-trip through
// the exporter, and stay out of the document while it is at its default.

import Testing

@testable import VGLanguage
@testable import VGraph

struct LoopMarkersVGLTests {

    private func triangle(_ setting: String) -> String {
        """
        vgraph cld: CLD "Triangle" {
          \(setting)
          node a: Stock "A";
          node b: Stock "B";
          node c: Stock "C";
          edge a -> b: same;
          edge b -> a: same;
          edge b -> c: same;
          edge c -> b: same;
          edge a -> c: same;
          edge c -> a: same;
        }
        """
    }

    @Test("The setting survives export and reparse")
    func settingRoundTrips() throws {
        let parsed = try VGraphParser(logger: NoOpLogger()).parse(source: triangle("loopmarkers: independent;"))
        let exported = try VGLExporter().export(graph: parsed)

        #expect(exported.contains("loopmarkers: independent"))
        let reparsed = try VGraphParser(logger: NoOpLogger()).parse(source: exported)
        #expect(try reparsed.get(attribute: Attributes.Group.loopMarkers) == .independent)
    }

    @Test("The default is not written out")
    func defaultIsNotExported() throws {
        let parsed = try VGraphParser(logger: NoOpLogger()).parse(source: triangle(""))
        #expect(!(try VGLExporter().export(graph: parsed)).contains("loopmarkers"))
    }
}
