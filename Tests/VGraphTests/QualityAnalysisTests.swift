import TestSupport
import Testing

@testable import VGraph

@Suite("Generic Quality Checks")
struct GenericQualityChecksTests {

    typealias CM = Notations.ConceptMap

    private func createConceptMapGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        graph = graph.using(notation: "ConceptMap")
        return graph
    }

    private func addConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.concept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addRelation(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.relation)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEdge(id: String, from: String, to: String, type: EdgeType, in graph: VGraph) throws(VError) -> VGraph {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: type)
    }

    @Test("Disconnected node produces warning")
    func testDisconnectedNodeWarning() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        // Only connect a and r1, leave b disconnected
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.disconnectedNodes(graph: graph)
        let catWarnings = messages.filter { $0.message.contains("Cat") }
        #expect(!catWarnings.isEmpty)
        #expect(catWarnings.first?.severity == .warning)
    }

    @Test("Fully connected graph has no disconnected node warnings")
    func testNoDisconnectedWarnings() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)

        let messages = GenericQualityChecks.disconnectedNodes(graph: graph)
        #expect(messages.isEmpty)
    }

    @Test("Unknown node type produces error")
    func testUnknownNodeTypeError() throws {
        var graph = try createConceptMapGraph()
        graph = try graph.ensureUnknownNodeType()
        let node = Node(string: "bad_node")
        graph = try graph.add(node: node, type: NodeType.unknown)
        graph = try graph.set(node: node, attribute: Attributes.Node.label.attribute("Mystery"))

        let messages = GenericQualityChecks.unknownNodeTypes(graph: graph)
        #expect(!messages.isEmpty)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("unknown node type") == true)
    }

    @Test("Unknown edge type produces error")
    func testUnknownEdgeTypeError() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)

        // Create an edge with an unknown edge type (concept to concept is not allowed in ConceptMap)
        let unknownEdgeType = EdgeType.unknown(from: CM.NodeTypes.concept, to: CM.NodeTypes.concept)
        graph = try graph.add(edgeType: unknownEdgeType)
        let edge = Edge(string: "bad_edge", from: "a", to: "b")
        graph = try graph.add(edge: edge, edgeType: unknownEdgeType)

        let messages = GenericQualityChecks.unknownEdgeTypes(graph: graph)
        #expect(!messages.isEmpty)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("invalid edge type") == true)
    }

    @Test("OrJunctor in sufficient-cause notation produces redundancy warning")
    func testRedundantOrJunctorUnderSufficientCause() throws {
        // PrerequisiteTree is necessary-condition by default and registers OrJunctor;
        // override the diagram logic to sufficient-cause to provoke the redundancy warning.
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.PrerequisiteTree.addNotation(addTo: graph)
        graph = try graph.set(graphAttribute: Attributes.Group.diagramLogic.attribute(.sufficientCause))

        let or = Node(string: "or1")
        graph = try graph.add(node: or, type: Notations.PrerequisiteTree.NodeTypes.orJunctor)
        graph = try graph.set(node: or, attribute: Attributes.Node.label.attribute("alt"))

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        // PrerequisiteTree's OrJunctor uses the short "OR" type id
        #expect(messages.first?.message.contains("OR") == true)
        #expect(messages.first?.message.contains("implicit OR") == true)
    }

    @Test("AndJunctor in necessary-condition notation produces redundancy warning")
    func testRedundantAndJunctorUnderNecessaryCondition() throws {
        // CRT is sufficient-cause by default and registers AndJunctor;
        // override the diagram logic to necessary-condition to provoke the redundancy warning.
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.CurrentRealityTree.addNotation(addTo: graph)
        graph = try graph.set(graphAttribute: Attributes.Group.diagramLogic.attribute(.necessaryCondition))

        let and = Node(string: "and1")
        graph = try graph.add(node: and, type: Notations.CurrentRealityTree.NodeTypes.andJunctor)
        graph = try graph.set(node: and, attribute: Attributes.Node.label.attribute("combo"))

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("AndJunctor") == true)
        #expect(messages.first?.message.contains("implicit AND") == true)
    }

    @Test("AndJunctor under sufficient-cause logic is fine (no warning)")
    func testAndJunctorUnderSufficientCauseIsFine() throws {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.CurrentRealityTree.addNotation(addTo: graph)

        let and = Node(string: "and1")
        graph = try graph.add(node: and, type: Notations.CurrentRealityTree.NodeTypes.andJunctor)

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.isEmpty)
    }

    @Test("noLogic notation skips junctor redundancy check entirely")
    func testNoLogicSkipsCheck() throws {
        // ConceptMap is noLogic; the check should bail out without inspecting node types.
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.ConceptMap.addNotation(addTo: graph)

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.isEmpty)
    }

    @Test("Full quality analysis runs all levels")
    func testFullAnalysis() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)

        let report = Notations.analyzeQuality(graph: graph)
        #expect(report.notationName == "ConceptMap")
        #expect(!report.infos.isEmpty)
    }
}

