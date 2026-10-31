// `StyleFactories.makeIcon` supplies a default icon name when a `vnotation`
// declares an icon-bearing `nodeStyle` without naming one. Naming nothing means
// the author did not choose, so the default has to be a mark VGraph really has
// — a name nobody has is a different state, and draws the missing-icon placeholder.

import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import App

@Suite("A vnotation icon style with no icon named")
struct VNotationIconDefaultTests {

    private static let iconStyles = ["iconWithText", "withCategoryAndIcon", "iconOnly"]

    @Test(arguments: iconStyles)
    func rendersWithoutNamingAnIcon(_ nodeStyle: String) throws {
        let vgl = """
            vnotation Custom {
                node type: Thing [nodeStyle: \(nodeStyle), backgroundColor: "#b0d5f8"]
                edge type: rel from: Thing to: Thing
            }

            vgraph t: Custom "T" {
                node a: Thing "A";
                node b: Thing "B";
                edge a -> b;
            }
            """

        let app = VGraphTestApp()
        let svg = try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg
        #expect(!svg.isEmpty)
    }

    @Test("The default icon names a symbol the renderer has")
    func theDefaultIconResolves() {
        let icon = StyleFactories.makeIcon(from: [:], defaultIconColorHex: "#ffffff")
        #expect(BuiltinIcons.artwork(for: icon.iconName) != nil)
    }

    @Test("Given a vnotation node type with an icon style and no icon, when the document is rendered, then the node draws the fallback seal")
    func theNodeDrawsTheFallbackSeal() throws {
        let vgl = """
            vnotation Custom {
                node type: Thing [nodeStyle: iconOnly, backgroundColor: "#b0d5f8"]
                edge type: rel from: Thing to: Thing
            }

            vgraph t: Custom "T" {
                node a: Thing "A";
            }
            """

        let app = VGraphTestApp()
        let svg = try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg
        #expect(svg.contains(##"href="#icon-default""##))
    }
}
