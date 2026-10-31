// Tests for a notation's self-description. `metadescription` in VGL draws the
// same structural diagram as `metagraph`; the Markdown document comes from
// `describeNotation`, which renders it from the notation itself rather than
// carrying it through the graph (ADR-0030: it is not an attribute).

import Foundation
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

/// No shipped notation declares detailings yet.
private enum Architecture: NotationDeclaration {
    static let id: Identifier<Notation> = .init(rawValue: "Architecture")
    static let system = NodeType(string: "System")
    static let container = NodeType(string: "Container")
    static let database = NodeType(string: "Database")

    struct NodeTypes: NotationNodeTypes {
        static var all: [NodeType] { [system, container, database] }
        static var allDefinitions: [NodeTypeDefinition] {
            [
                NodeTypeDefinition(system, description: "A whole system", detailedBy: [container, database]),
                NodeTypeDefinition(container, description: "Runs code", detailedBy: [container]),
                NodeTypeDefinition(database, description: "Stores data"),
            ]
        }
    }

    struct EdgeTypes: NotationEdgeTypes {
        static var all: [EdgeType] { [] }
    }
}

@Suite
struct MetadescriptionTest {
    let app = VGraphApplication(ports: ParseOnlyPorts(logger: NoOpLogger()))

    // MARK: - The diagram, and the document beside it

    @Test
    func ibisMetadescriptionBuildsTheMetagraph() throws {
        let source = "metadescription IBIS"
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        // Default label mirrors the metagraph naming convention so the diagram
        // portion of a metadescription reads naturally.
        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "IBIS Meta Model")

        let id: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(id == "IBIS")