@Suite("ConceptMap Quality Checks")
struct ConceptMapQualityChecksTests {

    typealias CM = Notations.ConceptMap

    private func createConceptMapGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        graph = graph.using(notation: "ConceptMap")
        return graph
    }

    private func addConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.concept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addRelation(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.relation)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEdge(id: String, from: String, to: String, type: EdgeType, in graph: VGraph) throws(VError) -> VGraph {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: type)
    }

    @Test("Concept/relation ratio reported as info")
    func testConceptRelationRatio() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)

        let messages = CM.conceptRelationRatio(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .info)
        #expect(messages.first?.message.contains("Concepts: 2") == true)
        #expect(messages.first?.message.contains("Relations: 1") == true)
    }

    @Test("Label length warning for long concept names")
    func testLabelLengthWarning() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "A Very Long Name Here", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)

        let messages = CM.labelLengthCheck(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("A Very Long Name Here") == true)
    }

    @Test("Unconnected concept produces warning")
    func testUnconnectedConcept() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("orphan", label: "Orphan", to: graph)
        graph = try addRelation("r1", label: "is", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.unconnectedConcepts(graph, topology: topology)
        let orphanWarnings = messages.filter { $0.message.contains("Orphan") }
        #expect(!orphanWarnings.isEmpty)
        #expect(orphanWarnings.first?.severity == .warning)
    }

    @Test("Relation with no edges produces error")
    func testIncompleteRelationNoEdges() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.incompleteRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("likes") == true)
        #expect(messages.first?.message.contains("no incoming or outgoing") == true)
    }

    @Test("Relation with no incoming concept produces error")
    func testIncompleteRelationNoIncoming() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "r1", to: "a", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.incompleteRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("likes") == true)
        #expect(messages.first?.message.contains("no incoming concept") == true)
    }

    @Test("Relation with no outgoing concept produces error")
    func testIncompleteRelationNoOutgoing() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.incompleteRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("likes") == true)
        #expect(messages.first?.message.contains("no outgoing concept") == true)
    }

    @Test("Complete relation produces no incomplete-relation error")
    func testCompleteRelationNoError() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addRelation("r1", label: "likes", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.incompleteRelations(graph, topology: topology)
        #expect(messages.isEmpty)
    }

    @Test("Unreused relations with same label and targets")
    func testUnreusedRelations() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)
        graph = try addConcept("b", label: "Cat", to: graph)
        graph = try addConcept("c", label: "Mammal", to: graph)
        graph = try addRelation("r1", label: "is a", to: graph)
        graph = try addRelation("r2", label: "is a", to: graph)
        // Both relations point to Mammal
        graph = try addEdge(id: "e1", from: "a", to: "r1", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "r1", to: "c", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e3", from: "b", to: "r2", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e4", from: "r2", to: "c", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.unreusedRelations(graph, topology: topology)
        #expect(!messages.isEmpty)
        #expect(messages.first?.message.contains("is a") == true)
        #expect(messages.first?.message.contains("reusing") == true)
    }
}

@Suite("IBIS Quality Checks")
struct IBISQualityChecksTests {

    typealias IB = Notations.Ibis

