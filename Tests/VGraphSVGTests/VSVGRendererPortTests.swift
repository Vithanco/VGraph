// The renderer port is the seam every consumer goes through — CLI, MCP, the wasm
// editor's preview and Save SVG, the Obsidian and VS Code plugins — so it is the
// one place the IR had to be wired in, and the one place to pin that it is.

import Testing

@testable import App
@testable import TestSupport
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct VSVGRendererPortTests {

    func laidOut(_ input: String) throws -> VGraph {
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for (index, node) in graph.nodes.enumerated() {
            graph = try graph.setting(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: Double(index) * 120 + 60, y: 80)))
            graph = try graph.setting(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 90, height: 44)))
        }
        for group in graph.groups {
            graph = try graph.setting(
                group: group,
                attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 20, y: 20, width: 300, height: 160)))
        }
        graph = try graph.setting(
            group: Group.root,
            attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 500, height: 300)))
        return graph
    }

    var fixture: String {
        """
        vgraph ported: IBIS "Ported" {
            node q1: Question "Q" [url: "https://vithanco.com/q"];
            group g1 "Group" {
                node a1: Answer "A";
            };
            edge q1 -> a1;
        }
        """
    }

    /// The two halves of the port have to agree: whatever `render` carried into
    /// the artefact is what `sourceVGL` gets back out. *How* it is carried is
    /// the adapter's business — `<metadata>` here, a text chunk in a PNG
    /// renderer, nothing at all in one that declines — so this is the only
    /// promise the application makes about it.
    @Test func whatTheRendererCarriesInItAlsoGetsBackOut() throws {
        let graph = try laidOut(fixture)
        let renderer: any ForRenderAGraph = VSVGRenderer(logger: TestLogger())

        let rendered = try renderer.render(
            graph: graph, sourceVGL: fixture, darkMode: false, interactive: false)

        #expect(renderer.sourceVGL(from: rendered) == fixture)
    }

    /// An artefact the renderer did not write carries nothing, and says so
    /// rather than guessing.
    @Test func aForeignArtifactCarriesNoSource() throws {
        let renderer: any ForRenderAGraph = VSVGRenderer(logger: TestLogger())

        #expect(renderer.sourceVGL(from: "<svg><rect/></svg>") == nil)
    }

    /// Through the port rather than through `VSVGGraph`, so it covers the embedded
    /// VGL that Save SVG and document re-opening depend on.
    @Test func thePortRendersTheWholeDocumentIncludingItsEmbeddedVGL() throws {
        let graph = try laidOut(fixture)
        let renderer: any ForRenderAGraph = VSVGRenderer(logger: TestLogger())

        for darkMode in [false, true] {
            let rendered = try renderer.render(graph: graph, sourceVGL: fixture, darkMode: darkMode, interactive: false)
            SVGSnapshot.verify(
                rendered, named: SVGSnapshot.caseName("Port", #function, darkMode ? "dark" : "light"))
            #expect(rendered.contains("<![CDATA[\(fixture)]]>"))
        }
    }

    /// Every host builds its ports here, so this is what makes "the IR is in
    /// production" true rather than merely available.
    @Test func nativePortsRenderThroughTheIR() throws {
        let graph = try laidOut(fixture)
        let ports = NativePorts(logger: TestLogger())

        // Compile-time, not a runtime `is`: `NativePorts` declares `renderer`
        // concretely, so this stops building the moment it stops being the adapter.
        let _: VSVGRenderer<TestLogger> = ports.renderer

        #expect(
            try ports.renderer.render(graph: graph, sourceVGL: nil, darkMode: false)
                == VSVGGraph.render(graph: graph, logger: TestLogger()).render())
    }

    func ids(in drawing: VSVGNode) -> [String] {
        switch drawing {
        case .element(_, let attributes, let children):
            return attributes.filter { $0.name == "id" }.map { $0.value } + children.flatMap { ids(in: $0) }
        case .fragment(let children):
            return children.flatMap { ids(in: $0) }
        case .text, .raw, .empty:
            return []
        }
    }

    /// The mounted preview and Save SVG must be one drawing, not two renders
    /// that happen to agree (ADR-0015 F1).
    @Test func renderIsTheDrawingSerialized() throws {
        let graph = try laidOut(fixture)
        let renderer = VSVGRenderer(logger: TestLogger())

        let drawing = try renderer.draw(graph: graph, darkMode: false, interactive: true)

        guard case .element(.svg, _, _) = drawing else {
            Issue.record("the drawing's root is not an <svg>")
            return
        }
        #expect(ids(in: drawing).contains("node-q1"))
        #expect(ids(in: drawing).contains("group-g1"))
        #expect(
            renderer.serialize(drawing, sourceVGL: fixture)
                == (try renderer.render(graph: graph, sourceVGL: fixture, darkMode: false, interactive: true)))
    }

    /// The envelope is the string's alone: a mounted tree cannot hold CDATA.
    @Test func theDrawingCarriesNoSourceEnvelope() throws {
        let renderer = VSVGRenderer(logger: TestLogger())
        let drawing = try renderer.draw(graph: try laidOut(fixture), darkMode: false, interactive: false)

        #expect(!drawing.render().contains("CDATA"))
        #expect(renderer.serialize(drawing, sourceVGL: fixture).contains("<![CDATA[\(fixture)]]>"))
    }

    /// Through the application, because that is where the editor gets it.
    @Test func aRenderResultCarriesTheDrawingBehindItsSVG() throws {
        let result = try VGraphTestApp().renderGraph(fixture)

        #expect(ids(in: result.drawing).contains("node-a1"))
        #expect(result.svg == VSVGRenderer(logger: TestLogger()).serialize(result.drawing, sourceVGL: fixture))
    }

    /// A struct that stops being stateless stops compiling here.
    @Test func theAdapterIsSendable() throws {
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(VSVGRenderer<TestLogger>.self)
    }

    /// A theme is an argument, not a mode the renderer is left in.
    @Test func interleavedThemesOnOneInstanceDoNotContaminateEachOther() throws {
        let graph = try laidOut(fixture)
        let shared = VSVGRenderer(logger: TestLogger())

        let dark = try shared.render(graph: graph, sourceVGL: nil, darkMode: true)
        _ = try shared.render(graph: graph, sourceVGL: nil, darkMode: false)
        let darkAgain = try shared.render(graph: graph, sourceVGL: nil, darkMode: true)

        #expect(dark == darkAgain)
        #expect(dark == (try VSVGRenderer(logger: TestLogger()).render(graph: graph, sourceVGL: nil, darkMode: true)))
    }
}
