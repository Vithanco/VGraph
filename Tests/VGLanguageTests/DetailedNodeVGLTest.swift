import Testing

@testable import VGLanguage
@testable import VGraph

/// ADR-0032: `group x: T` is a detailed node when T is a node type, a plain
/// group when T is a group type.
@Suite("Detailed node in VGL")
struct DetailedNodeVGLTest {

    private static let source = """
        vgraph arch: C4 "Architecture" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node web: Container "Web App";
            };
            folded group mainframe: SoftwareSystem "Mainframe" {
                node core: Container "Core";
            };
            edge customer -> web "uses";
        }
        """

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func group(_ id: String, in graph: VGraph) throws -> Group {
        try #require(graph.groups.first { $0.id.id == id })
    }

    @Test func aGroupTypedAsANodeTypeIsADetailedNode() throws {
        let graph = try parse(Self.source)
        let ibs = try group("ibs", in: graph)

        #expect(graph.nodeType(of: ibs) == Notations.C4.NodeTypes.softwareSystem)
        #expect(graph.groupType(of: ibs) == nil)
    }

    @Test func aDetailedNodeExportsWithItsNodeType() throws {
        let exported = try VGLExporter().export(graph: parse(Self.source))

        #expect(exported.contains("\tgroup ibs: SoftwareSystem \"Internet Banking System\" {"))
    }

    /// A detailed node starts folded (ADR-0032), so `folded` repeats its type and
    /// is dropped, while an unfolded one says so.
    @Test func aDetailedNodeWritesOnlyAnUnfolding() throws {
        let unfolded = Self.source.replacingOccurrences(of: "node web:", with: "isfolded: false;\n node web:")
        let exported = try VGLExporter().export(graph: parse(unfolded))

        #expect(exported.contains("\tgroup mainframe: SoftwareSystem \"Mainframe\" {"))
        #expect(exported.contains("\t\tisfolded: false\n"))
        #expect(try VGLExporter().export(graph: parse(exported)) == exported)
    }

    @Test func aDetailedNodeRoundTrips() throws {
        let first = try VGLExporter().export(graph: parse(Self.source))
        let reparsed = try parse(first)

        #expect(try VGLExporter().export(graph: reparsed) == first)
        #expect(reparsed.nodeType(of: try group("ibs", in: reparsed)) == Notations.C4.NodeTypes.softwareSystem)
    }

    /// A ⌥ retype can give a group a node type that is detailed by nothing.
    @Test func aDetailedNodeWhoseTypeHasNoDetailingStillLoads() throws {
        let graph = try parse(
            """
            vgraph arch: C4 "Architecture" {
                group p: Person "Customer" {
                    node web: Container "Web App";
                };
            }
            """)

        #expect(graph.nodeType(of: try group("p", in: graph)) == Notations.C4.NodeTypes.person)
    }

    @Test func aNodeTypeInTheGroupSlotIsNotColouredAsAnError() {
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: Self.source)

        #expect(html.contains(">SoftwareSystem</span>"))
        #expect(!html.contains("vg-error\">SoftwareSystem</span>"))
    }
}
