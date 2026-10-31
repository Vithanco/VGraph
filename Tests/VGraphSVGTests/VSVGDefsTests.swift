// Mostly pure: `renderDefs` never touches the graph, so most cases compare
// against the same building blocks it calls, with no VGraph at all.

import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct VSVGDefsTests {

    // MARK: - Pure (renderDefs never touches the graph)

    static let expectedStyles =
        VSVGBuilder.style(css: SVGBuilder.dmSansFontImportCSS()).render()
        + VSVGBuilder.style(css: SVGBuilder.hoverStylesCSS()).render()

    @Test func noIconsNoWatermarkReturnsJustTheFontImport() throws {
        let ported = VSVGDefs.render(icons: [:], includeWatermark: false, darkMode: false).render()
        #expect(ported == Self.expectedStyles)
        #expect(!ported.contains("<defs>"), "the early-return path must not wrap in <defs> at all")
    }

    @Test func theFontImportURLIsEscapedForXMLButNotOverEscaped() throws {
        let ported = VSVGDefs.render(icons: [:], includeWatermark: false, darkMode: false).render()
        #expect(ported.contains("&amp;display=swap"))
        #expect(!ported.contains("&amp;amp;"))
        #expect(ported.contains("url('https://fonts.googleapis.com"), "quotes must survive unescaped")
        #expect(ported.contains(".vgraph-group > rect"), "the child combinator must survive unescaped")
    }

    @Test func watermarkOnlyWrapsInDefsWithTheWatermarkSymbol() throws {
        let ported = VSVGDefs.render(icons: [:], includeWatermark: true, darkMode: false).render()
        #expect(ported.hasPrefix(Self.expectedStyles))
        #expect(ported.contains("<defs>"))
        #expect(ported.contains("vithanco-watermark"))
        #expect(ported.hasSuffix("</defs>"))
    }

    @Test func darkModeWatermarkUsesTheDarkFillToken() throws {
        let light = VSVGDefs.render(icons: [:], includeWatermark: true, darkMode: false).render()
        let dark = VSVGDefs.render(icons: [:], includeWatermark: true, darkMode: true).render()
        #expect(light.contains(SemanticColor.watermark.lightHex))
        #expect(dark.contains(SemanticColor.watermark.darkHex))
        #expect(!dark.contains(SemanticColor.watermark.lightHex))
    }

    @Test func oneKnownIconIsIncludedVerbatim() throws {
        let artwork = try #require(BuiltinIcons.artwork(for: "and"))
        let expectedIconDef = IconRenderer.renderDefinition(name: "and", artwork: artwork).render()
        let ported = VSVGDefs.render(
            icons: ["and": artwork], includeWatermark: false, darkMode: false
        ).render()
        #expect(ported.contains(expectedIconDef))
        #expect(!ported.contains("vithanco-watermark"))
    }

    @Test func iconsAreSortedForDeterministicOutput() throws {
        let icons: [String: IconArtwork] = ["zebra.icon": .missing, "alpha.icon": .missing]
        // Both are unknown, which no longer stops either from being emitted, so
        // the ordering is read off the output directly.
        let ported = VSVGDefs.render(icons: icons, includeWatermark: false, darkMode: false).render()
        let alpha = try #require(ported.range(of: "icon-alpha.icon"))
        let zebra = try #require(ported.range(of: "icon-zebra.icon"))
        #expect(alpha.lowerBound < zebra.lowerBound)
    }

    /// The id has to stay the requested name: `<use href="#icon-…">` was written
    /// from the same name and cannot know the artwork was substituted.
    @Test func anUnknownIconNameIsDefinedAsTheMissingPlaceholder() throws {
        let ported = VSVGDefs.render(icons: ["nonexistent.icon": .missing], includeWatermark: false, darkMode: false).render()

        #expect(ported.contains("id=\"icon-nonexistent.icon\""))
        #expect(ported.contains(IconArtwork.missing.path))
    }

    @Test func iconsAndWatermarkTogetherBothAppearInOneDefsBlock() throws {
        let ported = VSVGDefs.render(
            icons: ["and": BuiltinIcons.artwork(for: "and")!], includeWatermark: true, darkMode: false
        ).render()
        #expect(ported.contains("icon-and"))
        #expect(ported.contains("vithanco-watermark"))
        // Exactly one <defs> wrapper, not one per content type.
        #expect(ported.components(separatedBy: "<defs>").count == 2)
        #expect(ported.components(separatedBy: "</defs>").count == 2)
    }

    // MARK: - Wiring: does the real pipeline actually feed this what we assume?

    func makeSimpleGraph() throws -> VGraph {
        let input = """
            vgraph myGraph: IBIS "Test Graph" {
                node q1: Question "Q";
            }
            """
        let parser = VGraphParser(logger: TestLogger())
        var graph = try parser.parse(source: input)
        for node in graph.nodes {
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 50, y: 50)))
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 80, height: 40)))
        }
        return graph
    }

    @Test func defaultWatermarkAttributeIsTrueAndReachesTheOutput() throws {
        // Attributes.Group.watermark defaults to true — confirm the real
        // pipeline actually surfaces the watermark symbol without an explicit
        // override, matching the `includeWatermark: true` assumption above.
        let graph = try makeSimpleGraph()
        let full = try VSVGGraph.render(graph: graph, logger: TestLogger()).render()
        #expect(full.contains("vithanco-watermark"))
    }

    @Test func watermarkDisabledOmitsItFromTheRealPipeline() throws {
        var graph = try makeSimpleGraph()
        graph = try graph.set(graphAttribute: Attributes.Group.watermark.attribute(false))
        let full = try VSVGGraph.render(graph: graph, logger: TestLogger()).render()
        let defs = VSVGDefs.render(icons: [:], includeWatermark: false, darkMode: false).render()
        #expect(!full.contains("vithanco-watermark"))
        #expect(full.contains(defs))
    }
}