        // Structural part: IBIS has 4 node types (Question, Answer, Pro, Con).
        let nodeIds = Set(graph.nodes.map { $0.id.description })
        #expect(nodeIds == ["_meta_Question", "_meta_Answer", "_meta_Pro", "_meta_Con"])
        #expect(graph.edges.count >= 4)
    }

    @Test
    func ibisDescriptionCoversEverySection() throws {
        let markdown = try #require(app.describeNotation("IBIS"))
        #expect(markdown.contains("# IBIS"))
        #expect(markdown.contains("## Purpose"))
        #expect(markdown.contains("## When to use"))
        #expect(markdown.contains("## Node types"))
        #expect(markdown.contains("## Edge types"))
        #expect(markdown.contains("## History"))
        #expect(markdown.contains("## References"))
        // Tagline from `Notations.Ibis.description` shows up as a blockquote.
        #expect(markdown.contains("> Models arguments and decisions"))
        // Every node type label appears in the node-type table.
        #expect(markdown.contains("| Question |"))
        #expect(markdown.contains("| Answer |"))
        #expect(markdown.contains("| Pro |"))
        #expect(markdown.contains("| Con |"))
        // Historical attribution is preserved.
        #expect(markdown.contains("Werner Kunz"))
        #expect(markdown.contains("Rittel"))
    }

    @Test
    func ibisMetadescriptionWithCustomTitle() throws {
        let source = #"metadescription IBIS "Why IBIS works""#
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "Why IBIS works")

        let markdown = try #require(app.describeNotation("IBIS", title: "Why IBIS works"))
        #expect(markdown.contains("# Why IBIS works"))
    }

    @Test
    func timelineDescriptionIsComplete() throws {
        let markdown = try #require(app.describeNotation("Timeline"))
        #expect(markdown.contains("# Timeline"))
        #expect(markdown.contains("## Node types"))
        #expect(markdown.contains("| TimePoint |"))
        #expect(markdown.contains("| Event |"))
        #expect(markdown.contains("## Purpose"))
        #expect(markdown.contains("## When to use"))
        #expect(markdown.contains("## History"))
        #expect(markdown.contains("## References"))
    }

    /// C4's levels are its detailings; a system or container boundary is a
    /// detailed node, so the only group type left is the organisation's.
    @Test
    func c4DescriptionNamesItsHierarchy() throws {
        let markdown = try #require(app.describeNotation("C4"))
        #expect(markdown.contains("| SoftwareSystem | Container, Database |"))
        #expect(markdown.contains("| Container | Component |"))
        #expect(markdown.contains("| Component | CodeElement |"))
        #expect(markdown.contains("## Group types"))
        #expect(markdown.contains("| Organisation |"))
        #expect(!markdown.contains("Boundary |"))
        #expect(!markdown.contains("External"))
    }

    @Test
    func c4DescriptionListsOneRelationshipPerLevel() throws {
        let markdown = try #require(app.describeNotation("C4"))
        let pairs = markdown.split(separator: "\n").filter { $0.contains(" → ") && $0.hasPrefix("| ") && !$0.contains("From → To") }
        #expect(
            pairs.map { $0.split(separator: "|")[0].trimmingCharacters(in: .whitespaces) } == [
                "Person → Person", "Person → SoftwareSystem", "SoftwareSystem → Person",
                "SoftwareSystem → SoftwareSystem", "Container → Container", "Container → Database",
                "Component → Component", "CodeElement → CodeElement",
            ])
    }

    @Test
    func ibisMetadescriptionHasNoGroupTypeSection() throws {
        let markdown = NotationMarkdown.render(entry: Notations.Ibis.entry)
        #expect(!markdown.contains("## Group types"))
    }

    @Test
    func aDescriptionListsEachTypesDetailTypes() {
        let markdown = NotationMarkdown.render(entry: Architecture.entry)
        #expect(markdown.contains("## Detailings"))
        #expect(markdown.contains("| System | Container, Database |"))
        #expect(markdown.contains("| Container | Container |"))
        #expect(!markdown.contains("| Database | |"))
        // An assistant reading only the names would not know how a detailed node is written.
        #expect(markdown.contains("`group <id>: <NodeType> \"<label>\" { … }`"))
    }

    @Test
    func aNotationWithoutDetailingsHasNoDetailingSection() {
        #expect(!NotationMarkdown.render(entry: Notations.Ibis.entry).contains("## Detailings"))
    }

    @Test
    func unknownNotationInMetadescription() throws {
        let source = "metadescription DoesNotExist"
        let logger = CapturingLogger()
        let parser = VGraphParser(logger: logger)
        _ = try parser.parse(source: source)
        #expect(logger.errors.contains(where: { $0.contains("DoesNotExist") }))
    }

    @Test
    func existingMetagraphStillWorks() throws {
        // Regression guard: factoring out `buildMetagraph` must not have broken
        // the plain `metagraph` path.
        let source = "metagraph IBIS"
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        #expect(graph.nodes.count == 4)
    }

    @Test
    func anUnknownNotationHasNoDescription() {
        #expect(app.describeNotation("DoesNotExist") == nil)
    }

    // MARK: - Direct NotationMarkdown.render() pathway

    @Test
    func directMarkdownRenderForIbis() throws {
        // Verify the pure rendering function is usable outside the parser,
        // so CLI/WASM/MCP surfaces can call it directly.
        let markdown = NotationMarkdown.render(entry: Notations.Ibis.entry)
        #expect(markdown.hasPrefix("# Ibis"))
        #expect(markdown.contains("Questions are the key driver of IBIS"))
        // Reference URLs are rendered as Markdown links.
        #expect(markdown.contains("(https://en.wikipedia.org/wiki/Issue-based_information_system)"))
    }

    @Test
    func directMarkdownRenderForNotationWithEmptyFields() throws {
        // Sanity: notations without self-description fields still produce a
        // valid Markdown document (only heading + tagline + tables).
        let markdown = NotationMarkdown.render(entry: Notations.Timeline.entry)
        #expect(markdown.hasPrefix("# Timeline"))
        #expect(markdown.contains("## Node types"))
        #expect(markdown.contains("| TimePoint |"))
    }
}
