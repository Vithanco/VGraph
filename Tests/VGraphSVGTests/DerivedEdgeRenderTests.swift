import Testing

@testable import App
@testable import TestSupport
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

private let shop = """
    vgraph shop: CLD "Shop" {
        node demand: Stock "Demand";
        node stock: Stock "Stock";
        node price: Stock "Price";
        edge demand -> stock: same;
        edge stock -> price: opposite;
    }

    vview overview "Overview" {
        exclude node stock;
    }

    vview plain "Plain" [derivedEdges: false] {
        exclude node stock;
    }
    """

private func shown(_ vgl: String, view: String = "v") throws -> VGraph {
    let parsed = try VGraphParser(logger: TestLogger()).parse(source: vgl)
    return try TransformStep.pipeline(Notations.extensionSteps)(try parsed.displaying(view: view))
}

private func isDerived(_ graph: VGraph, _ edge: Edge) -> Bool {
    (try? graph.edgeType(for: edge))?.isDerived == true
}

private func ends(_ graph: VGraph) -> [String] {
    graph.edges.map { "\($0.from.id)>\($0.to.id)" }.sorted()
}

private func marked(_ graph: VGraph) -> [[String]] {
    graph.loopsToMark.map { loop in loop.edges.map { "\($0.from.id)>\($0.to.id)" } }
}

@Suite("Derived edges: judging is unchanged")
struct DerivedEdgeJudgingTests {
    private let app = VGraphTestApp()

    @Test("Given a view that hides a node, when the quality report is made, then it equals the report without the view")
    func qualityIgnoresDerivedEdges() throws {
        let source = """
            vgraph test: ConceptMap "Test?" {
                node a: Concept "A Very Long Concept Name"
                node b: Concept "Cat"
                node r1: Relation "is a"
                edge a -> r1
                edge r1 -> b
            }
            vview v {
                exclude node r1;
            }
            """
        let with = try app.renderGraph(source, view: "v").qualityReport.formatted()
        let without = try app.renderGraph(source, view: nil).qualityReport.formatted()
        #expect(with != nil)
        #expect(with == without)
    }

    @Test(
        """
        Given a loop with one stretch real and visible and the other hidden, \
        when the view hides the other stretch, \
        then the real edges keep the loop marker
        """
    )
    func realStretchKeepsMarker() throws {
        let graph = try shown(
            """
            vgraph m: CLD "M" {
              node A: Stock "A";
              node B: Stock "B";
              node h: Stock "h";
              edge A -> B: same;
              edge B -> h: same;
              edge h -> A: same;
            }
            vview v {
              exclude node h;
            }
            """)
        #expect(marked(graph).contains { $0.contains("A>B") })
    }

    @Test("Given a loop that lives wholly on hidden nodes and derived edges, when the view hides it, then no marker is shown")
    func derivedOnlyLoopHasNoMarker() throws {
        let graph = try shown(
            """
            vgraph m: CLD "M" {
              node population: Stock "Population";
              node deaths: Stock "Deaths";
              edge population -> deaths: same;
              edge deaths -> population: opposite;
            }
            vview v {
              exclude node deaths;
            }
            """)
        #expect(marked(graph).isEmpty)
    }

    @Test("Given a derived A → B and a real B → A, when loops are searched on the display graph, then none is found")
    func findLoopsIgnoresDerivedEdges() throws {
        let graph = try shown(
            """
            vgraph m: CLD "M" {
              node A: Stock "A";
              node h: Stock "h";
              node B: Stock "B";
              edge A -> h: same;
              edge h -> B: same;
              edge B -> A: same;
            }
            vview v {
              exclude node h;
            }
            """)
        #expect(graph.edges.contains { isDerived(graph, $0) })
        #expect(graph.findLoops().loops.isEmpty)
    }
}

@Suite("Derived edges: folding")
struct DerivedEdgeFoldingTests {
    private func folded(_ extra: String, edges: String, hiding: String) throws -> VGraph {
        try shown(
            """
            vgraph m: CLD "M" {
              node A: Stock "A";
              node C: Stock "C";
              node h: Stock "h";
              node h2: Stock "h2";
              folded group g "G" {
                node x1: Stock "X1";
                node x2: Stock "X2";
              }
              \(extra)
              \(edges)
            }
            vview v {
              exclude node \(hiding);
            }
            """)
    }

    @Test("Given A in folded F and A → h → C, when the view hides h and folds F, then one derived F → C is shown")
    func foldedEndRedirected() throws {
        let graph = try folded("", edges: "edge x1 -> h: same;\nedge h -> C: same;", hiding: "h")
        let derived = graph.edges.filter { isDerived(graph, $0) }
        #expect(derived.map { "\($0.from.id)>\($0.to.id)" } == ["g>C"])
    }

