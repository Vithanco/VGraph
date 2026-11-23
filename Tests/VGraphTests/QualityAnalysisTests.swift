import TestSupport
import Testing

@testable import VGraph

private typealias CM = Notations.ConceptMap

enum CMKind {
    case concept, emphasized, relation
}

/// Edge types follow from the endpoint kinds, so a fixture lists nodes and links only.
private func conceptMap(
    _ nodes: [(id: String, kind: CMKind, label: String)], links: [(String, String)] = []
) throws(VError) -> VGraph {
    var graph = VGraph()
    graph = try CM.addNotation(to: graph)
    graph = graph.using(notation: "ConceptMap")
    var kinds: [String: CMKind] = [:]
    for (id, kind, label) in nodes {
        kinds[id] = kind
        let type =
            switch kind {
            case .concept: CM.NodeTypes.concept
            case .emphasized: CM.NodeTypes.emphasizedConcept
            case .relation: CM.NodeTypes.relation
            }
        let node = Node(rawValue: id)
        graph = try graph.adding(node: node, type: type)
        graph = try graph.setting(node: node, attribute: Attributes.Node.label.attribute(label))
    }
    for (index, (from, to)) in links.enumerated() {
        let type =
            switch (kinds[from]!, kinds[to]!) {
            case (.concept, .relation): CM.EdgeTypes.conceptToRelation
            case (.emphasized, .relation): CM.EdgeTypes.emphasizedConceptToRelation
            case (.relation, .concept): CM.EdgeTypes.relationToConcept
            case (.relation, .emphasized): CM.EdgeTypes.relationToEmphasizedConcept
            default: preconditionFailure("ConceptMap links join a concept and a relation")
            }
        graph = try graph.adding(edge: Edge(string: "e\(index + 1)", from: from, to: to), edgeType: type)
    }
    return graph
}

private func concepts(_ labels: [String]) -> [(id: String, kind: CMKind, label: String)] {
    labels.enumerated().map { (id: "c\($0.offset)", kind: .concept, label: $0.element) }
}

private func topology(_ graph: VGraph) -> GraphTopology {
    GraphTopology(edges: graph.edges)
}

private func info(_ text: String) -> MessageWithSeverity {
    MessageWithSeverity(message: text, severity: .info)
}

@Suite("Generic Quality Checks")
struct GenericQualityChecksTests {

    @Test("A node without edges is flagged; connected nodes are not")
    func testDisconnectedNodeWarning() throws {
        let graph = try conceptMap(
            [("a", .concept, "Dog"), ("b", .concept, "Cat"), ("r1", .relation, "likes")],
            links: [("a", "r1")])

        let messages = GenericQualityChecks.disconnectedNodes(graph: graph)
        #expect(messages.map { $0.target } == [.node("b")])
        #expect(messages.first?.severity == .warning)
    }

    @Test("Unknown node type produces error")
    func testUnknownNodeTypeError() throws {
        var graph = try conceptMap([])
        graph = try graph.ensuringUnknownNodeType()
        let node = Node(rawValue: "bad_node")
        graph = try graph.adding(node: node, type: NodeType.unknown)
        graph = try graph.setting(node: node, attribute: Attributes.Node.label.attribute("Mystery"))

        let messages = GenericQualityChecks.unknownNodeTypes(graph: graph)
        #expect(!messages.isEmpty)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("unknown node type") == true)
    }

    @Test("Unknown edge type produces error")
    func testUnknownEdgeTypeError() throws {
        var graph = try conceptMap([("a", .concept, "Dog"), ("b", .concept, "Cat")])

        // Concept to concept is not an edge type ConceptMap declares.
        let unknownEdgeType = EdgeType.unknown(from: CM.NodeTypes.concept, to: CM.NodeTypes.concept)
        graph = try graph.adding(edgeType: unknownEdgeType)
        graph = try graph.adding(edge: Edge(string: "bad_edge", from: "a", to: "b"), edgeType: unknownEdgeType)

        let messages = GenericQualityChecks.unknownEdgeTypes(graph: graph)
        #expect(!messages.isEmpty)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.message.contains("invalid edge type") == true)
    }

