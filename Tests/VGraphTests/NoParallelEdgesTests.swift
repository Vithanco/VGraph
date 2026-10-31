//
//  NoParallelEdgesTests.swift
//  VGraph
//
//  A graph criterion rather than a bound: it counts across every
//  edge type at once, which a bound declared on one edge type cannot. See
//  ADR-0011.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("noParallelEdges")
struct NoParallelEdgesTests {

    typealias CLD = Notations.CausalLoopDiagram

    private func causalLoopDiagram() throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        return graph.using(notation: "CausalLoopDiagram")
    }

    private func stock(_ id: String, _ label: String, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        let result = try graph.add(node: node, type: CLD.NodeTypes.stock)
        return try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
    }

    private func link(_ id: String, _ from: String, _ to: String, _ type: EdgeType, in graph: VGraph)
        throws(VError) -> VGraph
    {
        try graph.add(edge: Edge(string: id, from: from, to: to), edgeType: type)
    }

    private func check(_ graph: VGraph) -> [MessageWithSeverity] {
        QualityCheckRegistry.noParallelEdgesCheck(graph)
    }

    @Test("One link between two stocks is fine")
    func singleLinkPasses() throws {
        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)

        #expect(check(graph).isEmpty)
    }

    /// The case no [[Bound]] bound can express: `samePairMax: 1` on each of
    /// `same` and `opposite` still permits one of each, because each counts only
    /// its own type. This is the whole reason the criterion exists.
    @Test("Two links of different types between the same pair are caught")
    func differentTypesSamePairAreCaught() throws {
        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "a", "b", CLD.EdgeTypes.opposite, in: graph)

        let messages = check(graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        #expect(messages.first?.target == .edge(from: "a", to: "b"))
    }

    @Test("Links in opposite directions are a feedback loop, not a fault")
    func oppositeDirectionsPass() throws {
        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "b", "a", CLD.EdgeTypes.opposite, in: graph)

        #expect(check(graph).isEmpty)
    }

    @Test("A third link blames the second and the third")
    func onlyTheExtrasAreBlamed() throws {
        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "a", "b", CLD.EdgeTypes.opposite, in: graph)
        graph = try link("e3", "a", "b", CLD.EdgeTypes.same, in: graph)

        #expect(check(graph).count == 2)
    }

    @Test("The message names both stocks by their labels")
    func messageUsesLabels() throws {
        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "a", "b", CLD.EdgeTypes.opposite, in: graph)

        let message = try #require(check(graph).first?.message)
        #expect(message.contains("\"Rabbits\""))
        #expect(message.contains("\"Grass\""))
    }

    @Test("A notation reaches it by name")
    func resolvableFromVnotation() throws {
        let resolved = try QualityCheckRegistry.resolve(QualityCheckSpec(name: "noParallelEdges"))

        var graph = try causalLoopDiagram()
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "a", "b", CLD.EdgeTypes.opposite, in: graph)

        #expect(resolved(graph).count == 1)
    }

    /// The notations where a second link between the same two nodes, the same
    /// way, can only repeat or contradict the first. Arithmetic is out because
    /// `x + x` feeds one number into both operands; C4 because real architectures
    /// have several relationships between the same pair (ADR-0011).
    private let expectedAdopters: Set<String> = [
        "CLD", "CRT", "FRT", "TRT", "PRT", "EC", "GoalTree", "IBIS", "ConceptMap",
        "ADTree", "BBS", "ImpactMapping", "DecisionTree", "Timeline",
    ]

    @Test("Exactly the notations where a parallel link means nothing declare it")
    func adopters() {
        let declaring = NotationRegistry.entries
            .filter { entry in entry.entry.criteria.contains { $0.name == "noParallelEdges" } }
            .map { $0.id }
        #expect(Set(declaring) == expectedAdopters)
    }

    /// Declared on the notation, so it reaches a document through analysis without
    /// the document naming it.
    @Test("A declaring notation reports a parallel link through quality analysis")
    func reportedThroughAnalysis() throws {
        var graph = try causalLoopDiagram()
        graph = graph.using(notation: "CLD")
        graph = try stock("a", "Rabbits", in: graph)
        graph = try stock("b", "Grass", in: graph)
        graph = try link("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try link("e2", "a", "b", CLD.EdgeTypes.opposite, in: graph)

        let parallel = Notations.analyzeQuality(graph: graph).messages.filter { $0.message.contains("more than once") }
        #expect(parallel.count == 1)
    }

    @Test("Arithmetic's x + x is not reported")
    func arithmeticMayFeedOneNumberTwice() throws {
        typealias A = Notations.Arithmetic
        var graph = try VGraph().defineStandardAttributes()
        graph = try A.addNotation(addTo: graph)
        graph = graph.using(notation: "Arithmetic")
        graph = try graph.add(node: Node(string: "x"), type: A.NodeTypes.number)
        graph = try graph.add(node: Node(string: "op"), type: A.NodeTypes.plus)
        graph = try graph.add(edge: Edge(string: "e1", from: "x", to: "op"), edgeType: A.EdgeTypes.plusFirstOperand)
        graph = try graph.add(edge: Edge(string: "e2", from: "x", to: "op"), edgeType: A.EdgeTypes.plusSecondOperand)

        #expect(!Notations.analyzeQuality(graph: graph).messages.contains { $0.message.contains("more than once") })
    }
}
