// An icon name that resolves to nothing used to be `VError.iconNotFound` and no
// SVG at all: one mistyped name cost the whole diagram (ADR-0022).

import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import App

@Suite("An icon name nobody has")
struct MissingIconTests {

    @Test("A document naming one still renders, whole")
    func aDocumentWithAnUnknownIconStillRenders() throws {
        let vgl = """
            vnotation RiskMap {
                node type: Risk [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "no.such.mark"]
                edge type: rel from: Risk to: Risk
            }

            vgraph rm: RiskMap "Risks" {
                node r1: Risk "Schedule overrun";
                node r2: Risk "Budget overrun";
                edge r1 -> r2;
            }
            """

        let app = VGraphTestApp()
        let svg = try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg

        #expect(svg.contains("Schedule overrun"), "the diagram survives its missing icon")
        #expect(svg.contains("Budget overrun"))
        #expect(svg.contains("icon-no.such.mark"))
    }

    /// The guide's own worked example declares every icon it draws. This is the
    /// copy that keeps the printed one honest.
    @Test("The RiskMap example from VGL_GUIDE.md renders")
    func theGuidesOwnExampleRenders() throws {
        let shieldPath = "M12 1 3 5v6c0 5.5 3.8 10.7 9 12 5.2-1.3 9-6.5 9-12V5z"
        let vgl = """
            vnotation RiskMap {
                layout: topToBottom

                icon risk   [viewBox: "0 0 24 24", path: "M12 2 22.5 21h-21zM11 9v6h2V9zm0 8v2h2v-2z"]
                icon shield [viewBox: "0 0 24 24", path: "\(shieldPath)"]

                node type: Risk    [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "risk"]
                node type: Control [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "shield"]
                node type: Owner   [nodeStyle: circle,       backgroundColor: "#3366cc"]

                edge type: risk_has_control  from: Risk    to: Control
                edge type: control_owned_by  from: Control to: Owner
            }

            vgraph rm1: RiskMap "Project Risk Map" {
                node r1: Risk    "Schedule overrun"
                node c1: Control "Weekly reviews"
                node o1: Owner   "PM"
                edge r1 -> c1
                edge c1 -> o1
            }
            """

        let app = VGraphTestApp()
        let svg = try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg

        #expect(svg.contains("Weekly reviews"))
        #expect(svg.contains(shieldPath), "the icon the guide declares is the icon it draws")
    }

    @Test("The missing placeholder is not an icon a document can ask for")
    func theMissingPlaceholderIsUnreachableByName() {
        for name in BuiltinIcons.names {
            #expect(BuiltinIcons.artwork(for: name) != IconArtwork.missing)
        }
    }

    @Test("Given a vnotation node type naming lightbulb.fill, when the document is rendered, then the node draws the missing-icon placeholder")
    func aMarkVGraphNoLongerShipsDrawsThePlaceholder() throws {
        let vgl = """
            vnotation Ideas {
                node type: Idea [nodeStyle: iconWithText, backgroundColor: "#f0c040", icon: "lightbulb.fill"]
                edge type: rel from: Idea to: Idea
            }

            vgraph i: Ideas "Ideas" {
                node i1: Idea "Ship it";
            }
            """

        let app = VGraphTestApp()
        let svg = try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg
        #expect(svg.contains(IconArtwork.missing.path))
    }
}

@Suite("Artwork the graph carries")
struct DeclaredArtworkRenderTests {

    private static let flame = IconArtwork(
        width: 24, height: 24, path: "M12 2c0.5,3.5 -4,5 -4,9 a4,4 0 0 0 8,0 c0,-2 -2,-4 -4,-7z")

    /// A style that draws an icon by name.
    private func markedGraph() throws -> VGraph {
        let vgl = """
            vnotation Marked {
                node type: Thing [nodeStyle: iconWithText, backgroundColor: "#b0d5f8", icon: "default"]
                edge type: rel from: Thing to: Thing
            }

            vgraph t: Marked "T" {
                node a: Thing "A";
            }
            """
        return try VGraphTestApp().parseGraph(vgl)
    }

    @Test("The defs draw what the graph declared, not the built-in of that name")
    func declaredArtworkReachesTheDefs() throws {
        let graph = try markedGraph().add(icon: "default", artwork: Self.flame)
        let svg = try VGraphTestApp().renderGraph(graph: graph, sourceVGL: "").svg

        #expect(svg.contains(Self.flame.path))
        #expect(!svg.contains(BuiltinIcons.artwork(for: "default")!.path))
    }

    @Test("A graph declaring nothing still draws the built-ins")
    func builtInsStillDraw() throws {
        let graph = try markedGraph()
        let svg = try VGraphTestApp().renderGraph(graph: graph, sourceVGL: "").svg

        #expect(svg.contains(BuiltinIcons.artwork(for: "default")!.path))
    }
}
