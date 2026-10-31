// The group label must be separately identifiable in the SVG so double-click
// editing can target it. See ADR-0009.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct GroupLabelStampTests {

    private func renderGraphWithGroup() throws -> String {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                };
            }
            """
        let graph = try VGraphParser(logger: TestLogger()).parse(source: input)

        var layouted = graph
        for node in graph.nodes {
            layouted = try layouted.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            layouted = try layouted.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        // A group renders only once Graphviz has given it bounds.
        layouted = try layouted.set(
            group: Group(rawValue: "g1"),
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(origin: VPoint(x: 0, y: 0), size: VSize(width: 200, height: 120))))

        return try VSVGRenderer(logger: TestLogger()).render(graph: layouted)
    }

    /// A group's boundary covers the elements inside it, so hit-testing the whole
    /// `.vgraph-group` would make every click in the cluster a rename. The label
    /// carries its own class so only the title is a target.
    @Test func groupLabelIsStampedSoItCanBeTargetedApartFromTheBoundary() throws {
        let svg = try renderGraphWithGroup()

        #expect(svg.contains("vgraph-group-label"))
    }

    /// The style guide renders group titles uppercased, so what is drawn is *not*
    /// the stored label. An inline editor must therefore seed itself from the graph
    /// attribute rather than the rendered text, or renaming would upper-case the
    /// label permanently.
    @Test func renderedGroupTitleIsUppercasedAndSoDiffersFromTheStoredLabel() throws {
        let svg = try renderGraphWithGroup()

        #expect(svg.contains("MY GROUP"))
        #expect(!svg.contains(">My Group<"))
    }
}