    private func createIBISGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try IB.addNotation(addTo: graph)
        graph = graph.using(notation: "IBIS")
        return graph
    }

    private func addQuestion(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: IB.NodeTypes.question)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addAnswer(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: IB.NodeTypes.answer)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    @Test("Node with multiple parents produces warning")
    func testMultipleParentsWarning() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Question 1", to: graph)
        graph = try addQuestion("q2", label: "Question 2", to: graph)
        graph = try addAnswer("a1", label: "Answer", to: graph)
        // Both questions point to the same answer (2 parents)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )
        graph = try graph.add(
            edge: Edge(string: "e2", from: "q2", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let parentWarnings = Notations.analyzeQuality(graph: graph).messages
            .filter { $0.message.contains("parent nodes") }
        #expect(parentWarnings.count == 1)
        #expect(parentWarnings.first?.severity == .warning)
        #expect(parentWarnings.first?.message.contains("\"Answer\" has 2 parent nodes") == true)
    }

    @Test("analyzeQuality dispatches IBIS notation checks by stored name")
    func testIBISChecksRunViaDispatch() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Unanswered Question", to: graph)

        let report = Notations.analyzeQuality(graph: graph)
        #expect(report.messages.contains { $0.message.contains("has no Answer") })
    }

    @Test("Well-formed IBIS tree has no warnings")
    func testWellFormedIBIS() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Main Question", to: graph)
        graph = try addAnswer("a1", label: "Answer 1", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let parentWarnings = Notations.analyzeQuality(graph: graph).messages
            .filter { $0.message.contains("parent nodes") }
        #expect(parentWarnings.isEmpty)
    }

    @Test("Question without an Answer produces warning")
    func testUnansweredQuestionWarning() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Unanswered Question", to: graph)

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("Unanswered Question") == true)
    }

    @Test("Question with an Answer produces no warning")
    func testAnsweredQuestionNoWarning() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Answered Question", to: graph)
        graph = try addAnswer("a1", label: "An Answer", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.isEmpty)
    }

    @Test("Only unanswered Questions are flagged, answered ones are not")
    func testMixedAnsweredAndUnanswered() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Has Answer", to: graph)
        graph = try addQuestion("q2", label: "No Answer", to: graph)
        graph = try addAnswer("a1", label: "Answer 1", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.message.contains("No Answer") == true)
    }

    @Test("A sub-Question is not an Answer")
    func testSubQuestionDoesNotAnswer() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Parent", to: graph)
        graph = try addQuestion("q2", label: "Child", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q1", to: "q2"),
            edgeType: IB.EdgeTypes.questionToQuestion
        )

        let flagged = IB.unansweredQuestions(graph).map { $0.target }
        #expect(flagged == [.node("q1"), .node("q2")])
    }

    @Test("An Answer pointing at a Question does not answer it")
    func testIncomingAnswerDoesNotAnswer() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Raised by an Answer", to: graph)
        graph = try addAnswer("a1", label: "Answer 1", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "a1", to: "q1"),
            edgeType: IB.EdgeTypes.answerToQuestion
        )

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("q1"))
    }

    @Test("Unanswered question warning surfaces through full analyzeQuality pipeline")
    func testUnansweredQuestionInFullPipeline() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Lonely Question", to: graph)
        graph = try addQuestion("q2", label: "Happy Question", to: graph)
        graph = try addAnswer("a1", label: "Answer 1", to: graph)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "q2", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let report = Notations.analyzeQuality(graph: graph)
        let unansweredWarnings = report.warnings.filter { $0.message.contains("no Answer") }
        #expect(unansweredWarnings.count == 1)
        #expect(unansweredWarnings[0].message.contains("Lonely Question"))
    }
}

@Suite("GoalTree Quality Checks")
struct GoalTreeQualityChecksTests {

    typealias GT = Notations.GoalTree

