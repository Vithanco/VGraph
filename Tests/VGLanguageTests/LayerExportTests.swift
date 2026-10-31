import Testing

@testable import VGLanguage
@testable import VGraph

/// The exporter writes the layers the author wrote: the `vnotation` layer into
/// the `vnotation` block, the model into the `vgraph` block (ADR-0030).
@Suite("Export writes the layers")
struct LayerExportTests {
    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func block(_ keyword: String, in exported: String) -> String {
        guard let start = exported.range(of: keyword) else { return "" }
        let rest = exported[start.lowerBound...]
        guard let end = rest.range(of: "\n}\n") else { return String(rest) }
        return String(rest[..<end.upperBound])
    }

    @Test("Given values in both a vnotation and its vgraph, when exported, then each stays in its own block")
    func valuesStayInTheBlockTheyWereWrittenIn() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                """
                vnotation Mine extends IBIS {
                    layout: leftToRight
                    node type: Extra [nodeStyle: withCategory, backgroundColor: "#884499", category: "E"]
                }

                vgraph g: Mine "G" {
                    splines: ortho
                    node q: Question "Q"
                }
                """))
        let vnotation = block("vnotation Mine", in: exported)
        let vgraph = block("vgraph g", in: exported)
        #expect(vnotation.contains("layout: leftToRight"))
        #expect(!vnotation.contains("splines"))
        #expect(vgraph.contains("splines: ortho"))
        #expect(!vgraph.contains("layoutdirection"))
    }

    private func teamsWithFoldedTeam(_ group: String) throws -> VGraph {
        let parsed = try parse(
            """
            vnotation Teams {
                node type: Member [nodeStyle: roundedBox]
                group type: Team
            }

            vgraph g: Teams "G" {
                \(group) b: Team "B" {
                    node p: Member "P";
                };
            }
            """)
        return try parsed.placing(
            NotationContent(values: [.groupType(GroupType(string: "Team"), [Attributes.Group.isFolded(true)])]),
            in: .builtin)
    }

    @Test("Given a group type that starts folded, when its group is exported, then it is not written as folded")
    func aTypesFoldingIsNotTheGroups() throws {
        let exported = try VGLExporter().export(graph: teamsWithFoldedTeam("group"))
        #expect(!exported.contains("folded group"))
        #expect(!exported.contains("isfolded"))
    }

    @Test("Given a group unfolded against its folded type, when exported, then the unfolding is written")
    func anUnfoldingIsWritten() throws {
        let unfolded = try teamsWithFoldedTeam("group")
            .set(group: Group(rawValue: "b"), attribute: Attributes.Group.isFolded.attribute(false))
        #expect(try VGLExporter().export(graph: unfolded).contains("isfolded: false"))
    }
}

/// What sets layer export apart from diffing against a rebuilt notation: a
/// value in the built-in layer that a fresh copy of the notation would not
/// have is the notation's, never the document's.
@Suite("The exporter reads the layers, not a rebuilt notation")
struct ExportReadsLayersTests {
    private let source = """
        vnotation Mine extends IBIS {
            node type: Extra [nodeStyle: withCategory, backgroundColor: "#884499", category: "E"]
        }

        vgraph g: Mine "G" {
            node q: Question "Q"
        }
        """

    private func parse() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test("Given a built-in type value no rebuilt notation has, when exported, then the vnotation does not claim it")
    func aBuiltInTypeValueIsNotTheVNotations() throws {
        let changed = try parse().placing(
            NotationContent(values: [.nodeType(NodeType("Question"), [Attributes.Node.fontsize(30)])]), in: .builtin)
        let exported = try VGLExporter().export(graph: changed)
        #expect(!exported.contains("node type: Question"))
    }

    @Test("Given a built-in diagram value no rebuilt notation has, when exported, then the vgraph block does not claim it")
    func aBuiltInRootValueIsNotTheModels() throws {
        let changed = try parse().placing(
            NotationContent(values: [.diagram([Attributes.Group.splines("ortho")])]), in: .builtin)
        #expect(!(try VGLExporter().export(graph: changed)).contains("splines"))
    }

    @Test("Given a vnotation value on a built-in type, when exported, then it is written as that type's override")
    func aVNotationOverrideIsWritten() throws {
        let changed = try parse().placing(
            NotationContent(values: [.nodeType(NodeType("Question"), [Attributes.Node.fontsize(30)])]), in: .vnotation)
        #expect(try VGLExporter().export(graph: changed).contains("node type: Question [fontsize: 30]"))
    }
}
