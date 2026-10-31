import TestSupport
import Testing
import VGraph

@testable import App

/// ADR-0032: folded, a detailed node is the node it was, so it draws as a node of
/// its type, with the type's current look.
@Suite("A folded detailed node draws as its node type")
struct FoldedDetailedNodeLookTests {
    private let app = VGraphTestApp()

    /// A plain node and a folded detailed node of the same type and label.
    private func banking(_ type: String) -> String {
        """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            node twin: \(type) "Internet Banking System";
            group ibs: \(type) "Internet Banking System" {
                node web: Container "Webapp";
            }
            edge customer -> web;
        }
        """
    }

    /// What an element draws, without where: the content of its positioning `<g>`.
    private func drawing(of id: String, in svg: String) throws -> Substring {
        let start = try #require(svg.range(of: "<g id=\"\(id)\""))
        let rest = svg[start.upperBound...]
        let transform = try #require(rest.range(of: "<g transform="))
        let open = try #require(rest[transform.upperBound...].range(of: ">"))
        let close = try #require(rest[open.upperBound...].range(of: "</g></g>"))
        return rest[open.upperBound..<close.lowerBound]
    }

    @Test(
        "Given a folded SoftwareSystem or Container detailed node, when rendered, then it is drawn exactly as a node of its type",
        arguments: ["SoftwareSystem", "Container"])
    func drawnAsItsType(type: String) throws {
        let svg = try app.renderGraph(banking(type)).svg

        #expect(try drawing(of: "group-ibs", in: svg) == drawing(of: "node-twin", in: svg))
    }

    @Test("Given a folded Database detailed node, when rendered, then it is drawn as a Database cylinder")
    func databaseIsACylinder() throws {
        let svg = try app.renderGraph(banking("Database")).svg
        let drawn = try drawing(of: "group-ibs", in: svg)

        #expect(drawn == (try drawing(of: "node-twin", in: svg)))
        #expect(drawn.contains("<ellipse") || drawn.contains("<path"))
    }

    /// C4's cards are preset layouts, which a type-level colour does not recolour
    /// for any node, so the vnotation gives the type a style that takes one.
    @Test("Given a vnotation recolouring SoftwareSystem, when rendered, then the folded detailed node takes the new colour")
    func takesTheTypesCurrentLook() throws {
        let source = """
            vnotation Bank extends C4 {
                node type: SoftwareSystem [nodeStyle: simpleRoundedBox, backgroundColor: "#aa0000"]
            }

            """ + banking("SoftwareSystem").replacingOccurrences(of: ": C4 ", with: ": Bank ")

        let svg = try app.renderGraph(source).svg
        let drawn = try drawing(of: "group-ibs", in: svg)

        #expect(drawn.contains("fill=\"#aa0000\""))
        #expect(!drawn.contains("#1168bd"))
        #expect(drawn == (try drawing(of: "node-twin", in: svg)))
    }

    @Test("Given a detailed node with its own colour, when folded, then its own colour beats the type's")
    func ownValuesBeatTheType() throws {
        let source = banking("SoftwareSystem")
            .replacingOccurrences(of: "node web:", with: "backgroundcolor: \"#00aa00\";\n node web:")

        let drawn = try drawing(of: "group-ibs", in: app.renderGraph(source).svg)

        #expect(drawn.contains("fill=\"#00aa00\""))
    }

    @Test("Given a view colouring a detailed node, when that view is rendered, then the folded node takes the view's colour")
    func viewValuesReachTheFoldedNode() throws {
        let source = banking("SoftwareSystem") + "\nvview context {\n group ibs [backgroundcolor: \"#0000aa\"];\n}\n"

        let drawn = try drawing(of: "group-ibs", in: app.renderGraph(source, view: "context").svg)

        #expect(drawn.contains("fill=\"#0000aa\""))
    }

    @Test("Given a folded detailed node, when rendered, then its box is stamped and hovered as a folded group")
    func identifiedAsAFoldedGroup() throws {
        let svg = try app.renderGraph(banking("SoftwareSystem")).svg

        #expect(svg.contains("id=\"group-ibs\" class=\"vgraph-node vgraph-folded-group\""))
        #expect(!svg.contains("node-ibs"))
        #expect(svg.contains("svg:has(#group-ibs:hover) #node-customer"))
        #expect(svg.contains("svg:has(#node-customer:hover)") && svg.contains("#group-ibs{"))
    }

    @Test("Given two edges into a folded detailed node, when rendered, then they are drawn as one bundle that unfolds it")
    func edgesBundleIntoIt() throws {
        let source = banking("SoftwareSystem")
            .replacingOccurrences(of: "node web:", with: "node api: Container \"Gateway\";\n node web:")
            .replacingOccurrences(of: "edge customer -> web;", with: "edge customer -> web;\n edge customer -> api;")

        let svg = try app.renderGraph(source).svg

        #expect(svg.contains("class=\"vgraph-edge vgraph-edge-bundle\" data-unfolds=\"ibs\""))
        #expect(svg.contains(">×2<"))
    }

    /// A drop needs a node under the pointer (ADR-0021), and the box is a group.
    @Test("Given an edge into a folded detailed node, when rendered for editing, then only its other end has a reattach handle")
    func noReattachHandleOnTheBox() throws {
        let source = banking("SoftwareSystem")
        let graph = try app.parseGraph(source)

        let svg = try app.renderGraph(graph: graph, sourceVGL: source, interactive: true).svg

        #expect(svg.contains("data-end=\"from\""))
        #expect(!svg.contains("data-end=\"to\""))
    }

    /// The editor marks a folded detailed node as having details. The
    /// mark is the editor's, so the SVG it saves draws the box as any other node.
    @Test("Given a folded detailed node, when rendered for editing, then the SVG carries no details marker")
    func noDetailsMarkerInTheSVG() throws {
        let source = banking("SoftwareSystem")
        let graph = try app.parseGraph(source)

        let svg = try app.renderGraph(graph: graph, sourceVGL: source, interactive: true).svg

        #expect(!svg.contains("vg-details-marker"))
        #expect(try drawing(of: "group-ibs", in: svg) == drawing(of: "node-twin", in: svg))
    }
}
