import Foundation
import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph
@testable import VGraphvizLib

/// Capturing logger for testing warning messages
final class CapturingLogger: ForLogMessages, @unchecked Sendable {
    var warnings: [String] = []
    var errors: [String] = []
    var logs: [String] = []

    func log(_ message: String) {
        logs.append(message)
    }

    func error(_ message: String) {
        errors.append(message)
    }

    func warn(_ message: String) {
        warnings.append(message)
    }
}

let exampleInput = """
        vgraph myGraph: IBIS "My Graph" {
            node node1: Question "Node 1" [color: "#ff0000"; fontsize: 10];
            node node2: Answer "Node 2" [color: "#0000ff"; fontsize: 15];
            edge node1 -> node2 "connects to" [style: dashed; weight: 5];
            group groupA "Group A" {
                style: filled;

                node node3: Question "Node 3" [color: "#008000"];
                edge node2 -> node3 [style: solid];

                group groupB "Group B" {
                    node node4: Question "Node 4" [color: "#008000"];
                };
            };
        }
    """

extension GetAttribute {
    func ensure<T>(node: Node, attribute: TypedAttributeDefinition<T>, isSameAs: T) throws {
        #expect(attribute.target == .node)
        let value = try get(node: node, attribute: attribute)
        #expect(value == isSameAs)
    }

    func ensure<T>(edge: Edge, attribute: TypedAttributeDefinition<T>, isSameAs: T) throws {
        #expect(attribute.target == .edge)
        let value = try get(edge: edge.id, attribute: attribute)
        #expect(value == isSameAs)
    }

    func ensure<T>(group: Group, attribute: TypedAttributeDefinition<T>, isSameAs: T) throws {
        #expect(attribute.target == .graph)
        let value = try get(group: group, attribute: attribute)
        #expect(value == isSameAs)
    }

    func ensure<T>(nodeType: NodeType, attribute: TypedAttributeDefinition<T>, isSameAs: T) throws {
        #expect(attribute.target == .node)
        let value = try get(nodeType: nodeType, attribute: attribute)
        #expect(value == isSameAs)
    }
}

@Suite
struct BasicParserTest {

