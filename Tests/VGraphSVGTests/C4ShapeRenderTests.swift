import Testing

@testable import VGraph
@testable import VGraphSVG

@Suite
struct C4ShapeRenderTests {

    private func renderBackground(shape: NodeShape) throws -> String {
        let style = NodeStyleLayout.background(.appearance(shape: shape, color: .literal(VColor.blue)), .empty)
        let bounds = VRect(origin: VPoint(x: 0, y: 0), size: VSize(width: 120, height: 80))
        return try VSVGNodeLayout.render(
            style: style, wrappedText: [], bounds: bounds, font: VFont(size: 14), darkMode: false
        ).render()
    }

    @Test("Given a Database node, when rendered to SVG, then it is drawn as a cylinder outline rather than a plain rectangle")
    func cylinderRendersAsCylinder() throws {
        let svg = try renderBackground(shape: .cylinder)
        #expect(svg.contains("<ellipse") || svg.contains("<path"))
    }

    @Test("Given a Person node, when rendered to SVG, then it is drawn with a person outline rather than a plain rectangle")
    func personRendersWithHead() throws {
        let svg = try renderBackground(shape: .person)
        #expect(svg.contains("<circle") || svg.contains("<path"))
    }
}
