import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

@Suite("A vnotation declares group types")
struct VNotationGroupTypeTest {
    static let source = """
        vnotation Teams {
        	node type: Member [nodeStyle: roundedBox]
        	group type: Team
        	group type: Guild
        }

        vgraph org: Teams "Org" {
        	group core: Team "Core" {
        		node ann: Member "Ann"
        	}
        }
        """

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test("Given a vnotation declaring group types, when parsed, then the graph registers them in order")
    func registersThem() throws {
        #expect(try parse(Self.source).groupTypes.map { $0.description } == ["Team", "Guild"])
    }

    @Test("Given a group typed with a declared group type, when parsed, then it has that type")
    func typesTheGroup() throws {
        let graph = try parse(Self.source)
        #expect(graph.groupType(of: Group(rawValue: "core"))?.description == "Team")
    }

    @Test("Given a vnotation declaring a group type, when highlighted semantically, then its name is a type wherever it appears")
    func highlightedAsAType() {
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: Self.source)
        #expect(html.components(separatedBy: "<span class=\"vg-type\">Team</span>").count == 3)
        #expect(!html.contains("vg-error"))
    }

    @Test("Given a vnotation declaring group types, when exported and reparsed, then the export does not change")
    func exportIsStable() throws {
        let first = try VGLExporter().export(graph: parse(Self.source))
        #expect(first.contains("\tgroup type: Team\n\tgroup type: Guild\n"))
        #expect(try VGLExporter().export(graph: parse(first)) == first)
    }

    @Test("Given a vnotation extending a notation with group types, when exported, then only its own are written")
    func baseGroupTypesStayInTheBase() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation Mine extends C4 {
                	group type: Team
                }

                vgraph g: Mine "G" {
                	node p: Person "P"
                }
                """))
        let block = exported.split(separator: "\n").map { String($0) }.filter { $0.contains("group type:") }
        #expect(block == ["\tgroup type: Team"])
    }
}