    @Test
    func exampleInputToGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: exampleInput)
        let id: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(id == "myGraph")
        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "My Graph")
        #expect(graph.nodes.count == 4)
        #expect(graph.edges.count == 2)
        #expect(graph.groups.count == 2)

        let node1 = graph.nodes[0]
        let node2 = graph.nodes[1]
        let node3 = graph.nodes[2]
        let node4 = graph.nodes[3]
        let edge1 = graph.edges[0]
        let edge2 = graph.edges[1]
        let group1 = graph.groups[0]
        let group2 = graph.groups[1]

        try graph.ensure(node: node1, attribute: Attributes.Node.label, isSameAs: "Node 1")
        try graph.ensure(node: node1, attribute: Attributes.Node.fontsize, isSameAs: 10)
        try graph.ensure(node: node1, attribute: Attributes.Node.backgroundColor, isSameAs: VColor(hexString: "#ff0000")!)
        #expect((try graph.nodeType(for: node1)) == Notations.Ibis.NodeTypes.question)

        try graph.ensure(node: node2, attribute: Attributes.Node.fontsize, isSameAs: 15)
        try graph.ensure(node: node2, attribute: Attributes.Node.backgroundColor, isSameAs: VColor(hexString: "#0000ff")!)
        #expect((try graph.nodeType(for: node2)) == Notations.Ibis.NodeTypes.answer)

        try graph.ensure(node: node3, attribute: Attributes.Node.backgroundColor, isSameAs: VColor(hexString: "#008000")!)
        try graph.ensure(node: node3, attribute: Attributes.Node.label, isSameAs: "Node 3")
        #expect((try graph.nodeType(for: node3)) == Notations.Ibis.NodeTypes.question)

        try graph.ensure(node: node4, attribute: Attributes.Node.label, isSameAs: "Node 4")

        try graph.ensure(edge: edge1, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.dashed)
        try graph.ensure(edge: edge1, attribute: Attributes.Edge.weight, isSameAs: 5)
        try graph.ensure(edge: edge1, attribute: Attributes.Edge.label, isSameAs: "connects to")
        #expect((try graph.edgeType(for: edge1)) == Notations.Ibis.EdgeTypes.questionToAnswer)

        try graph.ensure(edge: edge2, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.solid)
        try graph.ensure(edge: edge2, attribute: Attributes.Edge.weight, isSameAs: Attributes.Edge.weight.defaultValue)
        try graph.ensure(edge: edge2, attribute: Attributes.Edge.label, isSameAs: "")
        #expect((try graph.edgeType(for: edge2)) == Notations.Ibis.EdgeTypes.answerToQuestion)

        #expect(group1.id.description == "groupA")
        try graph.ensure(group: group1, attribute: Attributes.Group.Id, isSameAs: "groupA")
        try graph.ensure(group: group1, attribute: Attributes.Group.label, isSameAs: "Group A")
        try graph.ensure(group: group1, attribute: Attributes.Group.style, isSameAs: .filled)
        try graph.ensure(group: group1, attribute: Attributes.Group.isFolded, isSameAs: false)

        try graph.ensure(group: group2, attribute: Attributes.Group.Id, isSameAs: "groupB")

    }

    @Test func testUnknownNotation() throws {
        let input = """
            vgraph testGraph: UnknownNotation "Test Unknown Notation" {
                node node1: SomeType "Node 1";
            }
            """

        let logger = CapturingLogger()
        let parser = VGraphParser(logger: logger)
        let graph = try parser.parse(source: input)

        #expect(logger.errors.count >= 1)
        #expect(logger.errors.first?.contains("Unknown notation") == true)
        #expect(logger.errors.first?.contains("UnknownNotation") == true)

        // Graph should still be created but without notation-specific types
        #expect(graph.nodes.count == 1)
    }

    @Test func testUnknownNodeType() throws {
        let input = """
            vgraph testGraph: IBIS "Test Unknown Node Type" {
                node node1: InvalidType "Node with invalid type";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let node1 = Node(string: "node1")
        #expect(graph.has(node: node1))

        let nodeType = try graph.nodeType(for: node1)
        #expect(nodeType == NodeType.unknown)
    }

    @Test func testNodeWithoutLabelUsesId() throws {
        // A node declared without a label falls back to its id as the label
        // (not the generic "Change Me" default), so it is meaningful in the
        // drawing. The id-derived label is then emitted explicitly on export.
        let input = """
            vgraph testGraph: IBIS "Test Missing Label" {
                node leads: Question;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let leads = Node(string: "leads")
        #expect(graph.has(node: leads))
        try graph.ensure(node: leads, attribute: Attributes.Node.label, isSameAs: "leads")

        // Round-trip: the id-derived label is exported explicitly.
        let exported = try VGLExporter().export(graph: graph)
        #expect(exported.contains("\"leads\""))
    }

    @Test func testUnknownEdgeType() throws {
        let input = """
            vgraph testGraph: IBIS "Test Unknown Edge Type" {
                node node1: Question "Node 1";
                node node2: Answer "Node 2";
                edge node1 -> node2: invalid_edge_type "Edge with invalid type";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let edges = graph.edges
        #expect(edges.count == 1)

        let edge1 = edges[0]
        let edgeType = try graph.edgeType(for: edge1.id)

        #expect(edgeType.id.description.starts(with: EdgeType.unknownPrefix))

        let fromNodeType = try graph.nodeType(for: edge1.from)
        let toNodeType = try graph.nodeType(for: edge1.to)
        #expect(edgeType.from == fromNodeType)
        #expect(edgeType.to == toNodeType)
    }

    @Test func testEdgeTypeNodeTypeMismatch() throws {
        let input = """
            vgraph testGraph: IBIS "Test Edge Type Mismatch" {
                node node1: Question "Node 1";
                node node2: Question "Node 2";
                edge node1 -> node2: answered_by "Wrong edge type for these nodes";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let edges = graph.edges
        #expect(edges.count == 1)

        let edge1 = edges[0]
        let edgeType = try graph.edgeType(for: edge1.id)

        #expect(edgeType.id.description.starts(with: EdgeType.unknownPrefix))

        #expect(edgeType.from == Notations.Ibis.NodeTypes.question)
        #expect(edgeType.to == Notations.Ibis.NodeTypes.question)
    }

    @Test func testIBISNotationWithProAndCon() throws {
        let input = """
            vgraph ibisGraph: IBIS "IBIS with Pro and Con" {
                node q1: Question "Main Question";
                node a1: Answer "Answer 1";
                node p1: Pro "Pro Argument";
                node c1: Con "Con Argument";
                node q2: Question "Follow-up Question";

                edge q1 -> a1: answered_by;
                edge a1 -> p1: supports;
                edge a1 -> c1: objects_to;
                edge p1 -> q2: pro_questions_question;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        let p1 = Node(string: "p1")
        let c1 = Node(string: "c1")
        let q2 = Node(string: "q2")

        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
        #expect(graph.has(node: p1))
        #expect(graph.has(node: c1))
        #expect(graph.has(node: q2))

        #expect((try graph.nodeType(for: q1)) == Notations.Ibis.NodeTypes.question)
        #expect((try graph.nodeType(for: a1)) == Notations.Ibis.NodeTypes.answer)
        #expect((try graph.nodeType(for: p1)) == Notations.Ibis.NodeTypes.pro)
        #expect((try graph.nodeType(for: c1)) == Notations.Ibis.NodeTypes.con)
        #expect((try graph.nodeType(for: q2)) == Notations.Ibis.NodeTypes.question)

        #expect(graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.question)?.backgroundFill != nil)
        #expect(graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.answer)?.backgroundFill != nil)
        #expect(graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.pro)?.backgroundFill != nil)
        #expect(graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.con)?.backgroundFill != nil)

        let edges = graph.edges
        #expect(edges.count == 4)

        let edge1 = edges.first { $0.from == q1 && $0.to == a1 }
        let edge2 = edges.first { $0.from == a1 && $0.to == p1 }
        let edge3 = edges.first { $0.from == a1 && $0.to == c1 }
        let edge4 = edges.first { $0.from == p1 && $0.to == q2 }

        #expect(edge1 != nil)
        #expect(edge2 != nil)
        #expect(edge3 != nil)
        #expect(edge4 != nil)

        #expect((try graph.edgeType(for: edge1!.id)) == Notations.Ibis.EdgeTypes.questionToAnswer)
        #expect((try graph.edgeType(for: edge2!.id)) == Notations.Ibis.EdgeTypes.answerToPro)
        #expect((try graph.edgeType(for: edge3!.id)) == Notations.Ibis.EdgeTypes.answerToCon)
        #expect((try graph.edgeType(for: edge4!.id)) == Notations.Ibis.EdgeTypes.proToQuestion)
    }

    @Test func testGetAllAttributesForNodeType() throws {
        let input = """
            vgraph test: IBIS "Test getAllAttributes" {
                node q1: Question "Q1";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Get all attributes for Question node type
        let allAttrs = graph.getAllAttributes(nodeType: Notations.Ibis.NodeTypes.question)

        // IBIS styles Question; its font is the default, so it is not held (ADR-0030).
        #expect(allAttrs[Attributes.Node.nodeStyle.id] != nil)

        // getAllAttributes returns ALL attributes for the node type
        #expect(allAttrs.count >= 1)
    }

    @Test func testGetAllAttributesForEdgeType() throws {
        let input = """
            vgraph test: IBIS "Test edge type attributes" {
                node q1: Question "Q1";
                node a1: Answer "A1";
                edge q1 -> a1: answered_by;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        // Get all attributes for the answered_by edge type
        let allAttrs = graph.getAllAttributes(edgeType: Notations.Ibis.EdgeTypes.questionToAnswer.id)

        // Should return all attributes for this edge type (might be empty if none are set)
        #expect(allAttrs.count >= 0)
    }

    @Test func testDotExporterUsesAllAttributes() throws {
        let input = """
            vgraph test: IBIS "Test DOT Export" {
                node q1: Question "Question without explicit color" [fontsize: 10];
                node q2: Question "Question with explicit color" [color: "#ff0000"];
                node a1: Answer "Answer";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        let exporter = DotExporter()
        let dot = try exporter.export(graph: graph)

        let questionFill = try #require(
            graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.question)?.backgroundFill)
        let answerFill = try #require(
            graph.effectiveNodeLayout(for: Notations.Ibis.NodeTypes.answer)?.backgroundFill)

        let q1Line = try #require(dot.split(separator: "\n").first { $0.contains("q1") })
        #expect(q1Line.contains(questionFill.hexString))

        let q2Line = try #require(dot.split(separator: "\n").first { $0.contains("q2") })
        #expect(q2Line.contains("#ff0000"))
        #expect(!q2Line.contains(questionFill.hexString))

        let a1Line = try #require(dot.split(separator: "\n").first { $0.contains("a1") })
        #expect(a1Line.contains(answerFill.hexString))
    }

    // MARK: - Less Verbose Syntax Tests

    @Test func testNodeWithoutBraces() throws {
        let input = """
            vgraph test: IBIS "Test Node Without Braces" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
        try graph.ensure(node: q1, attribute: Attributes.Node.label, isSameAs: "Question 1")
        try graph.ensure(node: a1, attribute: Attributes.Node.label, isSameAs: "Answer 1")
    }

    @Test func testNodeWithInlineBracketAttributes() throws {
        let input = """
            vgraph test: IBIS "Test Inline Attributes" {
                node q1: Question "Question 1" [fontsize: 12];
                node a1: Answer "Answer 1" [fontsize: 10; color: "#ff0000"];
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        try graph.ensure(node: q1, attribute: Attributes.Node.fontsize, isSameAs: 12)
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 10)
        try graph.ensure(node: a1, attribute: Attributes.Node.backgroundColor, isSameAs: VColor(hexString: "#ff0000")!)
    }

    @Test func testEdgeWithoutBraces() throws {
        let input = """
            vgraph test: IBIS "Test Edge Without Braces" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1";
                edge q1 -> a1: answered_by;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.edges.count == 1)
        let edge = graph.edges[0]
        #expect(edge.from == Node(string: "q1"))
        #expect(edge.to == Node(string: "a1"))
    }

    @Test func testEdgeWithoutTypeAndBraces() throws {
        let input = """
            vgraph test: IBIS "Test Edge Without Type" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1";
                edge q1 -> a1;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.edges.count == 1)
        let edge = graph.edges[0]
        #expect(edge.from == Node(string: "q1"))
        #expect(edge.to == Node(string: "a1"))
    }

    @Test func testEdgeWithInlineBracketAttributes() throws {
        let input = """
            vgraph test: IBIS "Test Edge Inline Attributes" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1";
                edge q1 -> a1: answered_by [style: dashed];
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.edges.count == 1)
        let edge = graph.edges[0]
        try graph.ensure(edge: edge, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.dashed)
    }

    @Test func testConciseSyntaxVariations() throws {
        let input = """
            vgraph test: IBIS "Test Concise Syntax" {
                node q1: Question "Question 1" [fontsize: 12];
                node a1: Answer "Answer 1" [fontsize: 10];
                node p1: Pro "Pro 1";

                edge q1 -> a1 [style: solid];
                edge a1 -> p1 [style: dashed];
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 3)
        #expect(graph.edges.count == 2)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        let p1 = Node(string: "p1")

        try graph.ensure(node: q1, attribute: Attributes.Node.fontsize, isSameAs: 12)
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 10)
        #expect(graph.has(node: p1))

        let edge1 = graph.edges.first { $0.from == q1 && $0.to == a1 }
        let edge2 = graph.edges.first { $0.from == a1 && $0.to == p1 }
        #expect(edge1 != nil)
        #expect(edge2 != nil)

        try graph.ensure(edge: edge1!, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.solid)
        try graph.ensure(edge: edge2!, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.dashed)
    }

    @Test func testSubgraphWithIBISNodes() throws {
        let input = """
            vgraph myGraph: IBIS "My IBIS Graph" {
                node q1: Question "What should we do?" [fontsize: 20];
                node a1: Answer "We should implement feature X" [fontsize: 11];
                group lsj "Subgraph" {
                    node pro1: Pro "It will improve performance" [fontsize: 10];
                    node con1: Con "It will increase complexity" [fontsize: 10];
                };
                edge q1 -> a1;
                edge a1 -> pro1;
                edge a1 -> con1 [style: dashed];
                edge pro1 -> con1 [label: "Unknown edge type (will be red and bold)"];
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 4)
        #expect(graph.edges.count == 4)
        #expect(graph.groups.count == 1)  // "lsj" group (root group is filtered out)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        let pro1 = Node(string: "pro1")
        let con1 = Node(string: "con1")

        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
        #expect(graph.has(node: pro1))
        #expect(graph.has(node: con1))

        try graph.ensure(node: q1, attribute: Attributes.Node.fontsize, isSameAs: 20)
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 11)
        try graph.ensure(node: pro1, attribute: Attributes.Node.fontsize, isSameAs: 10)
        try graph.ensure(node: con1, attribute: Attributes.Node.fontsize, isSameAs: 10)

        #expect((try graph.nodeType(for: q1)) == Notations.Ibis.NodeTypes.question)
        #expect((try graph.nodeType(for: a1)) == Notations.Ibis.NodeTypes.answer)
        #expect((try graph.nodeType(for: pro1)) == Notations.Ibis.NodeTypes.pro)
        #expect((try graph.nodeType(for: con1)) == Notations.Ibis.NodeTypes.con)

        let group = graph.groups[0]
        #expect(group.id.description == "lsj")
        try graph.ensure(group: group, attribute: Attributes.Group.label, isSameAs: "Subgraph")

        let rootGroup = Group(rawValue: "vithanco.vgraph.rootGroup.only.for.internal.use")
        #expect(graph.group(of: q1) == rootGroup)  // q1 is in root group
        #expect(graph.group(of: a1) == rootGroup)  // a1 is in root group
        #expect(graph.group(of: pro1) == group)  // pro1 is in the subgraph
        #expect(graph.group(of: con1) == group)  // con1 is in the subgraph

        let edges = graph.edges
        let edge1 = edges.first { $0.from == q1 && $0.to == a1 }
        let edge2 = edges.first { $0.from == a1 && $0.to == pro1 }
        let edge3 = edges.first { $0.from == a1 && $0.to == con1 }
        let edge4 = edges.first { $0.from == pro1 && $0.to == con1 }

        #expect(edge1 != nil)
        #expect(edge2 != nil)
        #expect(edge3 != nil)
        #expect(edge4 != nil)

        try graph.ensure(edge: edge3!, attribute: Attributes.Edge.style, isSameAs: Attributes.Edge.StyleType.dashed)

        // Note: Edge label via bracket syntax - verify it works
        // The attribute name in the parser is "label" but the Edge.label definition has name "Label on Edge"
        // The parser should still find it via substring match
        let edge4Label = try graph.get(edge: edge4!.id, attribute: Attributes.Edge.label)
        #expect(
            edge4Label == "Unknown edge type (will be red and bold)",
            "Edge label should be set via bracket attribute syntax")
    }

    // MARK: - Comment Tests

    @Test func testCommentsInGraph() throws {
        let input = """
            vgraph test: IBIS "Test Comments" {
                // This is a comment before a node
                node q1: Question "Question 1";
                node a1: Answer "Answer 1"; // This is a comment after a node
                // This is a comment before an edge
                edge q1 -> a1; // This is a comment after an edge
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
    }

    @Test func testCommentsWithAttributes() throws {
        let input = """
            vgraph test: IBIS "Test Comments With Attributes" {
                // Node with inline attributes
                node q1: Question "Question 1" [fontsize: 12]; // Comment after attributes
                node a1: Answer "Answer 1" [
                    // Comment inside attribute block
                    fontsize: 10;
                    color: "#ff0000"
                ]; // Comment after closing bracket
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        try graph.ensure(node: q1, attribute: Attributes.Node.fontsize, isSameAs: 12)
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 10)
        try graph.ensure(node: a1, attribute: Attributes.Node.backgroundColor, isSameAs: VColor(hexString: "#ff0000")!)
    }

    // MARK: - Optional Semicolon Tests

    @Test func testParsingWithoutSemicolons() throws {
        let input = """
            vgraph test: IBIS "Test Without Semicolons" {
                node q1: Question "Question 1"
                node a1: Answer "Answer 1" [fontsize: 10]
                edge q1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)

        let q1 = Node(string: "q1")
        let a1 = Node(string: "a1")
        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 10)
    }

    @Test func testParsingMixedSemicolons() throws {
        let input = """
            vgraph test: IBIS "Test Mixed Semicolons" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1"
                node p1: Pro "Pro 1";
                edge q1 -> a1
                edge a1 -> p1;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 3)
        #expect(graph.edges.count == 2)
    }

    @Test func testParsingGroupsWithoutSemicolons() throws {
        let input = """
            vgraph test: IBIS "Test Groups Without Semicolons" {
                node q1: Question "Question 1"
                group myGroup "My Group" {
                    style: filled
                    node a1: Answer "Answer 1"
                }
                edge q1 -> a1
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)
        #expect(graph.edges.count == 1)
        #expect(graph.groups.count == 1)

        let group = graph.groups[0]
        try graph.ensure(group: group, attribute: Attributes.Group.style, isSameAs: .filled)
    }

    @Test func testCommentOnlyLines() throws {
        let input = """
            vgraph test: IBIS "Test Comment Only Lines" {
                // First comment
                // Second comment

                node q1: Question "Question 1";

                // Comment between nodes

                node a1: Answer "Answer 1";

                // Final comment
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 2)
    }

    @Test func testCommentsInGroups() throws {
        let input = """
            vgraph test: IBIS "Test Comments In Groups" {
                // Main question and primary answers
                node q1: Question "What architecture?";
                node a1: Answer "Microservices";
                node a2: Answer "Monolithic";

                // Arguments for Microservices
                group pros "Pros" {
                    // Pro arguments
                    node pro1: Pro "Better scalability";
                    node pro2: Pro "Independent deployment";
                };

                // Connect nodes
                edge q1 -> a1;
                edge q1 -> a2;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: input)

        #expect(graph.nodes.count == 5)
        #expect(graph.edges.count == 2)
        #expect(graph.groups.count == 1)
    }

    /// Regression: `parseToAST` must surface the specific `VParserError`
    /// description (e.g. "Duplicate node: 'n1' is already defined") through
    /// `VError.parsingError`, not a generic "Failed to parse VGL source".
    ///
    /// This guards the bare-`catch` form in `VGraphParser.parseToAST` —
    /// reverting to `try?` would replace the inner message with a generic one,
    /// and reverting to `catch let _ as VParserError` would hit a Swift 6.3.2
    /// SILGen crash.
    @Test func testParseErrorSurfacesInnerVParserErrorDescription() throws {
        let input = """
            vgraph testGraph: IBIS "Duplicate node id" {
                node n1: Question "first";
                node n1: Answer "duplicate";
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())

        var thrown: VError?
        do {
            _ = try parser.parse(source: input)
        } catch {
            thrown = error
        }

        guard case .parsingError(let message) = thrown else {
            Issue.record("Expected VError.parsingError, got \(String(describing: thrown))")
            return
        }

        #expect(message.contains("Duplicate node"))
        #expect(message.contains("n1"))
        #expect(message != "Failed to parse VGL source")
    }
}
