// Several edges running the same way into or out of a folded box are drawn as one
// [[Edge bundle]]: "×n", members on hover, their shared type's look or a neutral
// one, and no edge actions of its own (ADR-0027). Runs the display pipeline's
// transforms on parsed VGL, as rendering does.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct EdgeBundleTests {

    private func displayed(_ vgl: String) throws -> VGraph {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: vgl)
        return try TransformStep.pipeline(Notations.extensionSteps)(parsed)
    }

    /// Edges by their drawn ends, since VGL mints edge ids.
    private func ends(_ graph: VGraph) -> [String] {
        graph.edges.map { "\($0.from.id)>\($0.to.id)" }.sorted()
    }

    private func render(_ graph: VGraph) throws -> String {
        var laidOut = graph
        var x = 50.0
        for node in graph.nodes {
            laidOut = try laidOut.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: x, y: 50)))
            laidOut = try laidOut.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
            x += 120
        }
        return try VSVGRenderer(logger: TestLogger()).render(graph: laidOut, darkMode: false)
    }

    private let intoTheBox = """
        vgraph cld: CLD "Demo" {
          node a: Stock "A";
          folded group g "G" {
            node x1: Stock "X1";
            node x2: Stock "X2";
          }
          edge a -> x1: same;
          edge a -> x2: same;
        }
        """

    @Test("Two edges into a folded box become one bundle, labelled with the count")
    func twoEdgesBundle() throws {
        let graph = try displayed(intoTheBox)
        let bundle = try #require(graph.edges.first)

        #expect(ends(graph) == ["a>g"])
        #expect(try graph.get(edge: bundle.id, attribute: Attributes.Edge.label) == "×2")
        #expect(graph.bundledEdgeIds(of: bundle.id).count == 2)
    }

    @Test("A bundle keeps its members' type when they share one")
    func sharedTypeKept() throws {
        let graph = try displayed(intoTheBox)
        let bundle = try #require(graph.edges.first)
        #expect(try graph.edgeType(for: bundle.id).id.id.hasPrefix("same"))
    }

    /// `same` and `opposite` together have no single polarity to show.
    @Test("A bundle of mixed types takes a neutral type")
    func mixedTypesAreNeutral() throws {
        let graph = try displayed(intoTheBox.replacingOccurrences(of: "a -> x2: same", with: "a -> x2: opposite"))
        let bundle = try #require(graph.edges.first)
        let type = try graph.edgeType(for: bundle.id)

        #expect(type.id.id.hasPrefix("bundle__"))
        #expect(graph.getAllAttributes(edgeType: type.id).isEmpty)
    }

    @Test("A single edge into a folded box stays an edge")
    func singleEdgeIsNotABundle() throws {
        let graph = try displayed(intoTheBox.replacingOccurrences(of: "  edge a -> x2: same;\n", with: ""))
        let edge = try #require(graph.edges.first)

        #expect(ends(graph) == ["a>g"])
        #expect(graph.bundledEdgeIds(of: edge.id).isEmpty)
        #expect((try? graph.get(edge: edge.id, attribute: Attributes.Edge.label)) ?? "" == "")
    }

    @Test("Edges running opposite ways are not bundled together")
    func directionsStayApart() throws {
        let graph = try displayed(intoTheBox.replacingOccurrences(of: "edge a -> x2", with: "edge x2 -> a"))
        #expect(ends(graph) == ["a>g", "g>a"])
    }

    @Test("Edges between two folded groups bundle once")
    func betweenTwoFoldedGroups() throws {
        let graph = try displayed(
            """
            vgraph cld: CLD "Demo" {
              folded group g1 "G1" {
                node p: Stock "P";
                node q: Stock "Q";
              }
              folded group g2 "G2" {
                node r: Stock "R";
                node s: Stock "S";
              }
              edge p -> r: same;
              edge q -> s: same;
            }
            """)
        #expect(ends(graph) == ["g1>g2"])
        #expect(try render(graph).contains("data-unfolds=\"g1 g2\""))
    }

    /// Loop markers project a model loop through the edges that survive; a
    /// bundled member survives as its bundle.
    @Test("A loop through a bundled edge is still marked, through the bundle")
    func loopThroughBundle() throws {
        let graph = try displayed(
            intoTheBox.replacingOccurrences(
                of: "edge a -> x2: same;", with: "edge a -> x2: same;\n  edge x1 -> a: same;"))
        let loops = graph.loopsToMark.map { loop in loop.edges.map { "\($0.from.id)>\($0.to.id)" } }
        #expect(loops == [["a>g", "g>a"]])
    }

    @Test("A bundle is drawn as one, lists its members on hover and names what it unfolds")
    func drawnAsBundle() throws {
        let svg = try render(try displayed(intoTheBox))

        #expect(svg.contains("class=\"vgraph-edge vgraph-edge-bundle\""))
        #expect(svg.contains("data-unfolds=\"g\""))
        #expect(svg.contains("<title>A → X1 (same)\nA → X2 (same)</title>"))
    }
}
