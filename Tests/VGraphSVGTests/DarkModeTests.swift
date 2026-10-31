////  Tests for `ColorMath.darkOf` (the algorithmic dark-palette derivation
////  from §11 of the Vithanco Diagram Style Guide v2) and the renderer's
////  emit-time resolution of `SemanticColor` to concrete hex.
////

import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct DarkModeTests {

    // MARK: - darkOf algorithm

    /// Light tints (>70% L) must collapse to a dark fill (~13% L) — same hue,
    /// desaturated. Verified against the spec example `#fdeef1` → `#2b1115` band.
    @Test func darkOfLightTintProducesDarkFill() {
        let light = VColor(hexString: "#fdeef1")!
        let dark = ColorMath.darkOf(light)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l < 20, "Light tint should drop to ~13% lightness, got \(l)")
    }

    /// Deep texts (<30% L) must rise to a pastel (~86% L) — same hue.
    @Test func darkOfDeepTextProducesLightPastel() {
        let deep = VColor(hexString: "#301878")!  // IBIS Question text
        let dark = ColorMath.darkOf(deep)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l > 80, "Deep text should rise to ~86% lightness, got \(l)")
    }

    /// Mid-band colors (30-70% L) stay vibrant — lightness lifted to at least 62%.
    @Test func darkOfMidBandStaysVibrant() {
        let mid = VColor(hexString: "#6038d0")!  // IBIS Question border
        let dark = ColorMath.darkOf(mid)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(l >= 62, "Mid-band border should be lifted to ≥62% lightness, got \(l)")
    }

    /// Near-neutral colors (<8% S) just mirror lightness — keeps grays gray.
    @Test func darkOfNeutralGrayMirrorsLightness() {
        let gray = VColor(hexString: "#909090")!
        let dark = ColorMath.darkOf(gray)
        let (_, _, l) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        // 100 - 56.5 ≈ 43.5
        #expect(abs(l - 43.5) < 2, "Neutral gray should mirror lightness, got \(l)")
    }

    /// Hue must be preserved across the transform — that's what keeps each notation
    /// recognisable in dark mode.
    @Test func darkOfPreservesHue() {
        let light = VColor(hexString: "#ebfff2")!  // IBIS Pro fill
        let dark = ColorMath.darkOf(light)
        let (h1, _, _) = ColorMath.rgbToHSL(r: light.redComponent, g: light.greenComponent, b: light.blueComponent)
        let (h2, _, _) = ColorMath.rgbToHSL(r: dark.redComponent, g: dark.greenComponent, b: dark.blueComponent)
        #expect(abs(h1 - h2) < 1, "Hue must be preserved, got \(h1) vs \(h2)")
    }

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
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            layoutedGraph = try layoutedGraph.set(
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

    /// Direct-emit invariant for a known SemanticColor token: the watermark
    /// uses `#c8c4bc` (light) vs `#4a4842` (dark). With the post-pass deleted,
    /// these hexes must appear directly in the SVG output.
    @Test func watermarkUsesDarkHexInDarkMode() {
        // Use the watermark renderer directly — avoids needing a fully-laid-out
        // graph for bounds. Direct test of SemanticColor resolution at emit time.
        let darkHex = SemanticColor.watermark.resolve(darkMode: true).hexString
        let lightHex = SemanticColor.watermark.resolve(darkMode: false).hexString
        #expect(darkHex == "#4a4842")
        #expect(lightHex == "#c8c4bc")
    }

    /// Same invariant for the edge token — `#b0a898` light / `#6e6a60` dark.
    @Test func edgeTokenResolves() {
        #expect(SemanticColor.edge.resolve(darkMode: false).hexString == "#b0a898")
        #expect(SemanticColor.edge.resolve(darkMode: true).hexString == "#6e6a60")
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
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(
                    VPoint(x: Double(index) * 100 + 50, y: 50)))
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        let group = graph.groups[0]
        layoutedGraph = try layoutedGraph.set(
            group: group,
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(x: 80, y: 10, width: 200, height: 100)))
        layoutedGraph = try layoutedGraph.set(
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
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(
                    VPoint(x: Double(index) * 100 + 50, y: 50)))
            layoutedGraph = try layoutedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        // Synthesise an EdgeLayoutData with a label so renderEdgeLabel is exercised.
        let edge = graph.edges[0]
        let edgeLayout = EdgeLayoutData(
            splinePoints: [VPoint(x: 50, y: 50), VPoint(x: 150, y: 50)],
            label: LabelData(text: "edge-label-here", position: VPoint(x: 100, y: 50))
        )
        layoutedGraph = try layoutedGraph.set(
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