    @Test("OrJunctor in sufficient-cause notation produces redundancy warning")
    func testRedundantOrJunctorUnderSufficientCause() throws {
        // PrerequisiteTree is necessary-condition by default and registers OrJunctor;
        // override the diagram logic to sufficient-cause to provoke the redundancy warning.
        var graph = VGraph()
        graph = try Notations.PrerequisiteTree.addNotation(to: graph)
        graph = try graph.setting(graphAttribute: Attributes.Group.diagramLogic.attribute(.sufficientCause))

        let or = Node(rawValue: "or1")
        graph = try graph.adding(node: or, type: Notations.PrerequisiteTree.NodeTypes.orJunctor)
        graph = try graph.setting(node: or, attribute: Attributes.Node.label.attribute("alt"))

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
        var graph = VGraph()
        graph = try Notations.CurrentRealityTree.addNotation(to: graph)
        graph = try graph.setting(graphAttribute: Attributes.Group.diagramLogic.attribute(.necessaryCondition))

        let and = Node(rawValue: "and1")
        graph = try graph.adding(node: and, type: Notations.CurrentRealityTree.NodeTypes.andJunctor)
        graph = try graph.setting(node: and, attribute: Attributes.Node.label.attribute("combo"))

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("AndJunctor") == true)
        #expect(messages.first?.message.contains("implicit AND") == true)
    }

    @Test("AndJunctor under sufficient-cause logic is fine (no warning)")
    func testAndJunctorUnderSufficientCauseIsFine() throws {
        var graph = VGraph()
        graph = try Notations.CurrentRealityTree.addNotation(to: graph)

        let and = Node(rawValue: "and1")
        graph = try graph.adding(node: and, type: Notations.CurrentRealityTree.NodeTypes.andJunctor)

        let messages = GenericQualityChecks.redundantJunctor(graph: graph)
        #expect(messages.isEmpty)
    }

    @Test("noLogic notation skips the junctor redundancy check", arguments: [true, false])
    func testNoLogicSkipsCheck(orJunctor: Bool) throws {
        var graph = VGraph()
        let node = Node(rawValue: "j1")
        if orJunctor {
            graph = try Notations.PrerequisiteTree.addNotation(to: graph)
            graph = try graph.adding(node: node, type: Notations.PrerequisiteTree.NodeTypes.orJunctor)
        } else {
            graph = try Notations.CurrentRealityTree.addNotation(to: graph)
            graph = try graph.adding(node: node, type: Notations.CurrentRealityTree.NodeTypes.andJunctor)
        }
        graph = try graph.setting(graphAttribute: Attributes.Group.diagramLogic.attribute(.noLogic))

        #expect(GenericQualityChecks.redundantJunctor(graph: graph).isEmpty)
    }
}

@Suite("ConceptMap Quality Checks")
struct ConceptMapQualityChecksTests {

    struct RatioRow: Sendable {
        let nodes: [(id: String, kind: CMKind, label: String)]
        let expected: [MessageWithSeverity]
    }

    @Test(
        "Concept/relation ratio is reported as info, to two decimals, emphasized concepts counted",
        arguments: [
            RatioRow(
                nodes: [("a", .concept, "Dog"), ("b", .concept, "Cat"), ("r1", .relation, "likes")],
                expected: [info("Concepts: 2, Relations: 1, Ratio: 0.50")]),
            RatioRow(
                nodes: [
                    ("a", .concept, "Dog"), ("b", .concept, "Cat"), ("c", .concept, "Animal"),
                    ("r1", .relation, "is a"), ("r2", .relation, "likes"),
                ],
                expected: [info("Concepts: 3, Relations: 2, Ratio: 0.67")]),
            RatioRow(
                nodes: [("a", .concept, "Dog"), ("b", .emphasized, "Cat"), ("r1", .relation, "likes")],
                expected: [info("Concepts: 2, Relations: 1, Ratio: 0.50")]),
            RatioRow(nodes: [("r1", .relation, "likes")], expected: []),
        ])
    func testConceptRelationRatio(row: RatioRow) throws {
        #expect(CM.conceptRelationRatio(try conceptMap(row.nodes)) == row.expected)
    }

    @Test(
        "Concept count warns below 5 and above 25 concepts, emphasized ones counted",
        arguments: [
            (0, nil), (1, "Only 1 concepts — consider adding more to fully explore the guiding question"),
            (4, "Only 4 concepts — consider adding more to fully explore the guiding question"),
            (5, nil), (25, nil),
            (26, "26 concepts — consider splitting into sub-maps for readability"),
        ] as [(Int, String?)])
    func testConceptCount(count: Int, expected: String?) throws {
        // The last concept is emphasized: it must count like the others.
        var nodes = concepts((0..<max(count - 1, 0)).map { "C\($0)" })
        if count > 0 { nodes.append((id: "last", kind: .emphasized, label: "Last")) }
        let messages = CM.conceptCountCheck(try conceptMap(nodes))
        #expect(messages == expected.map { [MessageWithSeverity(message: $0, severity: .warning)] } ?? [])
    }

