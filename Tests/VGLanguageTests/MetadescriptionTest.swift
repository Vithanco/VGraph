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
    static let system = NodeType(rawValue: "System")
    static let container = NodeType(rawValue: "Container")
    static let database = NodeType(rawValue: "Database")

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

/// Nothing to check beyond what every notation runs.
private enum Plain: NotationDeclaration {
    static let id: Identifier<Notation> = .init(rawValue: "Plain")
    static let item = NodeType(rawValue: "Item")

    struct NodeTypes: NotationNodeTypes {
        static var all: [NodeType] { [item] }
        static var allDefinitions: [NodeTypeDefinition] { [NodeTypeDefinition(item, description: "A thing")] }
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

        let id: String = try graph.get(graphAttribute: Attributes.Group.id)
        #expect(id == "IBIS")

        // Structural part: IBIS has 4 node types (Question, Answer, Pro, Con).
        let nodeIds = Set(graph.nodes.map { $0.id.description })
        #expect(nodeIds == ["_meta_Question", "_meta_Answer", "_meta_Pro", "_meta_Con"])
        // One edge per IBIS edge type.
        #expect(graph.edges.count == 7)
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
        #expect(!markdown.contains("## Detailings"))
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

    // MARK: - What Vithanco checks

    @Test
    func aDescriptionListsTheRulesItChecks() {
        let markdown = NotationMarkdown.render(entry: Notations.Ibis.entry)
        #expect(
            markdown.contains(
                """
                ## What Vithanco checks

                - At most one edge joins two nodes in the same direction.
                - Every node has at most one parent.
                - Every Question has at least one Answer.

                """))
    }

    /// Detailings are rules too: a Database belongs inside a System only.
    @Test
    func aDescriptionListsWhereEachDetailTypeBelongs() {
        let markdown = NotationMarkdown.render(entry: Architecture.entry)
        #expect(markdown.contains("- A Container belongs inside a System or Container."))
        #expect(markdown.contains("- A Database belongs inside a System."))
    }

    /// The section is always there, so a page that shows it never looks forgotten.
    @Test
    func aNotationWithNoRulesOfItsOwnSaysSo() {
        let markdown = NotationMarkdown.render(entry: Plain.entry)
        #expect(markdown.contains("## What Vithanco checks\n\nOnly the checks every notation runs.\n"))
    }

    @Test
    func theChecksEveryNotationRunsAreDescribedOnce() {
        let markdown = app.describeCommonChecks()
        #expect(markdown.hasPrefix("# Checks every notation runs\n"))
        #expect(markdown.contains("## What Vithanco checks\n\n- "))
        #expect(markdown.contains("- Every node is connected to at least one other.\n"))
        #expect(markdown.contains("- A nested element sits inside a type that details it.\n"))
    }

    @Test
    func anUnknownNotationHasNoDescription() {
        #expect(app.describeNotation("DoesNotExist") == nil)
    }

    // MARK: - A vnotation, described by the document that declares it

    static let flow = """
        vnotation Flow {
        	node type: Goal [nodeStyle: roundedBox]
        	node type: Step [nodeStyle: roundedBox, detailedBy: (Task)]
        	node type: Task [nodeStyle: roundedBox]
        	edge type: next  from: Step  to: Step [outDegreeMax: 1]
        	qualityCheck: treeStructure
        	qualityCheck: exactlyOne(Goal)
        }

        vgraph g: Flow "G" {
        	node a: Step "A"
        }
        """

    @Test
    func aVNotationListsTheRulesItChecks() throws {
        let markdown = try app.describeNotation(in: Self.flow)
        #expect(markdown.hasPrefix("# Flow\n"))
        #expect(
            markdown.contains(
                """
                ## What Vithanco checks

                - Every node has at most one parent.
                - A diagram has exactly one Goal.
                - A Task belongs inside a Step.
                - A Step has at most 1 outgoing "next" edge.

                """))
    }

    @Test
    func aVNotationsTitleCanBeReplaced() throws {
        let markdown = try app.describeNotation(in: Self.flow, title: "How we plan")
        #expect(markdown.hasPrefix("# How we plan\n"))
    }

    /// The checks a `vnotation` names replace its base's, so the base's own are not listed.
    @Test
    func aVNotationListsOnlyTheChecksInForce() throws {
        let source = """
            vnotation Mine extends IBIS {
            	qualityCheck: labelLength(5)
            }

            vgraph g: Mine "G" {
            	node q: Question "Q"
            }
            """
        let markdown = try app.describeNotation(in: source)
        #expect(markdown.contains("- Every node's label has at most 5 words.\n"))
        #expect(!markdown.contains("Every Question has at least one Answer."))
    }

    @Test
    func aVNotationWithNoRulesOfItsOwnSaysSo() throws {
        let source = """
            vnotation Bare {
            	node type: Item [nodeStyle: roundedBox]
            }

            vgraph g: Bare "G" {
            	node i: Item "I"
            }
            """
        let markdown = try app.describeNotation(in: source)
        #expect(markdown.contains("## What Vithanco checks\n\nOnly the checks every notation runs.\n"))
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
    func aNotationWithoutSelfDescriptionStillRenders() throws {
        // Only heading and tables: no purpose, usage, history or references to show.
        let markdown = NotationMarkdown.render(entry: Architecture.entry)
        #expect(markdown.hasPrefix("# Architecture"))
        #expect(markdown.contains("## Node types"))
        #expect(markdown.contains("| System |"))
        for section in ["## Purpose", "## When to use", "## History", "## References"] {
            #expect(!markdown.contains(section), "\(section) has nothing to say")
        }
    }
}
