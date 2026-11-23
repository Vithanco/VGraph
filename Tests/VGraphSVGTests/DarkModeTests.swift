////  Tests for the renderer's emit-time resolution of `SemanticColor` to
////  concrete hex (§11 of the Vithanco Diagram Style Guide v2).
////

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct DarkModeTests {

    // MARK: - Renderer direct-emit (no post-pass CSS)

    /// `data-theme="dark"` survives on the root SVG element as a tooling hint,
    /// but the CSS attribute-selector post-pass is gone — colours are resolved
    /// at SVG emit time via `SemanticColor.resolve(darkMode:)`.
    @Test func rendererSetsDataThemeButNotOverrideCSS() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "What should we do?";
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)
        var layoutedGraph = graph
        for node in graph.nodes {
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }

        let renderer = VSVGRenderer(logger: TestLogger())
        let darkSvg = try renderer.render(graph: layoutedGraph, darkMode: true)
        let lightSvg = try renderer.render(graph: layoutedGraph, darkMode: false)

        #expect(darkSvg.contains("data-theme=\"dark\""))
        #expect(!lightSvg.contains("data-theme=\"dark\""))
        // No CSS attribute-selector override block in either output.
        #expect(!darkSvg.contains("[data-theme=\"dark\"]"))
        #expect(!lightSvg.contains("[data-theme=\"dark\"]"))
    }

    /// Regression for chat5.md: a group rendered with default styling must
    /// flip its fill / border / label color in dark mode. Before the fix,
    /// the renderer emitted the light hex `#f4f3f0` regardless of theme —
    /// so the group container ended up *brighter* than its children in
    /// dark mode (the bug the design's §11 update was prompted by).
    @Test func groupDefaultsFlipInDarkMode() throws {
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
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(
                    VPoint(x: Double(index) * 100 + 50, y: 50)))
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        let group = graph.groups[0]
        layoutedGraph = try layoutedGraph.setting(
            group: group,
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(x: 80, y: 10, width: 200, height: 100)))
        layoutedGraph = try layoutedGraph.setting(
            group: group,
            attribute: Attributes.Group.labelLayoutedPos.attribute(VPoint(x: 180, y: 20)))

        let renderer = VSVGRenderer(logger: TestLogger())
        let lightSvg = try renderer.render(graph: layoutedGraph, darkMode: false)
        let darkSvg = try renderer.render(graph: layoutedGraph, darkMode: true)

        // Scope assertions to the group element so unrelated tokens sharing a
        // hex (e.g. watermark light = #c8c4bc = groupText dark) don't collide.
        let lightGroup = try #require(extractGroupElement(svg: lightSvg, id: "g1"))
        let darkGroup = try #require(extractGroupElement(svg: darkSvg, id: "g1"))

        #expect(lightGroup.contains("#f4f3f0"), "Light group missing groupFill light #f4f3f0")
        #expect(lightGroup.contains("#909088"), "Light group missing groupBorder light #909088")
        #expect(lightGroup.contains("#505048"), "Light group missing groupText light #505048")

        #expect(darkGroup.contains("#1c1a16"), "Dark group missing groupFill dark #1c1a16")
        #expect(darkGroup.contains("#7a766e"), "Dark group missing groupBorder dark #7a766e")
        #expect(darkGroup.contains("#c8c4bc"), "Dark group missing groupText dark #c8c4bc")

        #expect(!lightGroup.contains("#1c1a16"))
        #expect(!lightGroup.contains("#7a766e"))
        #expect(!lightGroup.contains("#c8c4bc"))

        #expect(!darkGroup.contains("#f4f3f0"))
        #expect(!darkGroup.contains("#909088"))
        #expect(!darkGroup.contains("#505048"))
    }

    @Test func foldingKeepsTheGroupsDarkColors() throws {
        let graph = try VGraphParser(logger: TestLogger()).parse(
            source: """
                vgraph myGraph: IBIS "Test Graph" {
                    folded group g1 "My Group" {
                        node a1: Answer "Answer in group";
                    };
                }
                """)
        var folded = try TransformStep.pipeline(Notations.extensionSteps)(graph)
        for node in folded.nodes {
            folded = try folded.setting(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 50)))
            folded = try folded.setting(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 160, height: 50)))
        }

        let darkSvg = try VSVGRenderer(logger: TestLogger()).render(graph: folded, darkMode: true)

        #expect(darkSvg.contains("fill=\"\(SemanticColor.groupFill.darkHex)\""))
        #expect(darkSvg.contains("stroke=\"\(SemanticColor.groupBorder.darkHex)\""))
        #expect(darkSvg.contains("fill=\"\(SemanticColor.groupText.darkHex)\""))
    }

    /// Edge labels must render as DM Sans 11px italic in `SemanticColor.ink2`
    /// (Diagram Style Guide §04/§05 update). Promoted from ink-3 to ink-2 to
    /// clear AA contrast at small italic sizes in dark mode.
    @Test func edgeLabelsUseInk2AndItalic() throws {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
                node a1: Answer "A";
                edge q1 -> a1 "edge-label-here";
            }
            """

        let parser = VGraphParser(logger: TestLogger())
        let graph = try parser.parse(source: input)
        var layoutedGraph = graph
        for (index, node) in graph.nodes.enumerated() {
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(
                    VPoint(x: Double(index) * 100 + 50, y: 50)))
            layoutedGraph = try layoutedGraph.setting(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        // Synthesise an EdgeLayoutData with a label so renderEdgeLabel is exercised.
        let edge = graph.edges[0]
        let edgeLayout = EdgeLayoutData(
            splinePoints: [VPoint(x: 50, y: 50), VPoint(x: 150, y: 50)],
            label: LabelData(text: "edge-label-here", position: VPoint(x: 100, y: 50))
        )
        layoutedGraph = try layoutedGraph.setting(
            edge: edge.id,
            attribute: Attributes.Edge.layoutData.attribute(edgeLayout))

        let renderer = VSVGRenderer(logger: TestLogger())
        let lightSvg = try renderer.render(graph: layoutedGraph, darkMode: false)
        let darkSvg = try renderer.render(graph: layoutedGraph, darkMode: true)

        // Pull the <text> that holds the edge label so chrome <text> elements
        // (group label, graph label, watermark) can't satisfy the assertion.
        let extract: (String) -> String? = { svg in
            guard let start = svg.range(of: "edge-label-here") else { return nil }
            guard
                let openStart = svg.range(
                    of: "<text", options: .backwards,
                    range: svg.startIndex..<start.upperBound)
            else { return nil }
            guard let openEnd = svg.range(of: ">", range: openStart.upperBound..<svg.endIndex)
            else { return nil }
            return String(svg[openStart.lowerBound..<openEnd.upperBound])
        }
        let lightText = try #require(extract(lightSvg))
        let darkText = try #require(extract(darkSvg))

        #expect(lightText.contains("fill=\"#5a564e\""), "Light edge label not ink-2 #5a564e")
        #expect(darkText.contains("fill=\"#a8a49a\""), "Dark edge label not ink-2 dark #a8a49a")
        #expect(lightText.contains("font-size=\"11\""), "Light edge label not 11px")
        #expect(darkText.contains("font-size=\"11\""), "Dark edge label not 11px")
        #expect(lightText.contains("font-style=\"italic\""), "Light edge label not italic")
        #expect(darkText.contains("font-style=\"italic\""), "Dark edge label not italic")
    }

    /// Style guide §05: a junctor is a `--junctor` circle, `#303030` light and
    /// `#e8e3db` dark. Its letters are knocked out of the artwork, so the canvas
    /// shows through as the `--junctor-fg` label in either theme.
    @Test func junctorIconFlipsWithTheme() throws {
        let icon = IconInfo(
            iconPosition: .center, iconName: "and", iconColor: SemanticColor.junctor.resolve(darkMode: false),
            iconSize: 32)
        let bounds = VRect(x: 0, y: 0, width: 32, height: 32)
        let render: (Bool) throws -> String = { dark in
            try VSVGNodeLayout.render(
                style: .icon(icon), wrappedText: [], bounds: bounds, font: VFont(size: 14), darkMode: dark
            ).render()
        }
        #expect(try render(false).contains("fill=\"#303030\""))
        #expect(try render(true).contains("fill=\"#e8e3db\""))
    }

    @Test func junctorTypesUseTheJunctorToken() throws {
        let graph = try VGraphParser(logger: TestLogger()).parse(
            source: """
                vgraph crt: CRT "Junctor" {
                    node j: AndJunctor
                }
                """)
        let icon = try graph.get(
            nodeType: Notations.CurrentRealityTree.NodeTypes.andJunctor, attribute: Attributes.Node.iconInfo)
        #expect(icon.iconColor.hexString == SemanticColor.junctor.lightHex)
    }

    /// Pull the substring `<g id="group-<id>"…</g>` from a rendered SVG so
    /// hex-contains assertions are scoped to that group's chrome only.
    private func extractGroupElement(svg: String, id: String) -> String? {
        let opener = "<g id=\"group-\(id)\""
        guard let start = svg.range(of: opener) else { return nil }
        // The group's <g> contains a single `<rect>` and `<text>`; child nodes
        // live in sibling <g> blocks after this one closes. So the first
        // `</g>` after `start` is ours.
        guard let end = svg.range(of: "</g>", range: start.upperBound..<svg.endIndex)
        else { return nil }
        return String(svg[start.lowerBound..<end.upperBound])
    }
}