    @Test("Concept labels of four or more words warn; shorter ones and relation labels do not")
    func testLabelLengthWarning() throws {
        let graph = try conceptMap([
            ("long", .concept, "A Very Long Name"), ("short", .concept, "Big Fat Cat"),
            ("emph", .emphasized, "One Two Three"), ("r1", .relation, "is much more than"),
        ])

        #expect(
            CM.labelLengthCheck(graph) == [
                MessageWithSeverity(
                    message: "Node \"A Very Long Name\" has 4 words (recommended: 3 or fewer)", severity: .warning,
                    target: .node("long"))
            ])
    }

    @Test(
        "Vague relation labels warn, whatever their case; concepts with such labels do not",
        arguments: [
            ("relates to", true), ("Relates To", true), ("chases", false),
        ])
    func testVagueRelations(label: String, flagged: Bool) throws {
        let graph = try conceptMap([("r1", .relation, label), ("c1", .concept, "relates to")])

        #expect(
            CM.vagueRelationsCheck(graph)
                == (flagged
                    ? [
                        MessageWithSeverity(
                            message:
                                "Relation \"\(label)\" is too vague — use a specific verb that forms a falsifiable proposition",
                            severity: .warning, target: .node("r1"))
                    ] : []))
    }

    @Test("Only concepts without edges are unconnected; an edgeless relation is not one")
    func testUnconnectedConcept() throws {
        let graph = try conceptMap(
            [
                ("a", .concept, "Dog"), ("orphan", .concept, "Orphan"), ("r1", .relation, "is"),
                ("lonely", .relation, "lonely"),
            ], links: [("a", "r1")])

        #expect(
            CM.unconnectedConcepts(graph, topology: topology(graph)) == [
                MessageWithSeverity(
                    message: "Concept \"Orphan\" is not connected to any relation", severity: .warning,
                    target: .node("orphan"))
            ])
    }

    @Test(
        "Disconnected clusters warn once there are two; a lone concept is not a cluster",
        arguments: [
            (links: [("a", "r1"), ("r1", "b"), ("c", "r2"), ("r2", "d")], expected: 2),
            (links: [("a", "r1"), ("r1", "b"), ("c", "r1"), ("r1", "d")], expected: 0),
            (links: [("a", "r1"), ("r1", "b")], expected: 0),
        ])
    func testOrphanClusters(links: [(String, String)], expected: Int) throws {
        let graph = try conceptMap(
            [
                ("a", .concept, "Dog"), ("b", .concept, "Cat"), ("c", .concept, "Fish"), ("d", .concept, "Bird"),
                ("r1", .relation, "likes"), ("r2", .relation, "chases"),
            ], links: links)

        let messages = CM.orphanClusters(graph, topology: topology(graph))
        #expect(
            messages
                == (expected == 0
                    ? []
                    : [
                        MessageWithSeverity(
                            message:
                                "Map has \(expected) disconnected clusters — consider connecting them or splitting into separate maps",
                            severity: .warning)
                    ]))
    }

    @Test("Propositions in both directions between a pair warn once; one direction does not")
    func testRedundantPropositions() throws {
        let nodes: [(id: String, kind: CMKind, label: String)] = [
            ("a", .concept, "Dog"), ("b", .concept, "Cat"),
            ("r1", .relation, "chases"), ("r2", .relation, "is chased by"),
        ]
        let both = try conceptMap(nodes, links: [("a", "r1"), ("r1", "b"), ("b", "r2"), ("r2", "a")])
        let messages = CM.redundantPropositions(both, topology: topology(both))
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("linked in both directions") == true)
        #expect(messages.first?.message.contains("chases") == true)
        #expect(messages.first?.message.contains("is chased by") == true)

        let oneWay = try conceptMap(nodes, links: [("a", "r1"), ("r1", "b"), ("a", "r2"), ("r2", "b")])
        #expect(CM.redundantPropositions(oneWay, topology: topology(oneWay)).isEmpty)
    }

    @Test("Two-way links are reported in document order, each named the way it was first drawn")
    func redundantPropositionsInDocumentOrder() throws {
        let pairs = ["Dog", "Cat", "Fish", "Bird", "Cow", "Hen"]
        let concepts: [(id: String, kind: CMKind, label: String)] = pairs.map { (id: $0, kind: .concept, label: $0) }
        let relations: [(id: String, kind: CMKind, label: String)] = pairs.indices.map {
            (id: "r\($0)", kind: .relation, label: "rel\($0)")
        }
        let nodes = concepts + relations
        let links: [(String, String)] = stride(from: 0, to: pairs.count, by: 2).flatMap { (i: Int) -> [(String, String)] in
            let forward = "r\(i)"
            let backward = "r\(i + 1)"
            return [(pairs[i], forward), (forward, pairs[i + 1]), (pairs[i + 1], backward), (backward, pairs[i])]
        }
        let graph = try conceptMap(nodes, links: links)

        let messages = CM.redundantPropositions(graph, topology: topology(graph)).map { $0.message }

        let expected = stride(from: 0, to: pairs.count, by: 2).map { (i: Int) -> String in
            let names = "\"\(pairs[i])\" and \"\(pairs[i + 1])\""
            return "\(names) are linked in both directions (rel\(i) / rel\(i + 1)) — keep only the more meaningful direction"
        }
        #expect(messages == expected)
    }

    @Test("Relations sharing a label and targets are reported in label order")
    func unreusedRelationsInLabelOrder() throws {
        let labels = ["is a", "has", "eats", "likes", "owns", "needs"]
        let nodes: [(id: String, kind: CMKind, label: String)] =
            [(id: "a", kind: .concept, label: "Dog"), (id: "b", kind: .concept, label: "Cat")]
            + labels.indices.flatMap { (i: Int) -> [(id: String, kind: CMKind, label: String)] in
                [(id: "r\(i)x", kind: .relation, label: labels[i]), (id: "r\(i)y", kind: .relation, label: labels[i])]
            }
        let links: [(String, String)] = labels.indices.flatMap { (i: Int) -> [(String, String)] in
            [("r\(i)x", "b"), ("r\(i)y", "b")]
        }
        let graph = try conceptMap(nodes, links: links)

        let messages = CM.unreusedRelations(graph, topology: topology(graph)).map { $0.message }

        #expect(
            messages
                == labels.sorted().map {
                    "Relations with label \"\($0)\" appear 2 times with same targets -- consider reusing a single relation node"
                })
    }

    struct IncompleteRow: Sendable {
        let links: [(String, String)]
        let expected: String?
    }

    @Test(
        "A relation needs a concept on each side",
        arguments: [
            IncompleteRow(
                links: [], expected: "Relation \"likes\" has no incoming or outgoing concepts — it forms no proposition"),
            IncompleteRow(
                links: [("r1", "a")], expected: "Relation \"likes\" has no incoming concept — proposition has no source"),
            IncompleteRow(
                links: [("a", "r1")], expected: "Relation \"likes\" has no outgoing concept — proposition has no target"),
            IncompleteRow(links: [("a", "r1"), ("r1", "b")], expected: nil),
        ])
    func testIncompleteRelations(row: IncompleteRow) throws {
        let graph = try conceptMap(
            [("a", .concept, "Dog"), ("b", .concept, "Cat"), ("r1", .relation, "likes")], links: row.links)

        #expect(
            CM.incompleteRelations(graph, topology: topology(graph))
                == (row.expected.map {
                    [MessageWithSeverity(message: $0, severity: .error, target: .node("r1"))]
                } ?? []))
    }

    @Test(
        "Relations with one label warn only when their targets are the same",
        arguments: [("c", true), ("d", false)])
    func testUnreusedRelations(secondTarget: String, flagged: Bool) throws {
        let graph = try conceptMap(
            [
                ("a", .concept, "Dog"), ("b", .concept, "Cat"), ("c", .concept, "Mammal"),
                ("d", .concept, "Pet"), ("r1", .relation, "is a"), ("r2", .relation, "is a"),
            ], links: [("a", "r1"), ("r1", "c"), ("b", "r2"), ("r2", secondTarget)])

        #expect(
            CM.unreusedRelations(graph, topology: topology(graph))
                == (flagged
                    ? [
                        MessageWithSeverity(
                            message:
                                "Relations with label \"is a\" appear 2 times with same targets -- consider reusing a single relation node",
                            severity: .warning)
                    ] : []))
    }
}

