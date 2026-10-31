// Whole-document snapshots: every per-piece test could pass while the composition
// ordered them wrongly or dropped a pass. Both overlay notations are here because
// the slot passes, bounds contributions and node/edge filters have no other test.

import TestSupport
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct VSVGGraphTests {

    typealias CLD = Notations.CausalLoopDiagram

    func expectFullRender(
        _ graph: VGraph, darkMode: Bool = false,
        name: String = #function, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let rendered = try VSVGGraph.render(
            graph: graph, darkMode: darkMode, logger: TestLogger()
        ).render()
        SVGSnapshot.verify(
            rendered, named: SVGSnapshot.caseName("Graph", name, darkMode ? "dark" : "light"),
            sourceLocation: sourceLocation)
    }

    // MARK: - Fixtures

    func laidOut(_ input: String, groupBounds: VRect? = nil) throws -> VGraph {
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for (index, node) in graph.nodes.enumerated() {
            graph = try graph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: Double(index) * 120 + 60, y: 80)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 90, height: 44)))
        }
        for group in graph.groups {
            graph = try graph.set(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(
                    groupBounds ?? VRect(x: 20, y: 20, width: 300, height: 160)))
        }
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 500, height: 300)))
        return graph
    }

    // MARK: - Plain graphs

    @Test func simpleGraph() throws {
        let graph = try laidOut(
            """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                node pro1: Pro "Good outcome";
                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """)
        try expectFullRender(graph)
    }

    @Test func simpleGraphInDarkMode() throws {
        let graph = try laidOut(
            """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                node a1: Answer "A";
                edge q1 -> a1;
            }
            """)
        try expectFullRender(graph, darkMode: true)
    }

    @Test func graphWithGroups() throws {
        let graph = try laidOut(
            """
            vgraph myGraph: IBIS "Grouped" {
                node q1: Question "Main question";
                group g1 "My Group" {
                    node a1: Answer "Answer in group";
                    node pro1: Pro "Pro in group";
                };
                edge q1 -> a1;
            }
            """)
        try expectFullRender(graph)
        try expectFullRender(graph, darkMode: true)
    }

    @Test func nestedGroups() throws {
        let graph = try laidOut(
            """
            vgraph nested: IBIS "Nested" {
                node q1: Question "Root";
                group outer "Outer" {
                    node a1: Answer "A1";
                    group inner "Inner" {
                        node a2: Answer "A2";
                    };
                };
                edge q1 -> a1;
            }
            """)
        try expectFullRender(graph)
    }

    // The embedded-VGL case lives in `VSVGRendererPortTests`: the tree does not
    // carry the envelope, so the port is the only place it exists.

    @Test func watermarkDisabled() throws {
        var graph = try laidOut(
            """
            vgraph myGraph: IBIS "No Watermark" {
                node q1: Question "Q";
            }
            """)
        graph = try graph.set(graphAttribute: Attributes.Group.watermark.attribute(false))
        try expectFullRender(graph)
    }

    /// C4 draws no icons, so its `<defs>` holds only the watermark.
    @Test func graphWithIcons() throws {
        let graph = try laidOut(
            """
            vgraph c4: C4 "Banking" {
                node sys: System "Internet Banking";
                node person: Person "Customer";
                edge person -> sys;
            }
            """)
        try expectFullRender(graph)
    }

    /// All three badge call sites at once. `<a>` was missing from the IR's closed
    /// tag set for a while and nothing failed, because no fixture above carries a
    /// link — so add a fixture here for any render feature added from now on.
    @Test func urlBadgesOnNodeGroupAndEdge() throws {
        let graph = try laidOut(
            """
            vgraph linked: IBIS "Linked" {
                node q1: Question "Q" [url: "https://vithanco.com/q?a=1&b=2"];
                group g1 "Group" {
                    url: "https://vithanco.com/group";
                    node a1: Answer "A";
                };
                edge q1 -> a1 [url: "https://vithanco.com/edge"];
            }
            """)
        try expectFullRender(graph)
        try expectFullRender(graph, darkMode: true)
    }

    /// Sanitised again at draw time because `[url: "javascript:alert(1)"]` can be
    /// typed straight into the VGL, never passing the commands that check it.
    @Test func unsafeURLDrawsNoBadge() throws {
        let graph = try laidOut(
            """
            vgraph unsafe: IBIS "Unsafe" {
                node q1: Question "Q" [url: "javascript:alert(1)"];
            }
            """)
        try expectFullRender(graph)
        let ported = try VSVGGraph.render(graph: graph, logger: TestLogger()).render()
        #expect(!ported.contains("javascript:"))
        // Not the class — `hoverStyles()` names it in every document's `<style>`.
        #expect(!ported.contains("<a "))
    }

    /// Pinned by name as well as by snapshot: "tidying" this would move every
    /// snapshot at once, and a diff that large says nothing about the cause.
    @Test func svgDimensionsKeepRawDoubleFormattingUnlikeInnerCoordinates() throws {
        let graph = try laidOut(
            """
            vgraph myGraph: IBIS "Dims" {
                node q1: Question "Q";
            }
            """)
        let ported = try VSVGGraph.render(graph: graph, logger: TestLogger()).render()
        #expect(ported.contains("width=\"600.0\""))
        #expect(ported.contains("viewBox=\"-50.0 -50.0 600.0 400.0\""))
        // Same document, inner geometry: integral values with no ".0".
        #expect(ported.contains("width=\"90\""))
    }

    @Test func emptyGraph() throws {
        let graph = try laidOut(
            """
            vgraph empty: IBIS "Empty" {
            }
            """)
        try expectFullRender(graph)
    }

    // MARK: - Overlay notations (slot passes, filters, bounds, hover rules)

    func makeCLDWithCycle() throws -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        graph = graph.using(notation: "CLD")

        let a = Node(string: "a")
        let b = Node(string: "b")
        graph = try graph.add(node: a, type: CLD.NodeTypes.stock)
        graph = try graph.add(node: b, type: CLD.NodeTypes.stock)
        graph = try graph.set(node: a, attribute: Attributes.Node.label.attribute("A"))
        graph = try graph.set(node: b, attribute: Attributes.Node.label.attribute("B"))
        graph = try graph.set(node: a, attribute: Attributes.Node.wrappedText.attribute(["A"]))
        graph = try graph.set(node: b, attribute: Attributes.Node.wrappedText.attribute(["B"]))

        let e1 = Edge(string: "e1", from: "a", to: "b")
        let e2 = Edge(string: "e2", from: "b", to: "a")
        graph = try graph.add(edge: e1, edgeType: CLD.EdgeTypes.same)
        graph = try graph.add(edge: e2, edgeType: CLD.EdgeTypes.same)

        graph = try graph.set(node: a, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
        graph = try graph.set(node: b, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 300, y: 100)))
        graph = try graph.set(node: a, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))
        graph = try graph.set(node: b, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))

        graph = try graph.set(
            edge: e1.id,
            attribute: Attributes.Edge.layoutData.attribute(
                EdgeLayoutData(
                    splinePoints: [VPoint(x: 130, y: 90), VPoint(x: 270, y: 90)], color: "#000000", penwidth: 1.0)))
        graph = try graph.set(
            edge: e2.id,
            attribute: Attributes.Edge.layoutData.attribute(
                EdgeLayoutData(
                    splinePoints: [VPoint(x: 270, y: 110), VPoint(x: 130, y: 110)], color: "#000000", penwidth: 1.0)))

        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 400, height: 200)))
        return graph
    }

    /// CLD drives a slot pass, bounds contributions and extra hover rules.
    @Test func cldOverlayGraph() throws {
        let graph = try makeCLDWithCycle()
        try expectFullRender(graph)
        try expectFullRender(graph, darkMode: true)
    }

    /// Vacuity guard: the test above would pass if the overlay stopped resolving.
    @Test func cldOverlayActuallyContributesItsSlotAndBounds() throws {
        let ported = try VSVGGraph.render(graph: try makeCLDWithCycle(), logger: TestLogger()).render()
        #expect(ported.contains("loop-indicator"))
    }

    func makeTimelineGraph() throws -> VGraph {
        let input = """
            vgraph tl: Timeline "Test" {
                node tp1800: TimePoint "1800" [alignGroup: "1800"]
                node tp1850: TimePoint "1850" [alignGroup: "1850"]
                node ev1: Event "Napoleon" [alignGroup: "1800"]
                edge tp1800 -> tp1850: sequence
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        let positions: [String: VPoint] = [
            "tp1800": VPoint(x: 100, y: 50),
            "tp1850": VPoint(x: 300, y: 50),
            "ev1": VPoint(x: 100, y: 150),
        ]
        for node in graph.nodes {
            if let pos = positions[node.id] {
                graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
                graph = try graph.set(
                    node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 30)))
                graph = try graph.set(
                    node: node,
                    attribute: Attributes.Node.wrappedText.attribute(
                        [node.id == "tp1800" ? "1800" : node.id == "tp1850" ? "1850" : "Napoleon"]))
            }
        }
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 400, height: 200)))
        return graph
    }

    /// Timeline is the only notation exercising the node and edge keepSet filters.
    @Test func timelineOverlayGraph() throws {
        let graph = try makeTimelineGraph()
        try expectFullRender(graph)
        try expectFullRender(graph, darkMode: true)
    }

    /// Vacuity guard. Matches on `id="node-…"`, not the bare id: a filtered-out
    /// node still appears as `#node-…` in the hover CSS, because
    /// `renderNeighborHoverStyles` knows nothing about the overlay's filters.
    @Test func timelineOverlayActuallyFiltersNodesAndEdges() throws {
        let graph = try makeTimelineGraph()
        let ported = try VSVGGraph.render(graph: graph, logger: TestLogger()).render()
        #expect(!ported.contains("id=\"\(SVGElementId.node("tp1800"))\""), "TimePoint nodes should be filtered out")
        #expect(ported.contains("id=\"\(SVGElementId.node("ev1"))\""), "Event nodes should survive the filter")
        #expect(ported.contains("#\(SVGElementId.node("tp1800"))"), "…but its hover CSS is still emitted")
    }
}
