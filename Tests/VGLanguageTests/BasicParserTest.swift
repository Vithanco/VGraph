import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

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
        #expect(attribute.target == .group)
        let value = try get(group: group, attribute: attribute)
        #expect(value == isSameAs)
    }
}

@Suite
struct BasicParserTest {

    @Test
    func exampleInputToGraph() throws {
        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: exampleInput)
        let id: String = try graph.get(graphAttribute: Attributes.Group.id)
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
        try graph.ensure(group: group1, attribute: Attributes.Group.id, isSameAs: "groupA")
        try graph.ensure(group: group1, attribute: Attributes.Group.label, isSameAs: "Group A")
        try graph.ensure(group: group1, attribute: Attributes.Group.style, isSameAs: .filled)
        try graph.ensure(group: group1, attribute: Attributes.Group.isFolded, isSameAs: false)

        try graph.ensure(group: group2, attribute: Attributes.Group.id, isSameAs: "groupB")

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

        #expect(logger.errors.count == 1)
        #expect(logger.errors.first?.contains("UnknownNotation") == true)
        #expect(logger.errors.first?.contains("IBIS") == true, "The error should list the registered notations")

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

        let node1 = Node(rawValue: "node1")
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

        let leads = Node(rawValue: "leads")
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

        let q1 = Node(rawValue: "q1")
        let a1 = Node(rawValue: "a1")
        let p1 = Node(rawValue: "p1")
        let c1 = Node(rawValue: "c1")
        let q2 = Node(rawValue: "q2")

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

    // MARK: - Less Verbose Syntax Tests

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

        #expect(graph.groups.count == 1)  // "lsj" group (root group is filtered out)

        let q1 = Node(rawValue: "q1")
        let a1 = Node(rawValue: "a1")
        let pro1 = Node(rawValue: "pro1")
        let con1 = Node(rawValue: "con1")

        let group = graph.groups[0]
        #expect(group.id.description == "lsj")
        try graph.ensure(group: group, attribute: Attributes.Group.label, isSameAs: "Subgraph")

        #expect(graph.group(of: q1) == Group.root)
        #expect(graph.group(of: a1) == Group.root)
        #expect(graph.group(of: pro1) == group)
        #expect(graph.group(of: con1) == group)

        let edge4 = try #require(graph.edges.first { $0.from == pro1 && $0.to == con1 })
        #expect(try graph.edgeType(for: edge4.id).isUnknown, "Pro to Con has no edge type")
        try graph.ensure(
            edge: edge4, attribute: Attributes.Edge.label, isSameAs: "Unknown edge type (will be red and bold)")
    }

    // MARK: - Comment Tests

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

        let q1 = Node(rawValue: "q1")
        let a1 = Node(rawValue: "a1")
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

        let q1 = Node(rawValue: "q1")
        let a1 = Node(rawValue: "a1")
        #expect(graph.has(node: q1))
        #expect(graph.has(node: a1))
        try graph.ensure(node: a1, attribute: Attributes.Node.fontsize, isSameAs: 10)
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