    private func createGoalTreeGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try GT.addNotation(addTo: graph)
        graph = graph.using(notation: "GoalTree")
        return graph
    }

    private func addGoal(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: GT.NodeTypes.goal)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addCSF(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: GT.NodeTypes.criticalSuccessFactor)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    @Test("No Goal node produces error")
    func testNoGoalError() throws {
        var graph = try createGoalTreeGraph()
        graph = try addCSF("csf1", label: "CSF 1", to: graph)

        let messages = GT.exactlyOneGoal(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("no Goal node") == true)
    }

    @Test("Multiple Goal nodes produce error")
    func testMultipleGoalsError() throws {
        var graph = try createGoalTreeGraph()
        graph = try addGoal("g1", label: "Goal 1", to: graph)
        graph = try addGoal("g2", label: "Goal 2", to: graph)

        let messages = GT.exactlyOneGoal(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("2 Goal nodes") == true)
    }

    @Test("Exactly one Goal node produces no error")
    func testExactlyOneGoal() throws {
        var graph = try createGoalTreeGraph()
        graph = try addGoal("g1", label: "Goal", to: graph)

        let messages = GT.exactlyOneGoal(graph)
        #expect(messages.isEmpty)
    }

    @Test("Few CSFs produce info")
    func testFewCSFsInfo() throws {
        var graph = try createGoalTreeGraph()
        graph = try addGoal("g1", label: "Goal", to: graph)
        graph = try addCSF("csf1", label: "CSF 1", to: graph)

        let messages = GT.csfCount(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .info)
        #expect(messages.first?.message.contains("1 Critical Success Factors") == true)
    }

    @Test("3-5 CSFs produce no info")
    func testGoodCSFCount() throws {
        var graph = try createGoalTreeGraph()
        graph = try addGoal("g1", label: "Goal", to: graph)
        graph = try addCSF("csf1", label: "CSF 1", to: graph)
        graph = try addCSF("csf2", label: "CSF 2", to: graph)
        graph = try addCSF("csf3", label: "CSF 3", to: graph)

        let messages = GT.csfCount(graph)
        #expect(messages.isEmpty)
    }
}

// MARK: - GraphTopology Tests

@Suite("GraphTopology")
struct GraphTopologyTests {

    @Test("Empty edges produce empty topology")
    func testEmptyEdges() {
        let topology = GraphTopology(edges: [Edge]())
        #expect(topology.outgoingTargets.isEmpty)
        #expect(topology.incomingSources.isEmpty)
        #expect(topology.connectedNodes.isEmpty)
    }

    @Test("Single edge builds correct indexes")
    func testSingleEdge() {
        let edge = Edge(string: "e1", from: "a", to: "b")
        let topology = GraphTopology(edges: [edge])

        let nodeA = Node(string: "a")
        let nodeB = Node(string: "b")

        #expect(topology.outgoingTargets[nodeA] == [nodeB])
        #expect(topology.incomingSources[nodeB] == [nodeA])
        #expect(topology.connectedNodes == [nodeA, nodeB])
        #expect(topology.outgoingTargets[nodeB] == nil)
        #expect(topology.incomingSources[nodeA] == nil)
    }

    @Test("Multiple edges from same source accumulate targets")
    func testFanOut() {
        let edges = [
            Edge(string: "e1", from: "a", to: "b"),
            Edge(string: "e2", from: "a", to: "c"),
        ]
        let topology = GraphTopology(edges: edges)

        let nodeA = Node(string: "a")
        let nodeB = Node(string: "b")
        let nodeC = Node(string: "c")

        #expect(topology.outgoingTargets[nodeA] == [nodeB, nodeC])
        #expect(topology.incomingSources[nodeB] == [nodeA])
        #expect(topology.incomingSources[nodeC] == [nodeA])
    }

    @Test("Multiple edges to same target accumulate sources")
    func testFanIn() {
        let edges = [
            Edge(string: "e1", from: "a", to: "c"),
            Edge(string: "e2", from: "b", to: "c"),
        ]
        let topology = GraphTopology(edges: edges)

        let nodeA = Node(string: "a")
        let nodeB = Node(string: "b")
        let nodeC = Node(string: "c")

        #expect(topology.incomingSources[nodeC] == [nodeA, nodeB])
        #expect(topology.outgoingTargets[nodeA] == [nodeC])
        #expect(topology.outgoingTargets[nodeB] == [nodeC])
    }