    @Test("Given several derived edges landing on one folded box pair, when folded, then they merge into one edge with no count")
    func mergeWithoutCount() throws {
        let graph = try folded(
            "", edges: "edge x1 -> h: same;\nedge h -> C: same;\nedge x2 -> h2: same;\nedge h2 -> C: same;",
            hiding: "h, h2")
        let derived = graph.edges.filter { isDerived(graph, $0) }
        let edge = try #require(derived.first)
        #expect(derived.count == 1)
        #expect(try graph.get(edge: edge.id, attribute: Attributes.Edge.label) == "")
    }

    @Test("Given a derived and a real edge between the same boxes, when folded, then both are shown as two lines")
    func derivedAndRealStayTwo() throws {
        let graph = try folded("", edges: "edge x1 -> C: same;\nedge x2 -> h: same;\nedge h -> C: same;", hiding: "h")
        #expect(ends(graph) == ["g>C", "g>C"])
        #expect(graph.edges.filter { isDerived(graph, $0) }.count == 1)
    }

    @Test("Given a derived edge ending inside a folded group, when folded, then it ends at the box")
    func endingInsideFoldedGroup() throws {
        let graph = try folded("", edges: "edge A -> h: same;\nedge h -> x1: same;", hiding: "h")
        #expect(graph.edges.filter { isDerived(graph, $0) }.map { "\($0.from.id)>\($0.to.id)" } == ["A>g"])
    }
}

@Suite("Derived edges: drawing and the session")
struct DerivedEdgeDrawingTests {
    private let app = VGraphTestApp()

    @Test(
        """
        Given the ticket's shop example, \
        when overview is rendered, \
        then one dotted demand → price edge is drawn, stamped edge-derived-demand-price
        """
    )
    func overviewDraws() throws {
        let svg = try app.renderGraph(shop, view: "overview").svg
        #expect(svg.contains("id=\"edge-derived-demand-price\""))
        #expect(svg.components(separatedBy: "id=\"edge-derived-").count == 2)
    }

    @Test("Given the same example, when plain is rendered, then no edge between demand and price is drawn")
    func plainDrawsNone() throws {
        let svg = try app.renderGraph(shop, view: "plain").svg
        #expect(!svg.contains("edge-derived-"))
    }

    @Test("Given a large graph with many hidden nodes, when the view is rendered, then it finishes within the time budget")
    func largeGraphWithinBudget() throws {
        let count = 150
        let nodes = (0..<count).map { "node s\($0): Stock \"S\($0)\"; node h\($0): Stock \"H\($0)\"; node t\($0): Stock \"T\($0)\";" }
        let edges = (0..<count).map { "edge s\($0) -> h\($0): same; edge h\($0) -> t\($0): same;" }
        let source =
            "vgraph big: CLD \"Big\" {\n\(nodes.joined(separator: "\n"))\n\(edges.joined(separator: "\n"))\n}\n"
            + "vview v {\n exclude node \((0..<count).map { "h\($0)" }.joined(separator: ", "));\n}\n"
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            let svg = try app.renderGraph(source, view: "v").svg
            #expect(svg.contains("edge-derived-s0-t0"))
        }
        #expect(elapsed < .seconds(30))
    }

    @Test("Given an active view that hides a middle node, when the session shows the graph, then the derived edge is in it")
    func sessionShowsDerivedEdges() throws {
        let session = try app.makeSession(vgl: shop)
        try session.selectView("overview")
        #expect(try session.render().svg.contains("edge-derived-demand-price"))
    }
}

@Suite("Derived edges: the editor example")
struct DerivedEdgeExampleTests {
    private let app = VGraphTestApp()
    private var example: ExampleGraph? { exampleGraphs.first { $0.name.hasPrefix("CLD — Hiding") } }

    @Test("Given the new example, when parsed, then it has no errors")
    func parses() throws {
        let example = try #require(example)
        #expect(!(try app.parseGraph(example.vgl)).nodes.isEmpty)
    }

    @Test("Given the new example, when its views are listed, then it has an overview with derived edges and a plain one with derivedEdges: false")
    func listsViews() throws {
        let example = try #require(example)
        #expect(try app.parseGraph(example.vgl).views.map { $0.name } == ["overview", "plain"])
    }

    @Test("Given the new example, when each view is rendered, then the overview draws a derived edge and the plain view does not")
    func rendersBoth() throws {
        let example = try #require(example)
        #expect(try app.renderGraph(example.vgl, view: "overview").svg.contains("edge-derived-"))
        #expect(!(try app.renderGraph(example.vgl, view: "plain").svg.contains("edge-derived-")))
    }
}
