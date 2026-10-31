// Tests for the `metagraph` keyword, which renders the structure of a
// notation (its NodeTypes and EdgeTypes) as a diagram.

import Foundation
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

@Suite
struct MetagraphTest {

    @Test
    func timelineMetagraph() throws {
        let source = "metagraph Timeline"
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        // Default label: "<NotationName> Meta Model"
        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "Timeline Meta Model")

        let id: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(id == "Timeline")

        // Timeline has 2 NodeTypes (TimePoint, Event) and 2 EdgeTypes (sequence, influence).
        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 2)

        // Each actual node is typed with the matching NodeType and carries the type id as label.
        // Node IDs are prefixed with `_meta_` to avoid colliding with the NodeType IDs in
        // the shared attribute keyspace.
        let nodeIds = Set(graph.nodes.map { $0.id.description })
        #expect(nodeIds == ["_meta_TimePoint", "_meta_Event"])

        for node in graph.nodes {
            let nt = try graph.nodeType(for: node)
            #expect(node.id.description == "_meta_\(nt.id)")
            let nodeLabel: String = try graph.get(node: node, attribute: Attributes.Node.label)
            #expect(nodeLabel == nt.id.description)
        }
    }

    @Test("A metagraph shows a notation's types, so the criteria for diagrams stay silent")
    func aMetagraphIsNotJudgedAsADiagram() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        // Stock → Stock twice (same, opposite) is two edge types here, not a parallel edge.
        let meta = try parser.parse(source: "metagraph CLD")
        #expect(Notations.analyzeQuality(graph: meta).messages.isEmpty)

        // The same two edges in a diagram are still an error.
        let diagram = try parser.parse(
            source: """
                vgraph d: CLD "D" {
                    node a: Stock "A"
                    node b: Stock "B"
                    edge a -> b: same
                    edge a -> b: opposite
                }
                """)
        #expect(!Notations.analyzeQuality(graph: diagram).messages.isEmpty)
    }

    @Test
    func conceptMapMetagraphWithCustomLabel() throws {
        let source = #"metagraph ConceptMap "How ConceptMaps are built""#
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "How ConceptMaps are built")

        // ConceptMap has 3 NodeTypes (Concept, EmphasizedConcept, Relation).
        #expect(graph.nodes.count == 3)
        let nodeIds = Set(graph.nodes.map { $0.id.description })
        #expect(nodeIds == ["_meta_Concept", "_meta_EmphasizedConcept", "_meta_Relation"])
    }

    @Test
    func userDefinedNotationMetagraph() throws {
        let source = """
            vnotation MyNotation extends ConceptMap {
                node type: Hypothesis [nodeStyle: iconWithText]
                edge type: supports from: Hypothesis to: Concept
            }
            metagraph MyNotation
            """
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: source)

        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "MyNotation Meta Model")

        // MyNotation extends ConceptMap (3 node types) + adds Hypothesis = 4 node types.
        let nodeIds = Set(graph.nodes.map { $0.id.description })
        #expect(nodeIds.contains("_meta_Hypothesis"))
        #expect(nodeIds.contains("_meta_Concept"))
        #expect(nodeIds.contains("_meta_EmphasizedConcept"))
        #expect(nodeIds.contains("_meta_Relation"))

        // At least one edge should be the custom `supports` edge from Hypothesis to Concept.
        let hasSupports = graph.edges.contains { edge in
            (try? graph.edgeType(for: edge).id.description) == "supports"
        }
        #expect(hasSupports)
    }

    @Test
    func aMetagraphDrawsEachDetailingAsADetailedByEdge() throws {
        let source = """
            vnotation Architecture {
                node type: System [nodeStyle: withCategory, detailedBy: (Container, Database)]
                node type: Container [nodeStyle: withCategory, detailedBy: (Container)]
                node type: Database [nodeStyle: withCategory]
                edge type: reads from: Container to: Database
            }
            metagraph Architecture
            """
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: source)

        let detailings = graph.edges.filter {
            (try? graph.get(edge: $0.id, attribute: Attributes.Edge.label)) == "detailed by"
        }
        let pairs = Set(detailings.map { "\($0.from.id)->\($0.to.id)" })
        #expect(
            pairs == ["_meta_System->_meta_Container", "_meta_System->_meta_Database", "_meta_Container->_meta_Container"])
        #expect(graph.edges.count == 4)
        for edge in detailings {
            #expect(try graph.get(edge: edge.id, attribute: Attributes.Edge.style) == .dashed)
        }
    }

    @Test
    func unknownNotationInMetagraph() throws {
        let source = "metagraph DoesNotExist"
        let logger = CapturingLogger()
        let parser = VGraphParser(logger: logger)
        _ = try parser.parse(source: source)
        #expect(logger.errors.contains(where: { $0.contains("DoesNotExist") }))
    }
}
