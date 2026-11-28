import Foundation
import TestSupport
import Testing

@testable import VGLanguage
@testable import VGraph
@testable import VGraphSVG

struct WatermarkPlacementTests {

    let bounds = VRect(x: 0, y: 0, width: 400, height: 300)
    let nodeSize = VSize(width: 120, height: 80)

    func laidOut(nodesAt centers: [VPoint], size: VSize? = nil) throws -> VGraph {
        let declarations = centers.indices.map { "    node n\($0): Question \"Node \($0)\";" }
        let source = "vgraph g: IBIS {\n" + declarations.joined(separator: "\n") + "\n}"
        var graph = try VGraphParser(logger: TestLogger()).parse(source: source)
        for (node, center) in zip(graph.nodes, centers) {
            graph = try graph.setting(node: node, attribute: Attributes.Node.layoutedPos(center))
            graph = try graph.setting(node: node, attribute: Attributes.Node.layoutedSize(size ?? nodeSize))
        }
        return try graph.setting(
            group: Group.root, attribute: Attributes.Group.layoutedBounds(bounds))
    }

    func nodeRect(at center: VPoint) -> VRect {
        VRect(
            x: center.x - nodeSize.width / 2, y: center.y - nodeSize.height / 2,
            width: nodeSize.width, height: nodeSize.height)
    }

    func svg(_ graph: VGraph, overlays: [String: NotationOverlayEntry] = [:]) throws -> String {
        try VSVGGraph.render(graph: graph, darkMode: false, logger: TestLogger(), overlayProviders: overlays).render()
    }

    /// Stands in for CLD's loop markers: drawn by the renderer, not a node or a label.
    struct MarkerOverlay: NotationOverlayProvider {
        let notationName: String
        let marker: VRect
        func boundsContributions(graph: VGraph) -> [VRect] { [marker] }
    }

    func watermarkRect(in svg: String) throws -> VRect {
        let tag = try #require(firstMatch("<use href=\"#vithanco-watermark\"([^>]*)>", in: svg))
        return VRect(
            x: try #require(number("x", in: tag)), y: try #require(number("y", in: tag)),
            width: try #require(number("width", in: tag)), height: try #require(number("height", in: tag)))
    }

    func viewBox(of svg: String) throws -> VRect {
        let values = try #require(firstMatch("viewBox=\"([^\"]*)\"", in: svg))
            .split(separator: " ").compactMap { Double($0) }
        try #require(values.count == 4)
        return VRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    func firstMatch(_ pattern: String, in text: String) -> String? {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return String(text[Range(match.range(at: 1), in: text)!])
    }

    func number(_ name: String, in attributes: String) -> Double? {
        firstMatch("\\s\(name)=\"([-0-9.e]+)\"", in: attributes).flatMap { Double($0) }
    }

    func overlaps(_ a: VRect, _ b: VRect) -> Bool {
        min(a.maxX, b.maxX) > max(a.minX, b.minX) && min(a.maxY, b.maxY) > max(a.minY, b.minY)
    }

    func contains(_ outer: VRect, _ inner: VRect) -> Bool {
        inner.minX >= outer.minX && inner.maxX <= outer.maxX && inner.minY >= outer.minY && inner.maxY <= outer.maxY
    }

    var cornerCenters: [VPoint] {
        [
            VPoint(x: 60, y: 40), VPoint(x: 340, y: 40),
            VPoint(x: 60, y: 260), VPoint(x: 340, y: 260),
        ]
    }

    @Test func aNodeInEveryCornerDoesNotPushTheWatermarkOntoOne() throws {
        let rendered = try svg(laidOut(nodesAt: cornerCenters))
        let watermark = try watermarkRect(in: rendered)

        for center in cornerCenters {
            #expect(!overlaps(watermark, nodeRect(at: center)), "watermark \(watermark) covers node at \(center)")
        }
    }

    @Test func aNodeFillingTheDiagramDoesNotSitUnderTheWatermark() throws {
        let rendered = try svg(
            laidOut(nodesAt: [VPoint(x: 200, y: 150)], size: VSize(width: 400, height: 300)))

        #expect(!overlaps(try watermarkRect(in: rendered), bounds))
    }

    @Test func aWatermarkMovedOffTheDiagramStaysInsideTheImage() throws {
        let rendered = try svg(laidOut(nodesAt: cornerCenters))

        #expect(contains(try viewBox(of: rendered), try watermarkRect(in: rendered)))
    }

    @Test func anOverlayMarkerInTheFirstCornerIsNotCovered() throws {
        let graph = try laidOut(nodesAt: [cornerCenters[3]])
        let marker = VRect(x: 0, y: 260, width: 40, height: 40)
        let overlay = MarkerOverlay(notationName: graph.notationName, marker: marker)
        let rendered = try svg(graph, overlays: [graph.notationName: overlay.overlayEntry])

        #expect(!overlaps(try watermarkRect(in: rendered), marker))
    }

    @Test func aFreeCornerKeepsTheWatermarkOnTheDiagramWithoutGrowingTheImage() throws {
        let occupied = Array(cornerCenters.dropFirst(2)) + [cornerCenters[1]]
        let rendered = try svg(laidOut(nodesAt: occupied))
        let watermark = try watermarkRect(in: rendered)

        #expect(contains(bounds, watermark))
        #expect(try viewBox(of: rendered) == VRect(x: -20, y: -20, width: 440, height: 340))
    }
}
