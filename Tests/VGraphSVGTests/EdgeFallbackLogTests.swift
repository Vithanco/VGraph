import TestSupport
import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct EdgeFallbackLogTests {
    @Test(
        "Given an edge whose route falls back to a straight line, labelled SECRET-LABEL-7731, when rendered at the default level, then a warning names the edge id and not the label"
    )
    func fallbackWarningNamesEdgeOnly() throws {
        let secret = "SECRET-LABEL-7731"
        let capture = LogCapture()
        let graph = try VGraphParser(logger: NoOpLogger()).parse(
            source: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  edge a -> b "\(secret)";
                }
                """)
        let edge = try #require(graph.edges.first)
        _ = try VSVGRenderer(logger: CaptureLogger(capture)).render(graph: graph, darkMode: false)

        #expect(capture.text.contains(edge.id.description))
        #expect(!capture.text.contains(secret))
    }
}

private struct CaptureLogger: VForLogMessages {
    let capture: LogCapture
    init(_ capture: LogCapture) { self.capture = capture }
    func log(_ message: String) { capture.write(message) }
}