    /// Hover highlighting and edge redirects walk these lists, and both write
    /// their results out in the order they walk — so the order is contract.
    @Test("Edges touching a node come back in the order given, from either end")
    func testIncidentEdgesInDocumentOrder() {
        let e1 = Edge(string: "e1", from: "b", to: "a")
        let e2 = Edge(string: "e2", from: "a", to: "c")
        let e3 = Edge(string: "e3", from: "d", to: "a")
        let unrelated = Edge(string: "e4", from: "c", to: "d")
        let topology = GraphTopology(edges: [e1, unrelated, e2, e3])

        let nodeA = Node(string: "a")
        #expect(topology.incidentEdges(of: nodeA) == [e1, e2, e3])
        #expect(topology.incomingEdges(of: nodeA) == [e1, e3])
        #expect(topology.outgoingEdges(of: nodeA) == [e2])
    }

    @Test("Parallel edges are each listed, unlike the neighbour sets")
    func testParallelEdgesKept() {
        let e1 = Edge(string: "e1", from: "a", to: "b")
        let e2 = Edge(string: "e2", from: "a", to: "b")
        let topology = GraphTopology(edges: [e1, e2])

        let nodeA = Node(string: "a")
        let nodeB = Node(string: "b")
        #expect(topology.outgoingEdges(of: nodeA) == [e1, e2])
        #expect(topology.incomingEdges(of: nodeB) == [e1, e2])
        #expect(topology.outgoingTargets[nodeA] == [nodeB])
    }

    @Test("A self-loop touches its node once and counts as both in and out")
    func testSelfLoop() {
        let loop = Edge(string: "e1", from: "a", to: "a")
        let topology = GraphTopology(edges: [loop])

        let nodeA = Node(string: "a")
        #expect(topology.incidentEdges(of: nodeA) == [loop])
        #expect(topology.incomingEdges(of: nodeA) == [loop])
        #expect(topology.outgoingEdges(of: nodeA) == [loop])
    }

    @Test("A node without edges has none")
    func testUnknownNode() {
        let topology = GraphTopology(edges: [Edge(string: "e1", from: "a", to: "b")])
        let nodeZ = Node(string: "z")
        #expect(topology.incidentEdges(of: nodeZ).isEmpty)
        #expect(topology.incomingEdges(of: nodeZ).isEmpty)
        #expect(topology.outgoingEdges(of: nodeZ).isEmpty)
    }
}

// MARK: - Mapped Relations Tests

@Suite("Mapped Relations Quality Check")
struct MappedRelationsTests {

    typealias CM = Notations.ConceptMap