@Suite("IBIS Quality Checks")
struct IBISQualityChecksTests {

    typealias IB = Notations.Ibis

    private func createIBISGraph() throws(VError) -> VGraph {
        var graph = VGraph()
        graph = try IB.addNotation(to: graph)
        graph = graph.using(notation: "IBIS")
        return graph
    }

    private func addQuestion(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(rawValue: id)
        var result = try graph.adding(node: node, type: IB.NodeTypes.question)
        result = try result.setting(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    private func addAnswer(_ id: String, label: String, to graph: VGraph) throws(VError) -> VGraph {
        let node = Node(rawValue: id)
        var result = try graph.adding(node: node, type: IB.NodeTypes.answer)
        result = try result.setting(node: node, attribute: Attributes.Node.label.attribute(label))
        return result
    }

    @Test("analyzeQuality runs the IBIS notation checks: tree structure and unanswered questions")
    func testNotationChecksRunViaAnalyzeQuality() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Question 1", to: graph)
        graph = try addQuestion("q2", label: "Question 2", to: graph)
        graph = try addQuestion("q3", label: "Lonely Question", to: graph)
        graph = try addAnswer("a1", label: "Answer", to: graph)
        // Both questions point to the same answer (2 parents)
        graph = try graph.adding(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )
        graph = try graph.adding(
            edge: Edge(string: "e2", from: "q2", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let warnings = Notations.analyzeQuality(graph: graph).warnings
        let parentWarnings = warnings.filter { $0.message.contains("parent nodes") }
        #expect(parentWarnings.count == 1)
        #expect(parentWarnings.first?.message.contains("\"Answer\" has 2 parent nodes") == true)
        let unanswered = warnings.filter { $0.message.contains("no Answer") }
        #expect(unanswered.map { $0.target } == [.node("q3")])
        #expect(unanswered.first?.message.contains("Lonely Question") == true)
    }

    @Test("Only unanswered Questions are flagged, answered ones are not")
    func testMixedAnsweredAndUnanswered() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Has Answer", to: graph)
        graph = try addQuestion("q2", label: "No Answer", to: graph)
        graph = try addAnswer("a1", label: "Answer 1", to: graph)
        graph = try graph.adding(
            edge: Edge(string: "e1", from: "q1", to: "a1"),
            edgeType: IB.EdgeTypes.questionToAnswer
        )

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.map { $0.target } == [.node("q2")])
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message.contains("No Answer") == true)
    }

