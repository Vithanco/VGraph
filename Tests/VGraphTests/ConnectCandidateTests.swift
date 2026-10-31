//
//  ConnectCandidateTests.swift
//  VGraph
//
//  What the notation permits between two *existing* nodes — the query behind
//  drag-to-connect. See ADR-0012.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("Connect candidates")
struct ConnectCandidateTests {

    typealias CM = Notations.ConceptMap
    typealias CLD = Notations.CausalLoopDiagram

    // MARK: - Fixtures

    private func conceptMap() throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        return graph.using(notation: "ConceptMap")
    }

    private func causalLoopDiagram() throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        return graph.using(notation: "CLD")
    }

    /// The same types under a notation name the registry does not know, so no
    /// [[Graph criterion]] is in force and only bounds decide — for the tests
    /// about bounds alone, which CLD's and ConceptMap's `noParallelEdges` would
    /// otherwise answer first.
    private func boundsOnly(_ graph: VGraph) throws(VError) -> VGraph {
        graph.using(notation: "BoundsOnly")
    }

    private func node(_ id: String, _ type: NodeType, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        let result = try graph.add(node: node, type: type)
        return try result.set(node: node, attribute: Attributes.Node.label.attribute(id))
    }

    private func edge(_ id: String, _ from: String, _ to: String, _ type: EdgeType, in graph: VGraph)
        throws(VError) -> VGraph
    {
        try graph.add(edge: Edge(string: id, from: from, to: to), edgeType: type)
    }

    private func bound(
        _ definition: TypedAttributeDefinition<Int>, _ value: Int, on edgeType: EdgeType, in graph: VGraph
    ) throws(VError) -> VGraph {
        try graph.set(edgeType: edgeType, attribute: definition.attribute(value))
    }

    private func candidates(_ graph: VGraph, _ from: String, _ to: String) -> [String] {
        graph.connectCandidates(from: Node(string: from), to: Node(string: to)).map { $0.id.id }
    }

    // MARK: - What the notation declares

    @Test("A declared edge type joining the two node types is a candidate")
    func declaredTypeIsOffered() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)

        #expect(candidates(graph, "a", "r") == [CM.EdgeTypes.conceptToRelation.id.id])
    }

    /// The whole of ADR-0012's "direction is the direction dragged": Relation →
    /// Concept exists, and that is precisely why dragging Concept onto Relation
    /// must not silently produce it.
    @Test("A type running the other way does not make the drop legal")
    func theReverseTypeDoesNotCount() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)

        #expect(candidates(graph, "r", "a") == [CM.EdgeTypes.relationToConcept.id.id])
        #expect(!candidates(graph, "r", "a").contains(CM.EdgeTypes.conceptToRelation.id.id))
    }

    /// Concept → Concept has to go through a Relation, so there is nothing to
    /// offer and the ghost line stays red.
    @Test("A pair the notation never joins has no candidate")
    func undeclaredPairIsEmpty() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)

        #expect(candidates(graph, "a", "b").isEmpty)
    }

    /// Two types between one pair is what makes the drop a question rather than
    /// an answer.
    @Test("Several types between one pair are all candidates")
    func severalTypesAreAllOffered() throws {
        var graph = try causalLoopDiagram()
        graph = try node("s1", CLD.NodeTypes.stock, in: graph)
        graph = try node("s2", CLD.NodeTypes.stock, in: graph)

        #expect(Set(candidates(graph, "s1", "s2")) == ["same", "opposite"])
    }

    /// An unknown type is the *record* of a past break, not an offer to repeat it.
    @Test("An unknown edge type is never a candidate")
    func unknownTypesAreNotOffered() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)
        let unknown: EdgeType
        (graph, unknown) = try graph.ensureUnknownEdgeType(
            from: CM.NodeTypes.concept, to: CM.NodeTypes.concept)
        graph = try edge("e1", "a", "b", unknown, in: graph)

        #expect(candidates(graph, "a", "b").isEmpty)
    }

    // MARK: - Bounds (ADR-0011)

    /// The bound only `connectCandidates` can read: with both endpoints known,
    /// "how many join *these two* nodes" is finally a question that can be asked.
    @Test("An exhausted samePairMax removes the candidate")
    func exhaustedSamePairMax() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(candidates(graph, "a", "r").isEmpty)
    }

    /// samePairMax counts one pair, so a second Relation is still reachable.
    @Test("samePairMax spent on one pair leaves another pair open")
    func samePairMaxIsPerPair() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r1", CM.NodeTypes.relation, in: graph)
        graph = try node("r2", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(candidates(graph, "a", "r1").isEmpty)
        #expect(candidates(graph, "a", "r2").count == 1)
    }

    @Test("An exhausted outDegreeMax removes the candidate")
    func exhaustedPerSourceMax() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r1", CM.NodeTypes.relation, in: graph)
        graph = try node("r2", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(candidates(graph, "a", "r2").isEmpty)
    }

    @Test("An exhausted inDegreeMax removes the candidate")
    func exhaustedPerTargetMax() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.inDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(candidates(graph, "b", "r").isEmpty)
    }

    /// The aggregate bound closes the source outright, whatever the edge type.
    @Test("An exhausted totalOutDegreeMax closes the source")
    func exhaustedTotalOutMax() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r1", CM.NodeTypes.relation, in: graph)
        graph = try node("r2", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMax.attribute(1))

        #expect(candidates(graph, "a", "r2").isEmpty)
    }

    /// The far end is a real node here, not a hypothetical one — so its *actual*
    /// incoming degree is what counts, which is what `successorCandidates` cannot
    /// ask.
    @Test("An exhausted totalInDegreeMax closes the destination")
    func exhaustedTotalInMax() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMax.attribute(1))

        #expect(candidates(graph, "b", "r").isEmpty)
    }

    /// Only a maximum can forbid an addition; a shortfall is a shortfall (ADR-0011).
    @Test("A minimum never removes a candidate")
    func minimaDoNotPrune() throws {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 5, on: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMin, 5, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(candidates(graph, "a", "r").count == 1)
    }

    /// Refusing a connection the notation permits because *one* of several types
    /// is spent would be the worse error (ADR-0012).
    @Test("One exhausted type does not hide the others")
    func oneExhaustedTypeLeavesTheRest() throws {
        var graph = try boundsOnly(causalLoopDiagram())
        graph = try node("s1", CLD.NodeTypes.stock, in: graph)
        graph = try node("s2", CLD.NodeTypes.stock, in: graph)
        graph = try edge("e1", "s1", "s2", CLD.EdgeTypes.same, in: graph)
        graph = try bound(Attributes.Edge.samePairMax, 1, on: CLD.EdgeTypes.same, in: graph)

        #expect(candidates(graph, "s1", "s2") == ["opposite"])
    }

    // MARK: - The default

    /// No notation declares a bound today, so the query must reduce to "what the
    /// notation declares" on every existing document.
    @Test("With nothing bounded, every declared type stays on offer")
    func unboundedNotationsOfferEverything() throws {
        var graph = try boundsOnly(conceptMap())
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("r", CM.NodeTypes.relation, in: graph)
        for index in 1...5 {
            graph = try edge("e\(index)", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        }

        #expect(candidates(graph, "a", "r").count == 1)
    }

    // MARK: - noParallelEdges

    /// The criterion is data, so the gesture can read it: a pair already joined is
    /// not offered again, in either type. The other direction is a loop, not a
    /// parallel link.
    @Test("A declaring notation offers nothing for a pair already joined")
    func joinedPairIsNotOffered() throws {
        var graph = try causalLoopDiagram()
        graph = try node("a", CLD.NodeTypes.stock, in: graph)
        graph = try node("b", CLD.NodeTypes.stock, in: graph)
        graph = try edge("e1", "a", "b", CLD.EdgeTypes.same, in: graph)

        #expect(graph.connectCandidates(from: Node(string: "a"), to: Node(string: "b")).isEmpty)
        #expect(!graph.connectCandidates(from: Node(string: "b"), to: Node(string: "a")).isEmpty)
    }

    /// Reattach and retype ask against the graph without the edge in hand, so an
    /// edge is never in its own way.
    @Test("Retyping an edge still offers its pair's other types")
    func retypeIsNotBlockedByItself() throws {
        var graph = try causalLoopDiagram()
        graph = try node("a", CLD.NodeTypes.stock, in: graph)
        graph = try node("b", CLD.NodeTypes.stock, in: graph)
        graph = try edge("e1", "a", "b", CLD.EdgeTypes.same, in: graph)

        #expect(graph.retypeCandidates(edge: Edge.Id(string: "e1")).map { $0.id } == [CLD.EdgeTypes.opposite.id])
    }

    @Test("Reattaching an end onto a pair already joined is not offered")
    func reattachOntoJoinedPairIsNotOffered() throws {
        var graph = try causalLoopDiagram()
        graph = try node("a", CLD.NodeTypes.stock, in: graph)
        graph = try node("b", CLD.NodeTypes.stock, in: graph)
        graph = try node("c", CLD.NodeTypes.stock, in: graph)
        graph = try edge("e1", "a", "b", CLD.EdgeTypes.same, in: graph)
        graph = try edge("e2", "c", "b", CLD.EdgeTypes.same, in: graph)

        #expect(graph.reattachCandidates(edge: Edge.Id(string: "e2"), end: .from, to: Node(string: "a")).isEmpty)
        #expect(!graph.reattachCandidates(edge: Edge.Id(string: "e2"), end: .from, to: Node(string: "c")).isEmpty)
    }

    @Test("A notation without the criterion still offers a second link")
    func arithmeticStillOffersTheSecondOperand() throws {
        typealias A = Notations.Arithmetic
        var graph = try VGraph().defineStandardAttributes()
        graph = try A.addNotation(addTo: graph)
        graph = graph.using(notation: "Arithmetic")
        graph = try graph.add(node: Node(string: "x"), type: A.NodeTypes.number)
        graph = try graph.add(node: Node(string: "op"), type: A.NodeTypes.plus)
        graph = try graph.add(edge: Edge(string: "e1", from: "x", to: "op"), edgeType: A.EdgeTypes.plusFirstOperand)

        #expect(
            graph.connectCandidates(from: Node(string: "x"), to: Node(string: "op")).map { $0.id }
                == [A.EdgeTypes.plusSecondOperand.id])
    }
}
