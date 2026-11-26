import Foundation
import TestSupport
import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

// The exporter asks Graphviz for a spacer line between the nodes and the caption,
// so the label block Graphviz reserves holds two lines. Drawn at the block's
// centre, the caption sat on the spacer and left its own line empty below it.
struct GraphCaptionTests {

    func baseline(of svg: String, caption: String) throws -> Double {
        let match = try #require(
            svg.matches(of: #/<text [^>]*y="([-0-9.]+)"[^>]*>([^<]*)</text>/#).first { $0.output.2 == caption })
        return try #require(Double(match.output.1))
    }

    func labelled(at center: VPoint, size: VSize, location: String) throws -> VGraph {
        let source = "vgraph g: IBIS \"Caption\" {\n labelLocation: \(location);\n node q: Question \"Q\";\n}"
        return try VGraphParser(logger: TestLogger()).parse(source: source)
            .setting(group: Group.root, attribute: Attributes.Group.labelLayoutedPos(center))
            .setting(group: Group.root, attribute: Attributes.Group.labelLayoutedSize(size))
    }

    @Test("Given a caption below the diagram, then it is drawn on the lower line of its two-line block")
    func bottomCaptionOnLowerLine() throws {
        let block = VSize(width: 200, height: 32.8)
        let graph = try labelled(at: VPoint(x: 100, y: 300), size: block, location: "b")
        let y = try baseline(of: VSVGGraph.renderGraphLabel(graph: graph, darkMode: false).render(), caption: "Caption")
        #expect(y > 300 + 4 && y <= 300 + block.height / 2, "baseline \(y)")
    }

    @Test("Given a caption above the diagram, then it stays within its one-line block")
    func topCaptionInsideBlock() throws {
        let block = VSize(width: 200, height: 16.4)
        let graph = try labelled(at: VPoint(x: 100, y: 20), size: block, location: "t")
        let y = try baseline(of: VSVGGraph.renderGraphLabel(graph: graph, darkMode: false).render(), caption: "Caption")
        #expect(y > 20 && y <= 20 + block.height / 2, "baseline \(y)")
    }

    @Test("Given a captioned diagram, when it is rendered, then the space below the caption is no larger than the margin plus a descender")
    func noEmptyLineBelowCaption() throws {
        let svg = try VGraphTestApp().renderGraph(
            """
            vgraph g: IBIS "Should we ship?" {
                watermark: false;
                node q: Question "Ship it?";
                node a: Answer "Yes";
                node b: Answer "No";
                edge q -> a;
                edge q -> b;
            }
            """).svg
        let viewBox = try #require(svg.firstMatch(of: #/viewBox="([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+)"/#))
        let bottom = try #require(Double(viewBox.output.2)) + #require(Double(viewBox.output.4))
        let margin = 50.0
        let space = bottom - (try baseline(of: svg, caption: "Should we ship?"))
        #expect(space < margin + 10, "space below the caption's baseline: \(space), margin: \(margin)")
    }
}
