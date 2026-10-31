// A folded group is drawn from a stand-in node in the display graph, but the box
// on screen represents the group, so it is stamped as one (ADR-0027). The box, the
// rule that lights it on hover and the rule that lights its neighbours must all
// use the same id, or hovering stops working on exactly the folded boxes.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct FoldedGroupIdentityTests {

    private let folded = """
        vgraph demo: ConceptMap "Demo" {
          node outside: Concept "Outside";
          folded group g1 "Cluster" {
            node inner: Concept "Inner";
          }
          edge outside -> inner;
        }
        """

    /// The display pipeline's transforms, then a hand-made layout, as Graphviz
    /// would leave it.
    private func render(_ vgl: String) throws -> String {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: vgl)
        var graph = try TransformStep.pipeline(Notations.extensionSteps)(parsed)
        var x = 50.0
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: x, y: 50)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
            x += 120
        }
        return try VSVGRenderer(logger: TestLogger()).render(graph: graph, darkMode: false)
    }

    @Test("A folded box is stamped as its group, not as a node")
    func stampedAsGroup() throws {
        let svg = try render(folded)

        #expect(svg.contains("id=\"group-g1\" class=\"vgraph-node vgraph-folded-group\""))
        #expect(!svg.contains("id=\"node-g1\""))
    }

    @Test("Hovering a folded box lights its edges, and hovering its neighbour lights the box")
    func hoverReachesTheBox() throws {
        let svg = try render(folded)

        #expect(svg.contains("svg:has(#group-g1:hover) #node-outside"))
        #expect(svg.contains("svg:has(#node-outside:hover) #group-g1"))
        #expect(!svg.contains("#node-g1"))
    }
}
