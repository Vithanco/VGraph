// Loop markers are the model's loops, projected onto what is drawn (ADR-0027).
// These run the display pipeline's own transforms on parsed VGL, so folding
// really happens before the loops are asked for.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct LoopProjectionTests {

    private func displayed(_ vgl: String) throws -> VGraph {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: vgl)
        return try TransformStep.pipeline(Notations.extensionSteps)(parsed)
    }

    /// Edges by their drawn ends, since VGL mints edge ids.
    private func marked(_ graph: VGraph) -> [(edges: [String], nodes: [String], style: LoopStyle)] {
        graph.loopsToMark.map { loop in
            (loop.edges.map { "\($0.from.id)>\($0.to.id)" }, loop.nodes.map { $0.id }, loop.loopStyle)
        }
    }

    @Test("Without folding, the marked loops are the graph's own")
    func unfoldedIsUnchanged() throws {
        let graph = try displayed(
            """
            vgraph cld: CLD "Demo" {
              node a: Stock "A";
              node b: Stock "B";
              edge a -> b: same;
              edge b -> a: same;
            }
            """)
        let loops = marked(graph)
        #expect(loops.count == 1)
        #expect(loops.first?.edges == ["a>b", "b>a"])
        #expect(loops.first?.style == .reinforcing)
    }

    /// A→x1 and x2→A with no path from x1 to x2: folding draws A→box→A, but the
    /// model has no loop, so nothing is marked.
    @Test("Folding never invents a loop")
    func noPhantomLoop() throws {
        let graph = try displayed(
            """
            vgraph cld: CLD "Demo" {
              node a: Stock "A";
              folded group g "G" {
                node x1: Stock "X1";
                node x2: Stock "X2";
              }
              edge a -> x1: same;
              edge x2 -> a: same;
            }
            """)
        #expect(marked(graph).isEmpty)
    }

    @Test("A loop wholly inside a folded group is not marked")
    func hiddenLoopIsNotMarked() throws {
        let graph = try displayed(
            """
            vgraph cld: CLD "Demo" {
              folded group g "G" {
                node x: Stock "X";
                node y: Stock "Y";
              }
              edge x -> y: same;
              edge y -> x: same;
            }
            """)
        #expect(marked(graph).isEmpty)
    }

    /// Through the box, with the polarity of all three model links: two `same`
    /// and one `opposite` is balancing, although both links still drawn are `same`.
    @Test("A loop through a folded group is marked through the box, with the model's polarity")
    func crossingLoopKeepsModelPolarity() throws {
        let graph = try displayed(
            """
            vgraph cld: CLD "Demo" {
              node a: Stock "A";
              folded group g "G" {
                node x: Stock "X";
                node y: Stock "Y";
              }
              edge a -> x: same;
              edge x -> y: opposite;
              edge y -> a: same;
            }
            """)
        let loops = marked(graph)
        #expect(loops.count == 1)
        #expect(loops.first?.edges == ["a>g", "g>a"])
        #expect(loops.first?.nodes == ["a", "g"])
        #expect(loops.first?.style == .balancing)
    }

    /// A graph that never went through the pipeline is the model itself.
    @Test("Without the pipeline, the graph's own loops are marked")
    func fallsBackToTheGraphItself() throws {
        let graph = try VGraphParser(logger: TestLogger()).parse(
            source: """
                vgraph cld: CLD "Demo" {
                  node a: Stock "A";
                  node b: Stock "B";
                  edge a -> b: opposite;
                  edge b -> a: same;
                }
                """)
        #expect(marked(graph).map { $0.style } == [.balancing])
    }

    // MARK: - Polarity that cannot be read (ADR-0028)

    /// A→B drawn once `same` and once `opposite`: the loop is real, its polarity
    /// is not, and the marker says which link is to blame.
    private let contradictory = """
        vgraph cld: CLD "Demo" {
          node a: Stock "A";
          node b: Stock "B";
          edge a -> b: same;
          edge a -> b: opposite;
          edge b -> a: same;
        }
        """

    @Test("A loop through links of both polarities is one loop of unknown polarity")
    func ambiguousPolarity() throws {
        let loops = try displayed(contradictory).loopsToMark
        #expect(loops.count == 1)
        #expect(loops.first?.loopStyle == .ambiguous)
        #expect(loops.first?.ambiguousLinks == ["“A” → “B”"])
    }

    @Test("Its marker shows a question mark and names the link")
    func ambiguousMarker() throws {
        var graph = try displayed(contradictory)
        for (index, node) in graph.nodes.enumerated() {
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100 + 200 * Double(index), y: 100)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))
        }
        // Edge splines offset apart, as Graphviz draws them, so the loop has an area.
        for edge in graph.edges {
            let forward = edge.from.id == "a"
            let y = forward ? 90.0 : 110.0
            let points = forward ? [VPoint(x: 130, y: y), VPoint(x: 270, y: y)] : [VPoint(x: 270, y: y), VPoint(x: 130, y: y)]
            graph = try graph.set(
                edge: edge.id,
                attribute: Attributes.Edge.layoutData.attribute(
                    EdgeLayoutData(splinePoints: points, color: "#000000", penwidth: 1.0)))
        }
        let svg = try VSVGRenderer(logger: TestLogger()).render(graph: graph)

        #expect(svg.contains(">?<"))
        #expect(svg.contains("<title>Polarity unknown: “A” → “B” is drawn with both polarities</title>"))
    }

    // MARK: - More loops than can be marked (ADR-0028)

    @Test("A diagram with more loops than can be marked says so")
    func truncationIsReported() throws {
        let names = (0..<12).map { "s\($0)" }
        var vgl = "vgraph cld: CLD \"Dense\" {\n"
        for name in names { vgl += "  node \(name): Stock \"\(name)\";\n" }
        for a in names { for b in names where a != b { vgl += "  edge \(a) -> \(b): same;\n" } }
        vgl += "}"
        let graph = try VGraphParser(logger: TestLogger()).parse(source: vgl)

        let warnings = Notations.analyzeQuality(graph: graph).messages.filter { $0.message.contains("more loops") }
        #expect(warnings.count == 1)
        #expect(warnings.first?.severity == .warning)
    }

    @Test("A diagram whose loops all fit says nothing about it")
    func noTruncationNoMessage() throws {
        let graph = try VGraphParser(logger: TestLogger()).parse(source: contradictory)
        #expect(!Notations.analyzeQuality(graph: graph).messages.contains { $0.message.contains("more loops") })
    }

    // MARK: - Which loops are marked: loopMarkers (ADR-0028)

    /// Every pair of stocks linked both ways: five loops, of which four together
    /// cover every link.
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

    @Test("Without a setting, every loop is marked")
    func allByDefault() throws {
        #expect(try displayed(triangle("")).loopsToMark.count == 5)
    }

    @Test("independent marks a set covering every link")
    func independentSubset() throws {
        #expect(try displayed(triangle("loopmarkers: independent;")).loopsToMark.count == 4)
    }

    @Test("none marks nothing, and warns of nothing")
    func noneMarksNothing() throws {
        let source = triangle("loopmarkers: none;")
        #expect(try displayed(source).loopsToMark.isEmpty)
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: source)
        #expect(try parsed.get(attribute: Attributes.Group.loopMarkers) == .none)
    }

    @Test("The setting survives export and reparse")
    func settingRoundTrips() throws {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: triangle("loopmarkers: independent;"))
        let exported = try VGLExporter().export(graph: parsed)

        #expect(exported.contains("loopmarkers: independent"))
        let reparsed = try VGraphParser(logger: TestLogger()).parse(source: exported)
        #expect(try reparsed.get(attribute: Attributes.Group.loopMarkers) == .independent)
    }

    @Test("The default is not written out")
    func defaultIsNotExported() throws {
        let parsed = try VGraphParser(logger: TestLogger()).parse(source: triangle(""))
        #expect(!(try VGLExporter().export(graph: parsed)).contains("loopmarkers"))
    }
}
