import Foundation
import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import App

private func path(of icon: String) -> String {
    BuiltinIcons.artwork(for: icon)?.path ?? "<no artwork for \(icon)>"
}

private func occurrences(of needle: String, in text: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

private func icon(in svg: String, filledWith hex: String) -> Bool {
    svg.range(of: #"<use[^>]*fill="\#(hex)""#, options: .regularExpression) != nil
}

@Suite("Rendered node type badges")
struct NodeTypeBadgeRenderTests {

    private let question = """
        vgraph g: IBIS "T" {
            node q1: Question "Why?";
        }
        """

    private func render(_ vgl: String, darkMode: Bool = false) throws -> String {
        try VGraphTestApp().renderGraph(vgl, darkMode: darkMode).svg
    }

    @Test("Given a node with a node type badge, when rendered, then its icon is drawn from a symbol and no text is written for it")
    func theIconIsDrawnNotTyped() throws {
        let svg = try render(question)

        #expect(svg.contains(path(of: "question")))
        #expect(!svg.contains(">?</text>"))
    }

    @Test("Given nodes of type need, answer and undesirable-effect, when rendered, then the shared artwork is written once")
    func aSharedArtworkIsWrittenOnce() throws {
        let vgl = """
            vnotation Shared {
                node type: Need   [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "need"]
                node type: Answer [nodeStyle: iconWithText, backgroundColor: "#339933", icon: "answer"]
                node type: Ude    [nodeStyle: iconWithText, backgroundColor: "#3366cc", icon: "undesirable-effect"]
                edge type: rel from: Need to: Answer
            }

            vgraph s: Shared "S" {
                node a: Need "A";
                node b: Answer "B";
                node c: Ude "C";
            }
            """
        let svg = try render(vgl)

        #expect(occurrences(of: path(of: "need"), in: svg) == 1)
    }

    @Test("Given a node type badge, when rendered in light mode, then the icon is white")
    func theIconIsWhiteInLightMode() throws {
        #expect(icon(in: try render(question), filledWith: "#ffffff"))
    }

    @Test("Given a node type badge, when rendered in dark mode, then the icon is the dark --badge-icon colour")
    func theIconIsNearBlackInDarkMode() throws {
        #expect(icon(in: try render(question, darkMode: true), filledWith: "#14120f"))
    }

    @Test("Given a node type badge naming an icon nobody has, when rendered, then the placeholder is drawn and the diagram survives")
    func anUnknownIconDrawsThePlaceholder() throws {
        let app = VGraphTestApp()
        var graph = try app.parseGraph(question)
        let badge = NodeStyleLayout.iconAccentStrip(
            backgroundColor: .literal(lightHex: "#eeeeee"), borderColor: .literal(lightHex: "#336699"),
            textColor: .literal(lightHex: "#222222"), icon: "no.such.icon", typeName: "Question")
        graph = try graph.set(node: Node(string: "q1"), attribute: Attributes.Node.style.attribute(badge))

        let svg = try app.renderGraph(graph: graph, sourceVGL: "").svg

        #expect(svg.contains(IconArtwork.missing.path))
        #expect(svg.contains("Why?"))
    }

    @Test("Given a Concept Map concept, when rendered, then a node type badge reading CONCEPT with the dot icon is drawn")
    func aConceptWearsABadge() throws {
        let svg = try render(
            """
            vgraph c: ConceptMap "T" {
                node c1: Concept "Idea";
            }
            """)

        #expect(svg.contains(path(of: "concept")))
        #expect(svg.contains(">CONCEPT</text>"))
    }

    @Test("Given a Causal Loop Diagram stock, the only node type of its notation, when rendered, then no node type badge is drawn")
    func aSingleTypeNotationDrawsNoBadge() throws {
        let svg = try render(
            """
            vgraph c: CLD "T" {
                node a: Stock "Births";
                node b: Stock "Population";
                edge a -> b: same;
            }
            """)

        #expect(svg.contains("Births"))
        #expect(!svg.contains(path(of: "variable")))
        #expect(!svg.contains(">STOCK</text>"))
        #expect(!svg.contains(">VARIABLE</text>"))
    }

    @Test("Given a graph without node type badges or Arithmetic nodes, when rendered, then no badge icon symbols are written")
    func noBadgesMeansNoBadgeSymbols() throws {
        let svg = try render(
            """
            vgraph c: C4 "T" {
                node s: SoftwareSystem "S";
            }
            """)

        let written = ApprovedIcons.names.filter { svg.contains(path(of: $0)) }
        #expect(written.isEmpty, "symbols written for \(written.sorted())")
    }
}
