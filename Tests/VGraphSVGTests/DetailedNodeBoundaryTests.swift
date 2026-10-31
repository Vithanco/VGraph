import TestSupport
import Testing
import VGraph

@testable import App

/// ADR-0032: a detailed node starts folded, and unfolded it draws the boundary
/// its node type declares.
@Suite("Detailed node: fold default and boundary")
struct DetailedNodeBoundaryTests {
    private let app = VGraphTestApp()

    private let banking = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node web: Container "Webapp";
                node api: Container "Gateway";
            }
            edge customer -> web;
            edge web -> api;
        }
        """

    @Test("Given a detailed node with no fold setting, when rendered, then it is drawn folded")
    func startsFolded() throws {
        let svg = try app.renderGraph(banking).svg

        #expect(svg.contains("id=\"group-ibs\" class=\"vgraph-node vgraph-folded-group\""))
        #expect(!svg.contains("id=\"node-web\""))
    }

    @Test("Given a view with isfolded: false on a detailed node, when that view is rendered, then it is unfolded")
    func aViewUnfoldsIt() throws {
        let source = banking + "\nvview containers {\n group ibs [isfolded: false];\n}\n"

        let svg = try app.renderGraph(source, view: "containers").svg

        #expect(svg.contains("id=\"group-ibs\" class=\"vgraph-group depth-0\""))
        #expect(svg.contains("id=\"node-web\""))
    }

    @Test("Given a view unfolding a detailed node, when another view is rendered, then it is still folded there")
    func otherViewsStayFolded() throws {
        let source = banking + "\nvview containers {\n group ibs [isfolded: false];\n}\n\nvview context {\n node customer [fontsize: 16];\n}\n"

        let svg = try app.renderGraph(source, view: "context").svg

        #expect(svg.contains("vgraph-folded-group"))
        #expect(!svg.contains("id=\"node-web\""))
    }

    @Test("Given isfolded: false on a detailed node in the model, when rendered, then it is unfolded")
    func theModelUnfoldsIt() throws {
        let source = banking.replacingOccurrences(of: "node web:", with: "isfolded: false;\n node web:")

        let svg = try app.renderGraph(source).svg

        #expect(svg.contains("id=\"node-web\""))
    }

    /// The boundary rectangle the SVG draws for a group, up to its closing tag.
    private func boundary(of group: String, in svg: String) -> Substring? {
        guard let start = svg.range(of: "id=\"group-\(group)\"") else { return nil }
        let rest = svg[start.upperBound...]
        guard let rect = rest.range(of: "<rect"), let end = rest[rect.lowerBound...].range(of: "/>") else { return nil }
        return rest[rect.lowerBound..<end.upperBound]
    }

    @Test("Given an unfolded SoftwareSystem detailed node, when rendered, then its boundary is the C4 boundary its type declares")
    func boundaryComesFromTheNodeType() throws {
        let source = banking + "\nvview containers {\n group ibs [isfolded: false];\n}\n"

        let rect = try #require(boundary(of: "ibs", in: try app.renderGraph(source, view: "containers").svg))

        #expect(rect.contains("stroke-dasharray=\"8,4\""))
        #expect(rect.contains("stroke=\"#7a7a7a\""))
    }

    private let containers = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                isfolded: false;
                node twin: Container "API Application";
                group api: Container "API Application" {
                    node signIn: Component "Sign In";
                }
            }
            edge customer -> signIn;
            edge customer -> twin;
        }
        """

    @Test("Given an unfolded Container detailed node, when rendered, then its boundary is the C4 boundary")
    func anUnfoldedContainerIsABoundary() throws {
        let source = containers + "\nvview components {\n group api [isfolded: false];\n}\n"

        let rect = try #require(boundary(of: "api", in: try app.renderGraph(source, view: "components").svg))

        #expect(rect.contains("stroke-dasharray=\"8,4\""))
        #expect(rect.contains("stroke=\"#7a7a7a\""))
    }

    @Test("Given an Organisation group, when rendered, then it is a plain group with the C4 boundary")
    func anOrganisationIsAC4Boundary() throws {
        let source = banking.replacingOccurrences(
            of: "edge customer -> web;", with: "group bank: Organisation \"Big Bank\" {\n node clerk: Person \"Clerk\";\n}\nedge customer -> web;")

        let svg = try app.renderGraph(source).svg
        let rect = try #require(boundary(of: "bank", in: svg))

        #expect(svg.contains("id=\"group-bank\" class=\"vgraph-group depth-0\""))
        #expect(rect.contains("stroke-dasharray=\"8,4\""))
    }

    @Test("Given a plain group beside a detailed node, when rendered, then it keeps the generic cluster look")
    func plainGroupsKeepTheirLook() throws {
        let source = banking.replacingOccurrences(
            of: "edge customer -> web;", with: "group misc \"Misc\" {\n node bob: Person \"Bob\";\n}\nedge customer -> web;")

        let rect = try #require(boundary(of: "misc", in: try app.renderGraph(source).svg))

        #expect(rect.contains("stroke-dasharray=\"6,3\""))
    }
}
