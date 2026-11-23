import TestSupport
import Testing

@testable import App
@testable import VGraph
@testable import VGraphvizLib

/// Node sizes are stored in points; inches exist only at the DOT boundary.
@Suite("Node size in DOT")
struct NodeSizeDotTests {

    private func dot(_ source: String) throws -> String {
        try DotExporter().export(graph: VGraphTestApp().parseGraph(source))
    }

    /// 54 × 36 points is Graphviz's own default of 0.75 × 0.5 inches, so DOT need not say it.
    @Test
    func aNodeAtTheDefaultSizeWritesNoSize() throws {
        let output = try dot(
            """
            vgraph g: IBIS "Sizes" {
                node q: Question "Why?" [width: 54, height: 36]
            }
            """)

        #expect(!output.contains("width="))
        #expect(!output.contains("height="))
    }

    @Test
    func aLargerNodeWritesItsSizeInInches() throws {
        let output = try dot(
            """
            vgraph g: IBIS "Sizes" {
                node q: Question "Why?" [width: 144, height: 72]
            }
            """)

        #expect(output.contains("width=\"2"))
        #expect(output.contains("height=\"1"))
    }
}
