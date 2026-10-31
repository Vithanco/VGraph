// The watermark avoids the rectangles collectGroupLabelRects returns, so those
// rectangles must be where the labels are actually drawn. Each test checks the
// collected rects against the rendered SVG rather than against the layout data.

import Foundation
import TestSupport
import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct GroupLabelRectsTests {

    let rootLabelRect = VRect(x: 210, y: 283, width: 80, height: 14)

    func laidOut(_ source: String, groupBounds: [String: VRect], nodes: [String: VPoint] = [:]) throws -> VGraph {
        var graph = try VGraphParser(logger: TestLogger()).parse(source: source)
        for node in graph.nodes {
            let pos = nodes[node.id] ?? VPoint(x: 250, y: 150)
            graph = try graph.set(node: node, attribute: Attributes.Node.layoutedPos.attribute(pos))
            graph = try graph.set(
                node: node, attribute: Attributes.Node.layoutedSize.attribute(VSize(width: 90, height: 44)))
        }
        for group in graph.groups {
            if let bounds = groupBounds[group.id.id] {
                graph = try graph.set(group: group, attribute: Attributes.Group.layoutedBounds.attribute(bounds))
            }
        }
        let root = Group(rawValue: rootGroup)
        graph = try graph.set(
            group: root, attribute: Attributes.Group.layoutedBounds.attribute(VRect(x: 0, y: 0, width: 500, height: 300)))
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.labelLayoutedPos.attribute(
                VPoint(x: rootLabelRect.minX + rootLabelRect.width / 2, y: rootLabelRect.minY + rootLabelRect.height / 2)))
        graph = try graph.set(
            group: root,
            attribute: Attributes.Group.labelLayoutedSize.attribute(
                VSize(width: rootLabelRect.width, height: rootLabelRect.height)))
        return graph
    }

    func svg(_ graph: VGraph) throws -> String {
        try VSVGGraph.render(graph: graph, darkMode: false, logger: TestLogger()).render()
    }

    /// Each drawn group label: its anchor (x, baseline y) and its text.
    func drawnGroupLabels(in svg: String) -> [(x: Double, y: Double, text: String)] {
        let tag = try! NSRegularExpression(
            pattern: "<text([^>]*class=\"\(SVGElementId.groupLabelClass)\"[^>]*)>([^<]*)</text>")
        let range = NSRange(svg.startIndex..., in: svg)
        return tag.matches(in: svg, range: range).compactMap { match in
            let attributes = String(svg[Range(match.range(at: 1), in: svg)!])
            let text = String(svg[Range(match.range(at: 2), in: svg)!])
            guard let x = number(named: "x", in: attributes), let y = number(named: "y", in: attributes) else {
                return nil
            }
            return (x, y, text)
        }
    }

    func number(named name: String, in attributes: String) -> Double? {
        let attribute = try! NSRegularExpression(pattern: "\\s\(name)=\"([-0-9.]+)\"")
        let range = NSRange(attributes.startIndex..., in: attributes)
        guard let match = attribute.firstMatch(in: attributes, range: range) else { return nil }
        return Double(attributes[Range(match.range(at: 1), in: attributes)!])
    }

    /// A rect covers a drawn label when it holds the label's first and last glyph
    /// just above the baseline.
    func covers(_ rect: VRect, _ label: (x: Double, y: Double, text: String)) -> Bool {
        let width = TextSizeEstimator.estimateWidth(text: label.text, font: VFont(family: .dmSans, size: 11))
        let first = VPoint(x: label.x + 1, y: label.y - 3)
        let last = VPoint(x: label.x + width - 1, y: label.y - 3)
        return [first, last].allSatisfy { p in
            p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
        }
    }

    // MARK: - The graph's own label

    @Test func theGraphLabelIsCollectedWhenThereAreNoGroups() throws {
        let graph = try laidOut(
            """
            vgraph g: IBIS "The Title" {
                node q: Question "Why?";
            }
            """, groupBounds: [:])

        #expect(SVGRenderQueries.collectGroupLabelRects(graph: graph) == [rootLabelRect])
    }

    @Test func theGraphLabelIsCollectedOnceBesideTheGroupLabels() throws {
        let graph = try laidOut(
            """
            vgraph g: IBIS "The Title" {
                group a "Alpha" { node q: Question "Why?"; };
                group b "Beta" { node r: Question "How?"; };
            }
            """,
            groupBounds: ["a": VRect(x: 10, y: 10, width: 200, height: 120), "b": VRect(x: 260, y: 10, width: 200, height: 120)])

        let rects = SVGRenderQueries.collectGroupLabelRects(graph: graph)
        #expect(rects.filter { $0 == rootLabelRect }.count == 1)
        #expect(rects.count == 3)
    }

    // MARK: - Group labels, as drawn

    @Test func everyDrawnGroupLabelIsCoveredIncludingNestedOnes() throws {
        let graph = try laidOut(
            """
            vgraph g: IBIS "The Title" {
                group outer "Outer Zone" {
                    group inner "Inner Zone" { node q: Question "Why?"; };
                };
            }
            """,
            groupBounds: [
                "outer": VRect(x: 10, y: 10, width: 400, height: 250),
                "inner": VRect(x: 40, y: 60, width: 250, height: 150),
            ])

        let drawn = drawnGroupLabels(in: try svg(graph))
        #expect(drawn.map { $0.text } == ["OUTER ZONE", "INNER ZONE"])
        let rects = SVGRenderQueries.collectGroupLabelRects(graph: graph)
        for label in drawn {
            #expect(rects.contains { covers($0, label) }, "no rect covers \(label.text) at (\(label.x), \(label.y))")
        }
    }

    @Test func aDetailedNodesLabelIsCovered() throws {
        let graph = try laidOut(
            """
            vgraph g: C4 "Banking" {
                group bank: Organisation "Big Bank" {
                    group ibs: SoftwareSystem "Internet Banking" {
                        isfolded: false;
                        node ui: Container "UI";
                    };
                };
            }
            """,
            groupBounds: [
                "bank": VRect(x: 10, y: 10, width: 400, height: 250),
                "ibs": VRect(x: 40, y: 60, width: 250, height: 150),
            ])

        let drawn = drawnGroupLabels(in: try svg(graph))
        #expect(drawn.map { $0.text } == ["BIG BANK", "INTERNET BANKING"])
        let rects = SVGRenderQueries.collectGroupLabelRects(graph: graph)
        for label in drawn {
            #expect(rects.contains { covers($0, label) }, "no rect covers \(label.text)")
        }
    }

    @Test func onlyDrawnLabelsAreCollected() throws {
        let graph = try laidOut(
            """
            vgraph g: IBIS "The Title" {
                group named "Named" { node q: Question "Why?"; };
                group unnamed { node r: Question "How?"; };
                group unplaced "Not laid out" { node s: Question "When?"; };
            }
            """,
            groupBounds: [
                "named": VRect(x: 10, y: 10, width: 200, height: 120),
                "unnamed": VRect(x: 260, y: 10, width: 200, height: 120),
            ])

        let drawn = drawnGroupLabels(in: try svg(graph))
        let rects = SVGRenderQueries.collectGroupLabelRects(graph: graph)
        #expect(rects.count == drawn.count + 1)
    }

    // MARK: - The watermark

    @Test func theWatermarkAvoidsAGroupLabelInAFreeCorner() throws {
        // Both bottom corners hold nodes; top-left holds only the group's label;
        // top-right is free. The corner order is bottom-left, bottom-right,
        // top-left, top-right, so without the label the watermark lands on it.
        let graph = try laidOut(
            """
            vgraph g: IBIS {
                group zone "Internet Banking System" {
                    node a: Question "A";
                    node b: Question "B";
                };
            }
            """,
            groupBounds: ["zone": VRect(x: 0, y: 0, width: 500, height: 300)],
            nodes: ["a": VPoint(x: 45, y: 278), "b": VPoint(x: 455, y: 278)])

        let rendered = try svg(graph)
        let use = try #require(rendered.range(of: "<use[^>]*vithanco-watermark[^>]*>", options: .regularExpression))
        let tag = String(rendered[use])
        let x = try #require(number(named: "x", in: tag))
        let y = try #require(number(named: "y", in: tag))
        #expect(x > 250 && y < 150, "watermark at (\(x), \(y)); expected the free top-right corner")
    }
}