    @Test("A sub-Question is not an Answer")
    func testSubQuestionDoesNotAnswer() throws {
        var graph = try createIBISGraph()
        graph = try addQuestion("q1", label: "Parent", to: graph)
        graph = try addQuestion("q2", label: "Child", to: graph)
        graph = try graph.adding(
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
        graph = try graph.adding(
            edge: Edge(string: "e1", from: "a1", to: "q1"),
            edgeType: IB.EdgeTypes.answerToQuestion
        )

        let messages = IB.unansweredQuestions(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("q1"))
    }
}

/// Through `analyzeQuality`, so the table also proves that GoalTree's checks are wired in.
@Suite("GoalTree Quality Checks")
struct GoalTreeQualityChecksTests {

    typealias GT = Notations.GoalTree

    private func goalTree(goals: Int, csfs: Int) throws(VError) -> VGraph {
        var graph = VGraph()
        graph = try GT.addNotation(to: graph)
        graph = graph.using(notation: "GoalTree")
        for (prefix, count, type) in [("g", goals, GT.NodeTypes.goal), ("csf", csfs, GT.NodeTypes.criticalSuccessFactor)] {
            for index in 0..<count {
                let node = Node(rawValue: "\(prefix)\(index)")
                graph = try graph.adding(node: node, type: type)
                graph = try graph.setting(node: node, attribute: Attributes.Node.label.attribute("\(prefix) \(index)"))
            }
        }
        return graph
    }

    @Test(
        "A Goal Tree needs exactly one Goal",
        arguments: [
            (0, ["Expected exactly 1 Goal node but found none"]),
            (1, []),
            (2, ["Expected exactly 1 Goal node but found 2"]),
        ] as [(Int, [String])])
    func testExactlyOneGoal(goals: Int, expected: [String]) throws {
        let errors = Notations.analyzeQuality(graph: try goalTree(goals: goals, csfs: 3)).errors
        #expect(errors.map { $0.message }.filter { $0.contains("Goal node") } == expected)
    }

