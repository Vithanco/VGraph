import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

/// `detailedBy:` in a `vnotation` (ADR-0032).
@Suite("Detailings in a vnotation")
struct VNotationDetailingTests {
    static let source = """
        vnotation Arch {
        	node type: System [nodeStyle: withCategory, backgroundColor: "#1168bd", detailedBy: (Container, Database)]
        	node type: Container [nodeStyle: withCategory, backgroundColor: "#438dd5"]
        	node type: Database [nodeStyle: withCategory, backgroundColor: "#438dd5"]
        }

        vgraph g: Arch "G" {
        	node s: System "S"
        }
        """

    let system = NodeType(string: "System")

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    @Test("Given detailedBy: in a vnotation, when parsed, then the graph answers the detail types")
    func detailedByParses() throws {
        let graph = try parse(Self.source)
        #expect(graph.detailTypes(of: system) == [NodeType(string: "Container"), NodeType(string: "Database")])
    }

    @Test("Given detailedBy: in a vnotation, when highlighted, then the listed names are node types")
    func detailedByNamesAreHighlightedAsNodeTypes() throws {
        let html = VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: Self.source)
        let detailedBy = try #require(html.range(of: "detailedBy"))
        let rest = String(html[detailedBy.upperBound...])
        #expect(rest.hasPrefix("</span><span class=\"vg-punct\">:</span> <span class=\"vg-punct\">(</span><span class=\"vg-type\">Container</span>"))
    }

    @Test("Given detailedBy: naming an undeclared type, when parsed, then it is refused")
    func detailedByMustNameDeclaredTypes() {
        let source = Self.source.replacingOccurrences(of: "(Container, Database)", with: "(Container, Datbase)")
        #expect(throws: VError.detailingNamesUnknownType(of: system, unknown: NodeType(string: "Datbase"))) {
            try parse(source)
        }
    }

    @Test("Given detailedBy: on an edge type, when parsed, then it is refused")
    func detailedByBelongsOnANodeType() {
        let source = Self.source.replacingOccurrences(
            of: "}\n\nvgraph", with: "\tedge type: holds from: System to: Container [detailedBy: (Database)]\n}\n\nvgraph")
        let error = #expect(throws: VError.self) { try parse(source) }
        #expect(error?.description.contains("'detailedBy:' belongs on a node type") == true)
    }

    @Test("Given detailedBy: in a vnotation, when exported and reparsed, then the detailings are kept")
    func detailedByRoundTrips() throws {
        let exported = try VGLExporter().export(graph: parse(Self.source))
        #expect(exported.contains("detailedBy: (Container, Database)"))
        #expect(try parse(exported).detailTypes(of: system) == [NodeType(string: "Container"), NodeType(string: "Database")])
    }

    @Test("Given a vnotation adding to a built-in's detailings, when exported, then only its own are written")
    func onlyTheVnotationsOwnDetailingsAreExported() throws {
        let vnotation = DynamicNotation(
            id: .init(rawValue: "Mine"),
            nodeTypeSpecs: [NodeTypeSpec(name: "System", nodeStyle: nil, rawAttrs: [:], detailedBy: ["Database"])],
            edgeTypeSpecs: [], graphAttrs: [], baseEntry: Layered.entry)
        let graph = try vnotation.addNotation(addTo: VGraph().defineStandardAttributes()).using(notation: "Mine")
        #expect(graph.detailTypes(of: system) == [NodeType(string: "Container"), NodeType(string: "Database")])

        let exported = try VGLExporter().export(graph: graph)
        #expect(exported.contains("detailedBy: (Database)"), "\(exported)")
        #expect(!exported.contains("Container)"), "\(exported)")
    }
}

/// A built-in notation that details System by Container.
private enum Layered: NotationDeclaration {
    static let id: Identifier<Notation> = .init(rawValue: "Layered")

    struct NodeTypes: NotationNodeTypes {
        static let system = NodeType(string: "System")
        static let container = NodeType(string: "Container")
        static let database = NodeType(string: "Database")
        static var all: [NodeType] { [system, container, database] }
        static var allDefinitions: [NodeTypeDefinition] {
            [
                NodeTypeDefinition(system, description: "", detailedBy: [container]),
                NodeTypeDefinition(container, description: ""),
                NodeTypeDefinition(database, description: ""),
            ]
        }
    }

    struct EdgeTypes: NotationEdgeTypes {
        static var all: [EdgeType] { [] }
    }
}