    private func createConceptMapGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        graph = graph.using(notation: "ConceptMap")
        return graph
    }

    private func addConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.concept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEmphasizedConcept(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.emphasizedConcept)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addRelation(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CM.NodeTypes.relation)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addEdge(id: String, from: String, to: String, type: EdgeType, in graph: VGraph) throws(VError) -> VGraph {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: type)
    }

    @Test("Multi-inbound and multi-outbound with overlap produces error")
    func testCircularPropositions() throws {
        // {Learning, Accountability} -> enables -> {Learning, Accountability}
        var graph = try createConceptMapGraph()
        graph = try addConcept("learning", label: "Learning", to: graph)
        graph = try addConcept("accountability", label: "Accountability", to: graph)
        graph = try addRelation("enables", label: "enables", to: graph)
        graph = try addEdge(id: "e1", from: "learning", to: "enables", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "accountability", to: "enables", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "enables", to: "learning", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e4", from: "enables", to: "accountability", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("circular") == true)
        #expect(messages.first?.message.contains("Learning") == true)
        #expect(messages.first?.message.contains("Accountability") == true)
    }

    @Test("Multi-inbound and multi-outbound without overlap produces warning")
    func testManyToManyNoOverlap() throws {
        // {Dog, Cat} -> has -> {Fur, Teeth}
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addRelation("has", label: "has", to: graph)
        graph = try addConcept("fur", label: "Fur", to: graph)
        graph = try addConcept("teeth", label: "Teeth", to: graph)
        graph = try addEdge(id: "e1", from: "dog", to: "has", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "cat", to: "has", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "has", to: "fur", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e4", from: "has", to: "teeth", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("4 propositions") == true)
    }

    @Test("Partial overlap produces error")
    func testPartialOverlap() throws {
        // {A, B} -> enables -> {B, C}  — B on both sides
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "A", to: graph)
        graph = try addConcept("b", label: "B", to: graph)
        graph = try addConcept("c", label: "C", to: graph)
        graph = try addRelation("enables", label: "enables", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "enables", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "b", to: "enables", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "enables", to: "b", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e4", from: "enables", to: "c", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("B") == true)
    }

    @Test("Single inbound, multi outbound produces no message")
    func testSingleInboundMultiOutbound() throws {
        // Font -> has -> {Weight, Style}
        var graph = try createConceptMapGraph()
        graph = try addConcept("font", label: "Font", to: graph)
        graph = try addRelation("has", label: "has", to: graph)
        graph = try addConcept("weight", label: "Weight", to: graph)
        graph = try addConcept("style", label: "Style", to: graph)
        graph = try addEdge(id: "e1", from: "font", to: "has", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "has", to: "weight", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e3", from: "has", to: "style", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.isEmpty)
    }

    @Test("Multi inbound, single outbound produces no message")
    func testMultiInboundSingleOutbound() throws {
        // {Dog, Cat} -> is_a -> Mammal
        var graph = try createConceptMapGraph()
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addRelation("is_a", label: "is a", to: graph)
        graph = try addConcept("mammal", label: "Mammal", to: graph)
        graph = try addEdge(id: "e1", from: "dog", to: "is_a", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "cat", to: "is_a", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "is_a", to: "mammal", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.isEmpty)
    }

    @Test("EmphasizedConcept in overlap produces error")
    func testEmphasizedConceptOverlap() throws {
        // {EmphasizedA, B} -> enables -> {EmphasizedA, C}
        var graph = try createConceptMapGraph()
        graph = try addEmphasizedConcept("a", label: "Key Concept", to: graph)
        graph = try addConcept("b", label: "B", to: graph)
        graph = try addConcept("c", label: "C", to: graph)
        graph = try addRelation("enables", label: "enables", to: graph)
        graph = try addEdge(id: "e1", from: "a", to: "enables", type: CM.EdgeTypes.emphasizedConceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "b", to: "enables", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "enables", to: "a", type: CM.EdgeTypes.relationToEmphasizedConcept, in: graph)
        graph = try addEdge(id: "e4", from: "enables", to: "c", type: CM.EdgeTypes.relationToConcept, in: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("Key Concept") == true)
    }

    @Test("Composite check aggregates all sub-check messages")
    func testCompositeAggregation() throws {
        // Graph with: an orphan concept + a mapped relation
        var graph = try createConceptMapGraph()
        graph = try addConcept("orphan", label: "Orphan", to: graph)
        graph = try addConcept("dog", label: "Dog", to: graph)
        graph = try addConcept("cat", label: "Cat", to: graph)
        graph = try addRelation("has", label: "has", to: graph)
        graph = try addConcept("fur", label: "Fur", to: graph)
        graph = try addConcept("teeth", label: "Teeth", to: graph)
        graph = try addEdge(id: "e1", from: "dog", to: "has", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e2", from: "cat", to: "has", type: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try addEdge(id: "e3", from: "has", to: "fur", type: CM.EdgeTypes.relationToConcept, in: graph)
        graph = try addEdge(id: "e4", from: "has", to: "teeth", type: CM.EdgeTypes.relationToConcept, in: graph)

        let messages = CM.relationTopologyChecks(graph)
        let orphanMessages = messages.filter { $0.message.contains("Orphan") }
        #expect(!orphanMessages.isEmpty)
        let mappedMessages = messages.filter { $0.message.contains("4 propositions") }
        #expect(!mappedMessages.isEmpty)
    }

    @Test("No relation nodes produces no mapped relations messages")
    func testNoRelations() throws {
        var graph = try createConceptMapGraph()
        graph = try addConcept("a", label: "Dog", to: graph)

        let topology = GraphTopology(edges: graph.edges)
        let messages = CM.mappedRelations(graph, topology: topology)
        #expect(messages.isEmpty)
    }
}

// MARK: - Cycle Analysis Tests

@Suite("CycleAnalysis")
struct CycleAnalysisTests {

    typealias CLD = Notations.CausalLoopDiagram

    private func createCLDGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        graph = graph.using(notation: "CLD")
        return graph
    }

    private func addStock(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CLD.NodeTypes.stock)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addSameEdge(id: String, from: String, to: String, in graph: VGraph) throws(VError) -> VGraph {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CLD.EdgeTypes.same)
    }

    @Test("Acyclic graph has no cycles")
    func testAcyclicGraph() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "c", in: graph)

        let result = CycleAnalysis.analyze(graph)
        #expect(result.cycles.isEmpty)
    }

    @Test("Simple cycle A→B→C→A detected")
    func testSimpleCycle() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "c", in: graph)
        graph = try addSameEdge(id: "e3", from: "c", to: "a", in: graph)

        let result = CycleAnalysis.analyze(graph)
        #expect(result.cycles.count == 1)
        #expect(result.cycles[0].count == 3)
    }

    @Test("Multiple independent cycles detected")
    func testMultipleCycles() throws {
        // Cycle 1: A→B→A, Cycle 2: C→D→C
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addStock("d", label: "D", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "a", in: graph)
        graph = try addSameEdge(id: "e3", from: "c", to: "d", in: graph)
        graph = try addSameEdge(id: "e4", from: "d", to: "c", in: graph)

        let result = CycleAnalysis.analyze(graph)
        #expect(result.cycles.count == 2)
    }

    @Test("Graph with no edges has no cycles")
    func testNoEdges() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)

        let result = CycleAnalysis.analyze(graph)
        #expect(result.cycles.isEmpty)
    }

    @Test("Cycle edges contain correct domain Edge values")
    func testCycleEdgeValues() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "a", in: graph)

        let result = CycleAnalysis.analyze(graph)
        #expect(result.cycles.count == 1)
        let cycle = result.cycles[0]
        let fromNodes = Set(cycle.map { $0.from })
        let toNodes = Set(cycle.map { $0.to })
        #expect(fromNodes == [Node(string: "a"), Node(string: "b")])
        #expect(toNodes == [Node(string: "a"), Node(string: "b")])
    }

    @Test("GraphAnalysis typealias works with CycleAnalysis")
    func testGraphAnalysisInterface() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "a", in: graph)

        let analysis: GraphAnalysis<CycleAnalysis> = CycleAnalysis.analyze
        let result = analysis(graph)
        #expect(result.cycles.count == 1)
    }
}