    @Test(
        "3 to 5 Critical Success Factors are recommended",
        arguments: [
            (2, ["Goal Tree has 2 Critical Success Factors (recommended: 3-5)"]),
            (3, []), (5, []),
            (6, ["Goal Tree has 6 Critical Success Factors (recommended: 3-5)"]),
        ] as [(Int, [String])])
    func testCSFCount(csfs: Int, expected: [String]) throws {
        let infos = Notations.analyzeQuality(graph: try goalTree(goals: 1, csfs: csfs)).infos
        #expect(infos.map { $0.message }.filter { $0.contains("Critical Success Factors") } == expected)
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

        let nodeA = Node(rawValue: "a")
        let nodeB = Node(rawValue: "b")

        #expect(topology.outgoingTargets[nodeA] == [nodeB])
        #expect(topology.incomingSources[nodeB] == [nodeA])
        #expect(topology.connectedNodes == [nodeA, nodeB])
        #expect(topology.outgoingTargets[nodeB] == nil)
        #expect(topology.incomingSources[nodeA] == nil)
    }

    @Test("Edges from one source accumulate targets, edges into one target accumulate sources")
    func testFanOutAndFanIn() {
        let edges = [
            Edge(string: "e1", from: "a", to: "b"),
            Edge(string: "e2", from: "a", to: "c"),
            Edge(string: "e3", from: "b", to: "c"),
        ]
        let topology = GraphTopology(edges: edges)

        let nodeA = Node(rawValue: "a")
        let nodeB = Node(rawValue: "b")
        let nodeC = Node(rawValue: "c")

        #expect(topology.outgoingTargets[nodeA] == [nodeB, nodeC])
        #expect(topology.outgoingTargets[nodeB] == [nodeC])
        #expect(topology.incomingSources[nodeB] == [nodeA])
        #expect(topology.incomingSources[nodeC] == [nodeA, nodeB])
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

        let nodeA = Node(rawValue: "a")
        #expect(topology.incidentEdges(of: nodeA) == [e1, e2, e3])
        #expect(topology.incomingEdges(of: nodeA) == [e1, e3])
        #expect(topology.outgoingEdges(of: nodeA) == [e2])
    }

    @Test("Parallel edges are each listed, unlike the neighbour sets")
    func testParallelEdgesKept() {
        let e1 = Edge(string: "e1", from: "a", to: "b")
        let e2 = Edge(string: "e2", from: "a", to: "b")
        let topology = GraphTopology(edges: [e1, e2])

        let nodeA = Node(rawValue: "a")
        let nodeB = Node(rawValue: "b")
        #expect(topology.outgoingEdges(of: nodeA) == [e1, e2])
        #expect(topology.incomingEdges(of: nodeB) == [e1, e2])
        #expect(topology.outgoingTargets[nodeA] == [nodeB])
    }

    @Test("A self-loop touches its node once and counts as both in and out")
    func testSelfLoop() {
        let loop = Edge(string: "e1", from: "a", to: "a")
        let topology = GraphTopology(edges: [loop])

        let nodeA = Node(rawValue: "a")
        #expect(topology.incidentEdges(of: nodeA) == [loop])
        #expect(topology.incomingEdges(of: nodeA) == [loop])
        #expect(topology.outgoingEdges(of: nodeA) == [loop])
    }

    @Test("A node without edges has none")
    func testUnknownNode() {
        let topology = GraphTopology(edges: [Edge(string: "e1", from: "a", to: "b")])
        let nodeZ = Node(rawValue: "z")
        #expect(topology.incidentEdges(of: nodeZ).isEmpty)
        #expect(topology.incomingEdges(of: nodeZ).isEmpty)
        #expect(topology.outgoingEdges(of: nodeZ).isEmpty)
    }
}

// MARK: - Mapped Relations Tests

@Suite("Mapped Relations Quality Check")
struct MappedRelationsTests {

    struct Row: Sendable {
        let name: String
        let nodes: [(id: String, kind: CMKind, label: String)]
        let links: [(String, String)]
        let expected: [MessageWithSeverity]
    }

