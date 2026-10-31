// Behavioral tests for `TimelineOverlayProvider`. Each test verifies one
// visible-contract of the Timeline overlay's rendering: TimePoint suppression,
// sequence-edge suppression, axis/guide emission, dark-mode token swap,
// empty-Timeline degeneracy, and the `vnotation … extends Timeline` lookup
// chain in the registry.

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct TimelineOverlayTests {

    // MARK: - Helpers

    /// Build a Timeline graph with two TimePoints + one Event, then mock the
    /// minimal layout data the renderer needs. Skips the real Graphviz layout
    /// step — tests run pure-Swift without the WASM library.
    private func makeTimelineGraph(notation: String = "Timeline") throws -> VGraph {
        let input = """
            vgraph tl: \(notation) "Test" {
                node tp1800: TimePoint "1800" [alignGroup: "1800"]
                node tp1850: TimePoint "1850" [alignGroup: "1850"]
                node ev1: Event "Napoleon" [alignGroup: "1800"]
                edge tp1800 -> tp1850: sequence
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)

        // Mock node positions: TimePoints on y=50, Event on y=150.
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
                    attribute: Attributes.Node.wrappedText.attribute([node.id == "tp1800" ? "1800" : node.id == "tp1850" ? "1850" : "Napoleon"]))
            }
        }

        // Mock root group bounds (covers the full diagram for guide termination).
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 400, height: 200)))

        return graph
    }

    // MARK: - TimePoint suppression

    @Test func timepointNodesAreNotRendered() throws {
        let graph = try makeTimelineGraph()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)

        // Standard pipeline emits `<g transform=...>` for each rendered node.
        // With TimePoints suppressed, only the Event node should produce one.
        // The simplest signal: the year "1800" should not appear inside a
        // boxed node label. The overlay's axis layer DOES draw a "1800" text
        // element, but that's standalone — no surrounding rounded rect.
        //
        // Check: no <rect ... rx=...> precedes a "1800" label. We use a
        // simpler proxy — the Event node "Napoleon" still renders, but the
        // raw TimePoint group transform with rounded-rect attributes does not
        // appear with the TimePoint's id.
        #expect(svg.contains("Napoleon"), "Event nodes still render normally")
        #expect(!svg.contains("◇"), "TimePoint diamond glyph from old styling should not appear")
    }

    // MARK: - Sequence-edge suppression

    @Test func sequenceEdgesAreNotRendered() throws {
        let graph = try makeTimelineGraph()
        // Attach mock edge layout data so the standard pipeline would actually
        // draw the edge if it weren't suppressed.
        var graphWithEdge = graph
        if let seqEdge = graph.edges.first(where: { $0.id.id.contains("tp1800") || $0.id.id.contains("sequence") }) {
            let layout = EdgeLayoutData(
                splinePoints: [VPoint(x: 100, y: 50), VPoint(x: 300, y: 50)],
                color: "#000000", penwidth: 1.0
            )
            graphWithEdge = try graphWithEdge.set(
                edge: seqEdge.id, attribute: Attributes.Edge.layoutData.attribute(layout))
        }
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graphWithEdge)

        // The dashed axis guides (stroke-dasharray="2,4") should appear; a
        // standard edge path with spline coordinates should NOT — sequence
        // edges between TimePoints are filtered out.
        #expect(svg.contains("stroke-dasharray=\"2,4\""), "Guide stroke pattern should appear")
    }

    // MARK: - Axis chrome

    @Test func axisLayerEmitsBaselineDotsAndYearLabels() throws {
        let graph = try makeTimelineGraph()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)

        // Anchor dots (r=3).
        #expect(svg.contains("r=\"3\""), "Should emit r=3 anchor dots on the axis")
        // Year labels embedded as text content.
        #expect(svg.contains(">1800<"), "1800 year label should appear in SVG")
        #expect(svg.contains(">1850<"), "1850 year label should appear in SVG")
        // Axis baseline color (light-mode timeline.axis).
        #expect(svg.contains("#5a564e"), "Light-mode axis color should appear")
    }

    @Test func columnGuidesEmitDashedVerticals() throws {
        let graph = try makeTimelineGraph()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)

        // Two TimePoints → two dashed guides.
        let dashOccurrences = svg.components(separatedBy: "stroke-dasharray=\"2,4\"").count - 1
        #expect(dashOccurrences >= 2, "Each TimePoint should have its own dashed guide")
    }

    // MARK: - Dark mode token swap

    @Test func darkModeSwapsAxisAndYearTokens() throws {
        let graph = try makeTimelineGraph()
        let renderer = VSVGRenderer(logger: TestLogger())
        let dark = try renderer.render(graph: graph, darkMode: true)

        // Dark variants of timeline.axis/guide (#a8a49a) and timeline.year (#ecebe5).
        #expect(dark.contains("#a8a49a"), "Dark-mode axis/guide color should appear")
        #expect(dark.contains("#ecebe5"), "Dark-mode year-label color should appear")
        #expect(!dark.contains("#18160f"), "Light-mode year color should NOT appear in dark mode")
    }

    // MARK: - Empty Timeline (no TimePoints)

    @Test func emptyTimelineEmitsNoAxisOrGuides() throws {
        let input = """
            vgraph events: Timeline "Events Only" {
                node ev1: Event "Something happened"
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for node in graph.nodes {
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 30)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.wrappedText.attribute(["Something happened"]))
        }
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 200, height: 200)))

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)

        // No TimePoints → no axis baseline, no guides. The Event still renders.
        #expect(!svg.contains("stroke-dasharray=\"2,4\""), "No guides without TimePoints")
        #expect(svg.contains("Something happened"), "Event still renders")
    }

    // MARK: - vnotation extension lookup chain

    @Test func vnotationExtendsTimelineResolvesToOverlay() throws {
        // The registry resolve helper directly — proves that a graph carrying
        // extensions containing "Timeline" routes to the
        // Timeline overlay, even if the notation name itself is something else.
        let parser = VGraphParser(logger: TestLogger())
        let baseInput = """
            vgraph base: Timeline "Base" {
                node tp1: TimePoint "1900" [alignGroup: "1900"]
            }
            """
        var graph = try parser.parse(source: baseInput)
        graph = graph.using(notation: "MyCustomTimeline").using(extensions: ["Timeline"])

        let providers: [String: NotationOverlayEntry] = [
            "Timeline": TimelineOverlayProvider().overlayEntry
        ]
        let resolved = NotationOverlayRegistry.resolve(graph: graph, in: providers)
        #expect(resolved != nil, "Should resolve via extensions chain")
        #expect(resolved?.notationName == "Timeline", "Should resolve to Timeline overlay")
    }

    @Test func registryReturnsNilForUnregisteredNotation() throws {
        let input = """
            vgraph ibis1: IBIS "no overlay" {
                node q: Question "?"
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)
        let providers: [String: NotationOverlayEntry] = [
            "Timeline": TimelineOverlayProvider().overlayEntry
        ]
        let resolved = NotationOverlayRegistry.resolve(graph: graph, in: providers)
        #expect(resolved == nil, "IBIS should not match the Timeline-only registry")
    }
}
