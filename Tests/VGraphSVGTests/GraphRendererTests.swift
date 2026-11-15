// The full rendering pipeline (without WASM layout), driven through the port the
// hosts use. `VSVGGraphTests` snapshots these same documents; what these add is
// the named structure a reviewer needs in order to read a snapshot diff.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct TestLogger: ForLogMessages {
    func log(_ message: String) {
        // Silent for tests
    }
    func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}

struct SVGRendererTests {

    @Test func testRenderSimpleGraph() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // The editor's hit-testing, inline editor and hover CSS are all written
        // against these ids and classes.
        for node in graph.nodes {
            #expect(svg.contains("<g id=\"\(SVGElementId.node(node.id))\" class=\"\(SVGElementId.nodeClass)\">"))
        }
        for edge in graph.edges {
            #expect(svg.contains("<g id=\"\(SVGElementId.edge(edge.id.id))\" class=\"\(SVGElementId.edgeClass)\">"))
        }
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.hasSuffix("</svg>"))
        // Counted too: the ids above prove each element is present, not that it is
        // present once.
        #expect(svg.components(separatedBy: "class=\"\(SVGElementId.nodeClass)\"").count - 1 == graph.nodes.count)
        #expect(svg.components(separatedBy: "class=\"\(SVGElementId.edgeClass)\"").count - 1 == graph.edges.count)

        // No labels, and that is the fixture's doing: it skips the text-wrapping
        // step, and the renderer draws only what `wrappedText` hands it.
        #expect(!svg.contains("What should"))
    }

    @Test func testRenderGraphWithGroup() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Main question";

                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                    node pro1: Pro "Pro in group";
                };

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let group = graph.groups[0]
        layoutedGraph = try layoutedGraph.set(
            group: group,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 80, y: 10, width: 200, height: 100))
        )
        layoutedGraph = try layoutedGraph.set(
            group: group,
            attribute: Attributes.Group.labelLayoutedPos.attribute(VPoint(x: 180, y: 20))
        )

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("<g id=\"\(SVGElementId.group(group.id.id))\" class=\"\(SVGElementId.groupClass) depth-0\">"))
        // Classed separately because the group's box covers its members: hit-testing
        // the whole `.vgraph-group` would make any click inside it a rename.
        #expect(svg.contains("class=\"\(SVGElementId.groupLabelClass)\""))
        #expect(svg.contains("MY GROUP"), "group titles are upper-cased on the way out")
        #expect(!svg.contains(">My Group<"))

        // The members are nested inside the group element, not siblings of it.
        let groupOpen = svg.range(of: "<g id=\"\(SVGElementId.group(group.id.id))\"")
        let memberOpen = svg.range(of: "<g id=\"\(SVGElementId.node("a1"))\"")
        #expect(groupOpen != nil)
        #expect(memberOpen != nil)
        if let groupOpen, let memberOpen { #expect(groupOpen.lowerBound < memberOpen.lowerBound) }
    }

    // MARK: - Interactive Hover Tests

    /// Nodes and edges are wrapped in identifiable, hover-able groups, and the
    /// static self-highlight styles are baked into the SVG (Style Guide §12).
    @Test func testHoverWrappersAndStaticStyles() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("id=\"node-q1\" class=\"vgraph-node\""))
        #expect(svg.contains("id=\"node-a1\" class=\"vgraph-node\""))
        #expect(svg.contains("id=\"node-pro1\" class=\"vgraph-node\""))
        #expect(svg.contains("class=\"vgraph-edge\""))
        #expect(svg.contains(".vgraph-node:hover"))
        #expect(svg.contains(".vgraph-edge:hover"))
        #expect(svg.contains(".vgraph-group:hover"))
        #expect(svg.contains("svg:has(.vgraph-node:hover, .vgraph-edge:hover, .loop-indicator:hover) .vgraph-node"))
        #expect(svg.contains("opacity: 0.15"))
        #expect(svg.contains("opacity: 1 !important"))
    }

    /// Hovering a node highlights its neighbour nodes via generated `:has()`
    /// rules, and hovering an edge highlights its endpoints.
    @Test func testNeighborHoverRulesGenerated() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";

                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // a1 sits between q1 and pro1: hovering a1 must reach both neighbours.
        #expect(svg.contains("svg:has(#node-a1:hover) #node-q1"))
        #expect(svg.contains("svg:has(#node-a1:hover) #node-pro1"))
        // q1 is an endpoint of one edge → reaches a1 only (not pro1).
        #expect(svg.contains("svg:has(#node-q1:hover) #node-a1"))
        #expect(!svg.contains("svg:has(#node-q1:hover) #node-pro1"))
        // Edge hover highlights endpoint nodes (endpoint scope present).
        #expect(svg.contains(":hover) #node-q1"))
        // Neighbour re-brighten carries opacity:1 to outrank the spotlight dim,
        // and incident edges recolour to the accent.
        #expect(svg.contains("opacity:1;filter:drop-shadow"))
        #expect(svg.contains("stroke:#3b82f6;stroke-width:3;"))
    }

    // Each notation marks its own junctor; PRT's OR uses a different id from CRT's AndJunctor.
    @Test func testOrJunctorNeighbourhoodJumpsThrough() throws {
        let input = """
            vgraph prt: PRT "OR junctor test" {
                node o: Objective "Goal"
                node j: OR
                node a: IntermediateObjective "Path A"
                node b: IntermediateObjective "Path B"
                edge a -> j
                edge b -> j
                edge j -> o
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("svg:has(#node-a:hover) #node-j"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-o"))
        #expect(svg.contains("svg:has(#node-a:hover) #node-b"))
    }

    /// In a CLD, hovering the loop *indicator* highlights the whole loop. Loop
    /// nodes/edges keep the generic neighbour rules — a node does NOT pull in the
    /// far side of its loop.
    @Test func testCLDLoopIndicatorHighlightsLoop() throws {
        // a→b→c→d→a reinforcing loop. `a`'s direct neighbours are b and d; `c` is
        // on the far side (reachable only through the indicator, not by hovering a).
        let input = """
            vgraph cld: CLD "Loop test" {
                node a: Stock "A"
                node b: Stock "B"
                node c: Stock "C"
                node d: Stock "D"
                edge a -> b: same
                edge b -> c: same
                edge c -> d: same
                edge d -> a: same
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        // Square positions so the loop encloses a non-zero area (loopDirection
        // falls back to node positions here — collinear points would be .error).
        let square: [String: VPoint] = [
            "a": VPoint(x: 0, y: 0), "b": VPoint(x: 100, y: 0),
            "c": VPoint(x: 100, y: 100), "d": VPoint(x: 0, y: 100),
        ]
        var layoutedGraph = graph
        for node in graph.nodes {
            let pos = square[node.id] ?? VPoint(x: 0, y: 0)
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            layoutedGraph = try layoutedGraph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        // Node hover stays generic: `a` reaches its direct neighbours (b, d) but
        // NOT the far side `c` — hovering a node no longer lights the whole loop.
        #expect(svg.contains("svg:has(#node-a:hover) #node-b"))
        #expect(!svg.contains("svg:has(#node-a:hover) #node-c"))

        // The loop indicator is a hoverable element (id + transparent hit disc)…
        #expect(svg.contains("<g id=\"loop-"))
        #expect(svg.contains("pointer-events=\"all\""))
        // …and hovering it lights up the whole loop, including the far node `c`.
        let idStart = svg.range(of: "<g id=\"loop-")!.upperBound
        let loopId = "loop-" + svg[idStart...].prefix(while: { $0 != "\"" })
        #expect(svg.contains("svg:has(#\(loopId):hover) #node-c"))
    }

    // MARK: - Watermark Tests

    @Test func testWatermarkIncludedByDefault() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What?";
                node a1: Answer "This";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(svg.contains("id=\"vithanco-watermark\""))
        #expect(svg.contains("href=\"#vithanco-watermark\""))
        #expect(svg.contains("VITHANCO.COM"))
    }

    @Test func testWatermarkExcludedWhenDisabled() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What?";
                node a1: Answer "This";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)

        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            let pos = VPoint(x: Double(index) * 100 + 50, y: 50)
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(pos)
            )
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40))
            )
        }

        layoutedGraph = try layoutedGraph.set(
            graphAttribute: Attributes.Group.watermark.attribute(false)
        )

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: layoutedGraph)

        #expect(!svg.contains("vithanco-watermark"))
        #expect(!svg.contains("VITHANCO.COM"))
    }
}
