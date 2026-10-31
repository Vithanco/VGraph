// Regression + bugfix tests for `CLDOverlayProvider`. Verifies that the
// CLD loop indicators continue to render at expected positions after the
// migration from inline-in-SVGRenderer to overlay provider, AND that the
// pre-migration hardcoded `#808078` dark-mode bug is fixed (indicator color
// now resolves through `SemanticColor.loopIndicator`).

import TestSupport
import Testing

@testable import VGraph
@testable import VGraphSVG

struct CLDOverlayTests {

    typealias CLD = Notations.CausalLoopDiagram

    /// Build a small CLD with a 2-node reinforcing cycle, programmatically
    /// (not via VGL parser) so loop styling is wired up correctly.
    /// Includes the layout data the renderer + overlay need.
    private func makeCLDWithCycle() throws -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        graph = graph.using(notation: "CLD")

        // Two stocks, cycle via `same` edges (which carry reinforcing loopStyle).
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

        // Mock layout positions. Centroid will be (200, 100).
        graph = try graph.set(
            node: a, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
        graph = try graph.set(
            node: b, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 300, y: 100)))
        graph = try graph.set(
            node: a, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))
        graph = try graph.set(
            node: b, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))

        // Mock edge layout: spline endpoints offset so loopDirection's Shoelace
        // algorithm forms a quadrilateral with real area.
        let topLayout = EdgeLayoutData(
            splinePoints: [VPoint(x: 130, y: 90), VPoint(x: 270, y: 90)],
            color: "#000000", penwidth: 1.0
        )
        let bottomLayout = EdgeLayoutData(
            splinePoints: [VPoint(x: 270, y: 110), VPoint(x: 130, y: 110)],
            color: "#000000", penwidth: 1.0
        )
        graph = try graph.set(edge: e1.id, attribute: Attributes.Edge.layoutData.attribute(topLayout))
        graph = try graph.set(edge: e2.id, attribute: Attributes.Edge.layoutData.attribute(bottomLayout))

        // Root group bounds.
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(x: 0, y: 0, width: 400, height: 200)))

        return graph
    }

    // MARK: - Regression: loop indicators still render

    @Test func loopIndicatorRendersWithExpectedMarkup() throws {
        let graph = try makeCLDWithCycle()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)

        #expect(svg.contains("loop-indicator"), "Should emit loop-indicator <g> group")
        #expect(svg.contains(">R<"), "Reinforcing cycle should produce an 'R' letter")
        #expect(svg.contains(" A "), "Loop indicator arc path command should appear")
    }

    @Test func loopIndicatorAppearsNearCentroid() throws {
        // 2-node cycle with nodes at x=100, x=300 → centroid x=200.
        // SVG output uses `200.0` (Swift's default Double formatting), so
        // accept either `200.0` or `200` to be format-agnostic.
        let graph = try makeCLDWithCycle()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)
        #expect(
            svg.contains("x=\"200.0\"") || svg.contains("x=\"200\""),
            "Indicator label should be placed at centroid x=200"
        )
    }

    // MARK: - Bug fix: dark mode now applies

    @Test func lightModeUsesLightToken() throws {
        let graph = try makeCLDWithCycle()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph, darkMode: false)
        // SemanticColor.loopIndicator lightHex = #808078.
        #expect(svg.contains("#808078"), "Light-mode indicator color should be #808078")
    }

    @Test func darkModeUsesDarkToken() throws {
        // BUG FIX: pre-migration code hardcoded `#808078` and ignored
        // SemanticColor.loopIndicator's dark variant. After the migration the
        // dark hex (#a8a49a) should appear in the indicator markup.
        let graph = try makeCLDWithCycle()
        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph, darkMode: true)
        // SemanticColor.loopIndicator darkHex = #a8a49a.
        #expect(svg.contains("#a8a49a"), "Dark-mode indicator color should be #a8a49a")
    }

    // MARK: - Empty CLD (no cycles)

    @Test func cldWithoutCyclesEmitsNoIndicators() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        graph = graph.using(notation: "CLD")

        let a = Node(string: "a")
        let b = Node(string: "b")
        graph = try graph.add(node: a, type: CLD.NodeTypes.stock)
        graph = try graph.add(node: b, type: CLD.NodeTypes.stock)
        graph = try graph.set(node: a, attribute: Attributes.Node.wrappedText.attribute(["A"]))
        graph = try graph.set(node: b, attribute: Attributes.Node.wrappedText.attribute(["B"]))

        let e1 = Edge(string: "e1", from: "a", to: "b")
        graph = try graph.add(edge: e1, edgeType: CLD.EdgeTypes.same)

        graph = try graph.set(
            node: a, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 100, y: 100)))
        graph = try graph.set(
            node: b, attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: 200, y: 100)))
        graph = try graph.set(
            node: a, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))
        graph = try graph.set(
            node: b, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 60, height: 30)))
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.layoutedBounds.attribute(
                VRect(x: 0, y: 0, width: 300, height: 200)))

        let renderer = VSVGRenderer(logger: TestLogger())
        let svg = try renderer.render(graph: graph)
        // Match the drawn element, not the `.loop-indicator` rule baked into the
        // static hover <style> (which is present regardless of cycles).
        #expect(!svg.contains("class=\"loop-indicator\""), "Acyclic CLD should emit no loop indicators")
    }
}