// MARK: - Loop Direction Tests

@Suite("TLoop Direction")
struct TLoopDirectionTests {

    typealias CLD = Notations.CausalLoopDiagram

    private func createCLDGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        graph = graph.using(notation: "CLD")
        return graph
    }

    private func addStock(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: CLD.NodeTypes.stock)
        result = try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addSameEdge(id: String, from: String, to: String, in graph: VGraph) throws(VError) -> VGraph {
        let edge = Edge(string: id, from: from, to: to)
        return try graph.add(edge: edge, edgeType: CLD.EdgeTypes.same)
    }

    private func setPosition(_ nodeId: String, x: Double, y: Double, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: nodeId)
        return try graph.set(
            node: node,
            attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: x, y: y))
        )
    }

    @Test("Counter-clockwise triangle detected as counter-clockwise")
    func testCounterClockwiseTriangle() throws {
        // In y-up (Cartesian/Graphviz) coordinates:
        // A(0,2) top, B(2,0) bottom-right, C(-2,0) bottom-left
        // Edges: A→B→C→A traverses counter-clockwise (top → right → left)
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "c", in: graph)
        graph = try addSameEdge(id: "e3", from: "c", to: "a", in: graph)

        graph = try setPosition("a", x: 0, y: 2, in: graph)
        graph = try setPosition("b", x: 2, y: 0, in: graph)
        graph = try setPosition("c", x: -2, y: 0, in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) == .counterClockwise)
    }

    @Test("Clockwise triangle detected as clockwise")
    func testClockwiseTriangle() throws {
        // Same positions but edges reversed: A→C→B→A traverses clockwise (top → left → right)
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "c", in: graph)
        graph = try addSameEdge(id: "e2", from: "c", to: "b", in: graph)
        graph = try addSameEdge(id: "e3", from: "b", to: "a", in: graph)

        graph = try setPosition("a", x: 0, y: 2, in: graph)
        graph = try setPosition("b", x: 2, y: 0, in: graph)
        graph = try setPosition("c", x: -2, y: 0, in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) == .clockwise)
    }

    @Test("Counter-clockwise square detected as counter-clockwise")
    func testCounterClockwiseSquare() throws {
        // Square in y-up: A(0,1) top, B(1,0) right, C(0,-1) bottom, D(-1,0) left
        // Edges: A→B→C→D→A traverses counter-clockwise (top → right → bottom → left)
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addStock("d", label: "D", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "c", in: graph)
        graph = try addSameEdge(id: "e3", from: "c", to: "d", in: graph)
        graph = try addSameEdge(id: "e4", from: "d", to: "a", in: graph)

        graph = try setPosition("a", x: 0, y: 1, in: graph)
        graph = try setPosition("b", x: 1, y: 0, in: graph)
        graph = try setPosition("c", x: 0, y: -1, in: graph)
        graph = try setPosition("d", x: -1, y: 0, in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) == .counterClockwise)
    }

    private func setEdgeLayout(_ edgeId: String, start: VPoint, end: VPoint, in graph: VGraph) throws(VError) -> VGraph {
        let layoutData = EdgeLayoutData(splinePoints: [start, end])
        return try graph.set(
            edge: Edge.Id(string: edgeId),
            attribute: Attributes.Edge.layoutData.attribute(layoutData)
        )
    }

    @Test("Two-node cycle uses edge endpoints to determine direction")
    func testTwoNodeCycle() throws {
        // Node centers form a degenerate line (zero Shoelace area).
        // Edge endpoints are offset to the node borders, forming a quadrilateral.
        // e1 goes above the center line (A top-right → B top-left),
        // e2 goes below (B bottom-right → A bottom-left) → clockwise on screen.
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "a", in: graph)

        // Edge e1 curves above: starts at A's upper-right border, ends at B's upper-left
        graph = try setEdgeLayout("e1", start: VPoint(x: 1, y: 0.5), end: VPoint(x: 3, y: 0.5), in: graph)
        // Edge e2 curves below: starts at B's lower-right border, ends at A's lower-left
        graph = try setEdgeLayout("e2", start: VPoint(x: 3, y: -0.5), end: VPoint(x: 1, y: -0.5), in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) != .error, "Two-node cycle with edge layout must not return .error")
    }

    @Test("Two-node cycle without edge layout falls back to error for 2 nodes")
    func testTwoNodeCycleNoLayout() throws {
        // Without edge layout data, 2 node positions form a degenerate polygon
        // (< 3 vertices), so the method correctly returns .error.
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "a", in: graph)

        graph = try setPosition("a", x: 0, y: 0, in: graph)
        graph = try setPosition("b", x: 4, y: 0, in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) == .error)
    }

    @Test("Missing positions returns error")
    func testMissingPositions() throws {
        var graph = try createCLDGraph()
        graph = try addStock("a", label: "A", to: graph)
        graph = try addStock("b", label: "B", to: graph)
        graph = try addStock("c", label: "C", to: graph)
        graph = try addSameEdge(id: "e1", from: "a", to: "b", in: graph)
        graph = try addSameEdge(id: "e2", from: "b", to: "c", in: graph)
        graph = try addSameEdge(id: "e3", from: "c", to: "a", in: graph)

        let cycles = CycleAnalysis.analyze(graph).cycles
        let loops = TLoop.fromCycles(cycles, getter: graph)
        #expect(loops.count == 1)
        #expect(loops[0].loopDirection(in: graph) == .error)
    }
}
