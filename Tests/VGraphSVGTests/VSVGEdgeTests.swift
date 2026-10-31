// Edge markup, snapshotted per case: the arrowhead shapes and the B-spline
// guards are the parts most likely to move by accident.

import TestSupport
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct VSVGEdgeTests {

    func makeGraph() throws -> VGraph {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
                node a1: Answer "Option A";
                edge q1 -> a1;
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for (index, node) in graph.nodes.enumerated() {
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: Double(index) * 100 + 50, y: 50)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        return graph
    }

    func edgeId(_ graph: VGraph) -> Edge.Id {
        graph.edges[0].id
    }

    func expectSnapshot(
        _ graph: VGraph, darkMode: Bool = false, keepSet: Set<Edge>? = nil, interactive: Bool = false,
        variant: String? = nil, name: String = #function, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let rendered = VSVGEdge.render(
            graph: graph, darkMode: darkMode, logger: TestLogger(), keepSet: keepSet, interactive: interactive
        ).render()
        SVGSnapshot.verify(
            rendered, named: SVGSnapshot.caseName("Edge", name, variant), sourceLocation: sourceLocation)
    }

    // MARK: - Fallback path (no EdgeLayoutData)

    @Test func straightLineFallback() throws {
        expectSnapshot(try makeGraph())
    }

    @Test func straightLineFallbackDarkMode() throws {
        let graph = try makeGraph()
        expectSnapshot(graph, darkMode: true)
        // And that the composition embeds the fragment rather than rebuilding it.
        let edges = VSVGEdge.render(graph: graph, darkMode: true, logger: TestLogger()).render()
        let full = try VSVGGraph.render(graph: graph, darkMode: true, logger: TestLogger()).render()
        #expect(!edges.isEmpty)
        #expect(full.contains(edges))
    }

    // MARK: - Full path (spline + arrowhead + labels)

    func withLayoutData(_ graph: VGraph, _ layout: EdgeLayoutData) throws -> VGraph {
        try graph.set(edge: edgeId(graph), attribute: Attributes.Edge.layoutData.attribute(layout))
    }

    @Test func splinePathWithArrowHead() throws {
        let layout = EdgeLayoutData(
            splinePoints: [
                VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10),
            ],
            arrowHead: ArrowHeadData(shape: .polygon(points: [VPoint(x: 30, y: 5), VPoint(x: 35, y: 10), VPoint(x: 30, y: 15)]), color: "#ff0000"),
            penwidth: 2.0)
        let graph = try withLayoutData(try makeGraph(), layout)
        expectSnapshot(graph)
    }

    @Test func arrowHeadCircleShape() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            arrowHead: ArrowHeadData(shape: .circle(center: VPoint(x: 30, y: 10), radius: 3), color: "#00ff00"))
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func arrowHeadEllipseShapeFormatsNumbersLikeEveryOtherShape() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            arrowHead: ArrowHeadData(shape: .ellipse(center: VPoint(x: 30, y: 10), radiusX: 5, radiusY: 5), color: "#0000ff"))
        let graph = try withLayoutData(try makeGraph(), layout)
        let rendered = VSVGEdge.render(graph: graph, darkMode: false, logger: TestLogger()).render()
        #expect(rendered.contains("cx=\"30\""))
        #expect(!rendered.contains("cx=\"30.0\""))
        expectSnapshot(graph)
    }

    @Test func arrowHeadSplineShape() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            arrowHead: ArrowHeadData(
                shape: .spline(controlPoints: [
                    VPoint(x: 0, y: 0), VPoint(x: 2, y: 2), VPoint(x: 4, y: 4), VPoint(x: 6, y: 6),
                ]), color: "#123456"))
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func arrowHeadSplineWithTooFewPointsFallsBackToPolygon() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            arrowHead: ArrowHeadData(shape: .spline(controlPoints: [VPoint(x: 0, y: 0), VPoint(x: 2, y: 2)]), color: "#123456"))
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func arrowTailAndBothDirections() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            arrowHead: ArrowHeadData(shape: .circle(center: VPoint(x: 30, y: 10), radius: 3), color: "#ff0000"),
            arrowTail: ArrowHeadData(shape: .circle(center: VPoint(x: 0, y: 0), radius: 3), color: "#00ff00"))
        let graph = try makeGraph()
        let withLayout = try withLayoutData(graph, layout)

        for dir in ["forward", "back", "both", "none"] {
            let withDir = try withLayout.set(edge: edgeId(graph), attribute: Attributes.Edge.dir.attribute(dir))
            expectSnapshot(withDir, variant: dir)
        }
    }

    @Test func dashedAndDottedStyles() throws {
        let base = EdgeLayoutData(splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)])
        for style in ["dashed", "dotted", "solid", "bogus"] {
            let layout = EdgeLayoutData(splinePoints: base.splinePoints, style: style)
            expectSnapshot(try withLayoutData(try makeGraph(), layout), variant: style)
        }
    }

    @Test func explicitEdgeColorOverridesTheThemeDefault() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            color: "#ff00ff")
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func blackColorIsTreatedAsNoExplicitColorButOtherColorsAreHonored() throws {
        let black = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            color: "#000000")
        expectSnapshot(try withLayoutData(try makeGraph(), black))

        let graphWithBlack = try withLayoutData(try makeGraph(), black)
        let blackSVG = VSVGEdge.render(graph: graphWithBlack, darkMode: false, logger: TestLogger()).render()
        #expect(!blackSVG.contains("#000000"), "black should have been remapped to the theme edge colour")
    }

    @Test func labelsHeadLabelAndTailLabelAll() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            label: LabelData(text: "mid", position: VPoint(x: 15, y: 5)),
            headLabel: LabelData(text: "head", position: VPoint(x: 30, y: 10)),
            tailLabel: LabelData(text: "tail", position: VPoint(x: 0, y: 0)))
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func emptySplinePointsFallsBackToStraightLine() throws {
        let layout = EdgeLayoutData(splinePoints: [])
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    @Test func tooFewSplinePointsRendersNoPathButStillLogsAWarning() throws {
        let layout = EdgeLayoutData(splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 1, y: 1)])
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    /// 5 points: (5-1) % 3 != 0, so the B-spline guard rejects it.
    @Test func nonMultipleOf3PlusOnePointCountRendersNoPath() throws {
        let layout = EdgeLayoutData(
            splinePoints: [
                VPoint(x: 0, y: 0), VPoint(x: 1, y: 1), VPoint(x: 2, y: 2), VPoint(x: 3, y: 3), VPoint(x: 4, y: 4),
            ])
        expectSnapshot(try withLayoutData(try makeGraph(), layout))
    }

    // MARK: - keepSet

    @Test func keepSetFiltersEdges() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                node a1: Answer "A";
                node pro1: Pro "P";
                edge q1 -> a1;
                edge a1 -> pro1;
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for (index, node) in graph.nodes.enumerated() {
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: Double(index) * 100 + 50, y: 50)))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        let keep = Set([graph.edges[0]])
        expectSnapshot(graph, keepSet: keep)

        let kept = VSVGEdge.render(graph: graph, darkMode: false, logger: TestLogger(), keepSet: keep).render()
        #expect(kept.contains(SVGElementId.edge(graph.edges[0].id.id)))
        #expect(!kept.contains(SVGElementId.edge(graph.edges[1].id.id)))
    }

    // MARK: - darkMode threading

    let themedColor = "#334455"  // not black, not one of the fallback tokens

    @Test func darkModeAffectsTheEdgeFallbackToken() throws {
        let layout = EdgeLayoutData(splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)])
        let graph = try withLayoutData(try makeGraph(), layout)
        let light = VSVGEdge.render(graph: graph, darkMode: false, logger: TestLogger()).render()
        let dark = VSVGEdge.render(graph: graph, darkMode: true, logger: TestLogger()).render()
        #expect(light.contains(SemanticColor.edge.lightHex))
        #expect(dark.contains(SemanticColor.edge.darkHex))
        #expect(!dark.contains(SemanticColor.edge.lightHex))
    }

    @Test func darkModeAffectsEdgeLabelColor() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            label: LabelData(text: "mid", position: VPoint(x: 15, y: 5)))
        let graph = try withLayoutData(try makeGraph(), layout)
        let light = VSVGEdge.render(graph: graph, darkMode: false, logger: TestLogger()).render()
        let dark = VSVGEdge.render(graph: graph, darkMode: true, logger: TestLogger()).render()
        #expect(light.contains(SemanticColor.ink2.lightHex))
        #expect(dark.contains(SemanticColor.ink2.darkHex))
    }

    @Test func darkModeDoesNotAffectAnExplicitEdgeColor() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            color: themedColor)
        let graph = try withLayoutData(try makeGraph(), layout)
        let light = VSVGEdge.render(graph: graph, darkMode: false, logger: TestLogger()).render()
        let dark = VSVGEdge.render(graph: graph, darkMode: true, logger: TestLogger()).render()
        #expect(light.contains(themedColor))
        #expect(dark.contains(themedColor), "an explicit non-black colour must not be theme-remapped")
    }

    // MARK: - Edge end handles (ADR-0021)

    func withSimpleLayout(_ graph: VGraph) throws -> VGraph {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)])
        return try withLayoutData(graph, layout)
    }

    @Test func interactiveEmitsBothEndHandles() throws {
        let graph = try withSimpleLayout(try makeGraph())
        let id = edgeId(graph).id
        let rendered = VSVGEdge.render(
            graph: graph, darkMode: false, logger: TestLogger(), interactive: true
        ).render()

        #expect(rendered.contains(SVGElementId.edgeEndClass))
        #expect(
            rendered.contains(
                "\(SVGElementId.edgeEndEdgeAttribute)=\"\(id)\" \(SVGElementId.edgeEndSideAttribute)=\"from\""))
        #expect(
            rendered.contains(
                "\(SVGElementId.edgeEndEdgeAttribute)=\"\(id)\" \(SVGElementId.edgeEndSideAttribute)=\"to\""))
        expectSnapshot(graph, interactive: true)
    }

    @Test func nonInteractiveEmitsNoEndHandles() throws {
        // The default — every non-editor caller (CLI, MCP, the Wasm engine export)
        // reaches the renderer this way, and none of them must gain the handles.
        let rendered = VSVGEdge.render(
            graph: try withSimpleLayout(try makeGraph()), darkMode: false, logger: TestLogger()
        ).render()
        #expect(!rendered.contains(SVGElementId.edgeEndClass))
    }

    @Test func endHandleColourFollowsTheEdgeItBelongsTo() throws {
        let layout = EdgeLayoutData(
            splinePoints: [VPoint(x: 0, y: 0), VPoint(x: 10, y: 0), VPoint(x: 20, y: 10), VPoint(x: 30, y: 10)],
            color: themedColor)
        let graph = try withLayoutData(try makeGraph(), layout)
        let rendered = VSVGEdge.render(
            graph: graph, darkMode: false, logger: TestLogger(), interactive: true
        ).render()
        // The ring's stroke is the edge's own colour, never a fixed one — so it
        // can never contradict the notation (ADR-0021).
        #expect(rendered.contains("stroke=\"\(themedColor)\""))
    }

    /// A folded group's box stands in for the node inside it, and
    /// `edgeEndpointIsGroup` means it can never be a drop target — so an end
    /// drawn there gets no handle, or the drag could never be undone by gesture.
    @Test func noHandleOnAnEndSittingOnAFoldedGroup() throws {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: NodeType(string: "Plain"))
        graph = try Notations.FoldGroups.addExtension(addTo: graph)
        graph = try graph.add(
            edgeType: EdgeType(string: "e", from: "Plain", to: "FoldedGroup"))

        let plain = Node("plain")
        let folded = Node("box")
        graph = try graph.add(node: plain, type: NodeType(string: "Plain"))
        graph = try graph.add(node: folded, type: Notations.FoldGroups.NodeTypes.foldedGroup)
            .set(node: folded, attribute: Attributes.Node.standsForGroup.attribute(true))
        let edge = Edge(id: Edge.Id(string: "plainBox"), from: plain, to: folded)
        graph = try graph.add(edge: edge, edgeType: EdgeType(string: "e", from: "Plain", to: "FoldedGroup"))
        graph = try withSimpleLayout(graph)

        let rendered = VSVGEdge.render(
            graph: graph, darkMode: false, logger: TestLogger(), interactive: true
        ).render()

        #expect(
            rendered.contains(
                "\(SVGElementId.edgeEndEdgeAttribute)=\"plainBox\" \(SVGElementId.edgeEndSideAttribute)=\"from\""),
            "the plain end still gets a handle")
        #expect(
            !rendered.contains(
                "\(SVGElementId.edgeEndEdgeAttribute)=\"plainBox\" \(SVGElementId.edgeEndSideAttribute)=\"to\""),
            "the end on the folded group's box must not")
    }
}