    static let rows: [Row] = [
        Row(
            name: "full overlap is circular",
            nodes: [
                ("learning", .concept, "Learning"), ("accountability", .concept, "Accountability"),
                ("enables", .relation, "enables"),
            ],
            links: [
                ("learning", "enables"), ("accountability", "enables"), ("enables", "learning"),
                ("enables", "accountability"),
            ],
            expected: [
                MessageWithSeverity(
                    message:
                        "Relation \"enables\" has 2 inbound and 2 outbound concepts with circular propositions: Accountability, Learning appear(s) on both sides",
                    severity: .error, target: .node("enables"))
            ]),
        Row(
            name: "partial overlap is still circular",
            nodes: [
                ("a", .concept, "A"), ("b", .concept, "B"), ("c", .concept, "C"), ("enables", .relation, "enables"),
            ],
            links: [("a", "enables"), ("b", "enables"), ("enables", "b"), ("enables", "c")],
            expected: [
                MessageWithSeverity(
                    message:
                        "Relation \"enables\" has 2 inbound and 2 outbound concepts with circular propositions: B appear(s) on both sides",
                    severity: .error, target: .node("enables"))
            ]),
        Row(
            name: "many to many without overlap needs checking",
            nodes: [
                ("dog", .concept, "Dog"), ("cat", .concept, "Cat"), ("has", .relation, "has"),
                ("fur", .concept, "Fur"), ("teeth", .concept, "Teeth"),
            ],
            links: [("dog", "has"), ("cat", "has"), ("has", "fur"), ("has", "teeth")],
            expected: [
                MessageWithSeverity(
                    message:
                        "Relation \"has\" has 2 inbound and 2 outbound concepts, creating 4 propositions -- verify all are valid",
                    severity: .warning, target: .node("has"))
            ]),
        Row(
            name: "one inbound, many outbound",
            nodes: [
                ("font", .concept, "Font"), ("has", .relation, "has"), ("weight", .concept, "Weight"),
                ("style", .concept, "Style"),
            ],
            links: [("font", "has"), ("has", "weight"), ("has", "style")],
            expected: []),
        Row(
            name: "many inbound, one outbound",
            nodes: [
                ("dog", .concept, "Dog"), ("cat", .concept, "Cat"), ("is_a", .relation, "is a"),
                ("mammal", .concept, "Mammal"),
            ],
            links: [("dog", "is_a"), ("cat", "is_a"), ("is_a", "mammal")],
            expected: []),
        Row(
            name: "a concept with two in and two out is not a relation",
            nodes: [
                ("c", .concept, "Hub"), ("r1", .relation, "r1"), ("r2", .relation, "r2"), ("r3", .relation, "r3"),
                ("r4", .relation, "r4"),
            ],
            links: [("r1", "c"), ("r2", "c"), ("c", "r3"), ("c", "r4")],
            expected: []),
    ]

    @Test("Relations with several concepts on both sides are flagged", arguments: rows)
    func testMappedRelations(row: Row) throws {
        let graph = try conceptMap(row.nodes, links: row.links)
        #expect(CM.mappedRelations(graph, topology: topology(graph)) == row.expected, "\(row.name)")
    }

    @Test("ConceptMap analyzeQuality runs every check")
    func testCompositeAggregation() throws {
        let graph = try conceptMap(
            [
                ("orphan", .concept, "Orphan"),
                ("dog", .concept, "Dog"), ("cat", .concept, "Cat"), ("has", .relation, "has"),
                ("fur", .concept, "Fur"), ("teeth", .concept, "Teeth"),
                ("x", .concept, "X"), ("y", .concept, "Y"), ("chases", .relation, "chases"),
                ("chased", .relation, "is chased by"),
                ("m", .concept, "Mammal"), ("p", .concept, "Pet"), ("q", .concept, "Quad"),
                ("is1", .relation, "is a"), ("is2", .relation, "is a"),
                ("dangling", .relation, "dangling"), ("vague", .relation, "relates to"),
            ],
            links: [
                ("dog", "has"), ("cat", "has"), ("has", "fur"), ("has", "teeth"),
                ("x", "chases"), ("chases", "y"), ("y", "chased"), ("chased", "x"),
                ("p", "is1"), ("is1", "m"), ("q", "is2"), ("is2", "m"), ("dog", "vague"), ("vague", "m"),
            ])

        let report = Notations.analyzeQuality(graph: graph)
        let messages = report.messages.map { $0.message }
        for phrase in [
            "Concept \"Orphan\" is not connected to any relation",
            "disconnected clusters",
            "linked in both directions",
            "consider reusing a single relation node",
            "creating 4 propositions",
            "Relation \"dangling\" has no incoming or outgoing concepts",
            "Relation \"relates to\" is too vague",
        ] {
            #expect(messages.contains { $0.contains(phrase) }, "missing: \(phrase)")
        }
        #expect(report.infos.contains { $0.message.hasPrefix("Concepts: ") })
        let tooFew = Notations.analyzeQuality(graph: try conceptMap([("a", .concept, "A")]))
        #expect(tooFew.warnings.contains { $0.message.hasPrefix("Only 1 concepts") })
    }

