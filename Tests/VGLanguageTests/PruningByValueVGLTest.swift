import Testing

@testable import VGLanguage
@testable import VGraph

/// ADR-0030: a value equal to what its chain resolves is pruned, however it is spelled.
@Suite("Pruning compares values, not spellings")
struct PruningByValueVGLTest {

    private static let source = """
        vnotation Bank extends C4 {
            node type: Person [fontsize: 20.0]
            node type: SoftwareSystem [fontsize: 20.0]
        }

        vgraph arch: Bank "Architecture" {
            node customer: Person "Customer" [fontsize: 20];
            group ibs: SoftwareSystem "Internet Banking System" {
                fontsize: 20
                node web: Container "Web App";
            }
        }
        """

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func modelBlock(_ exported: String) throws -> Substring {
        try #require(exported.range(of: "vgraph arch").map { exported[$0.lowerBound...] })
    }

    @Test func aNodeValueSpelledDifferentlyFromItsTypesIsNotWritten() throws {
        let exported = try VGLExporter().export(graph: parse(Self.source))

        #expect(!(try modelBlock(exported).contains("fontsize")), "\(exported)")
    }

    @Test func aNodeThatOnlyRepeatedItsTypeFollowsTheTypesChange() throws {
        let graph = try parse(Self.source)
            .set(nodeType: Notations.C4.NodeTypes.person, attribute: Attributes.Node.fontsize(30))
            .set(nodeType: Notations.C4.NodeTypes.softwareSystem, attribute: Attributes.Node.fontsize(30))

        #expect(try graph.get(node: Node(string: "customer"), attribute: Attributes.Node.fontsize) == 30)
        #expect(try graph.get(group: Group(rawValue: "ibs"), attribute: Attributes.Node.fontsize) == 30)
    }

    @Test func aViewValueSpelledDifferentlyFromTheModelsIsNotWritten() throws {
        let source = """
            vgraph arch: C4 "Architecture" {
                node customer: Person "Customer" [fontsize: 20.0];
            }

            vview v {
                node customer [fontsize: 20];
            }
            """
        let exported = try VGLExporter().export(graph: parse(source))

        #expect(!exported.contains("node customer [fontsize: 20]"), "\(exported)")
    }
}