    @Test("A well-formed ConceptMap is clean")
    func testCleanMap() throws {
        let graph = try conceptMap(
            [
                ("a", .concept, "Dog"), ("b", .concept, "Cat"), ("c", .concept, "Fish"), ("d", .concept, "Bird"),
                ("e", .concept, "Animal"), ("r1", .relation, "likes"), ("r2", .relation, "is a"),
                ("r3", .relation, "chases"), ("r4", .relation, "sees"),
            ],
            links: [
                ("a", "r1"), ("r1", "b"), ("b", "r2"), ("r2", "e"), ("c", "r3"), ("r3", "d"), ("d", "r4"),
                ("r4", "e"),
            ])

        #expect(Notations.analyzeQuality(graph: graph).isClean)
    }
}

// MARK: - Loop Direction Tests

/// Layout positions are screen coordinates: y grows downward, as the overlay draws them.
@Suite("FeedbackLoop Direction")
struct FeedbackLoopDirectionTests {

    typealias CLD = Notations.CausalLoopDiagram

    private func cld(_ ids: [String], _ links: [(String, String)]) throws(VError) -> VGraph {
        var graph = VGraph()
        graph = try CLD.addNotation(to: graph)
        graph = graph.using(notation: "CLD")
        for id in ids {
            let node = Node(rawValue: id)
            graph = try graph.adding(node: node, type: CLD.NodeTypes.stock)
            graph = try graph.setting(node: node, attribute: Attributes.Node.label.attribute(id.uppercased()))
        }
        for (index, (from, to)) in links.enumerated() {
            graph = try graph.adding(edge: Edge(string: "e\(index + 1)", from: from, to: to), edgeType: CLD.EdgeTypes.same)
        }
        return graph
    }

    private func place(_ positions: [String: (Double, Double)], in graph: VGraph) throws(VError) -> VGraph {
        var graph = graph
        for (id, position) in positions {
            graph = try graph.setting(
                node: Node(rawValue: id),
                attribute: Attributes.Node.layoutedPos.attribute(VPoint(x: position.0, y: position.1)))
        }
        return graph
    }

    private func direction(of graph: VGraph) -> LoopDirection? {
        let loops = graph.loopsToMark
        return loops.count == 1 ? loops[0].loopDirection(in: graph) : nil
    }

    private static let triangle: [String: (Double, Double)] = ["a": (0, 2), "b": (2, 0), "c": (-2, 0)]

    @Test("Bottom, top-right, top-left reads counter-clockwise on screen")
    func testCounterClockwiseTriangle() throws {
        let graph = try place(
            Self.triangle, in: try cld(["a", "b", "c"], [("a", "b"), ("b", "c"), ("c", "a")]))
        #expect(direction(of: graph) == .counterClockwise)
    }

    @Test("The same triangle walked the other way is clockwise")
    func testClockwiseTriangle() throws {
        let graph = try place(
            Self.triangle, in: try cld(["a", "b", "c"], [("a", "c"), ("c", "b"), ("b", "a")]))
        #expect(direction(of: graph) == .clockwise)
    }

    @Test("A two-node loop takes its direction from the edge endpoints")
    func testTwoNodeCycle() throws {
        // Node centres are collinear, so only the spline endpoints enclose any area:
        // e1 runs along the lower side left to right, e2 back along the upper side.
        var graph = try cld(["a", "b"], [("a", "b"), ("b", "a")])
        for (id, start, end) in [
            ("e1", VPoint(x: 1, y: 0.5), VPoint(x: 3, y: 0.5)), ("e2", VPoint(x: 3, y: -0.5), VPoint(x: 1, y: -0.5)),
        ] {
            graph = try graph.setting(
                edge: Edge.Id(rawValue: id),
                attribute: Attributes.Edge.layoutData.attribute(EdgeLayoutData(splinePoints: [start, end])))
        }
        #expect(direction(of: graph) == .counterClockwise)
    }

    @Test("A two-node loop without edge layout has no direction")
    func testTwoNodeCycleNoLayout() throws {
        let graph = try place(
            ["a": (0, 0), "b": (4, 0)], in: try cld(["a", "b"], [("a", "b"), ("b", "a")]))
        #expect(direction(of: graph) == .error)
    }

    @Test("A loop whose nodes have no positions has no direction")
    func testMissingPositions() throws {
        let graph = try cld(["a", "b", "c"], [("a", "b"), ("b", "c"), ("c", "a")])
        #expect(direction(of: graph) == .error)
    }
}
