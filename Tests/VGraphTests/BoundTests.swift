//
//  BoundTests.swift
//  VGraph
//
//  Bounds on edge types and node types, and the quality check that
//  reports them. See ADR-0011.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("Bounds")
struct BoundTests {

    typealias CM = Notations.ConceptMap

    // MARK: - Fixtures

    /// Concept →(conceptToRelation) Relation →(relationToConcept) Concept.
    private func conceptMap() throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        return graph.using(notation: "ConceptMap")
    }

    private func concept(_ id: String, _ label: String, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        let result = try graph.add(node: node, type: CM.NodeTypes.concept)
        return try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
    }

    private func relation(_ id: String, _ label: String, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        let result = try graph.add(node: node, type: CM.NodeTypes.relation)
        return try result.set(node: node, attribute: Attributes.Node.label.attribute(label))
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

    // MARK: - The default: nothing is bounded

    /// The guarantee that makes this construct additive — no notation declares a
    /// bound today, so the check must be silent on every existing document.
    @Test("An undeclared bound reports nothing")
    func undeclaredBoundsAreSilent() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    /// `-1` is what "not stated" is stored as, so it must read as no bound rather
    /// than as a bound of minus one.
    @Test("An explicit -1 is the same as saying nothing")
    func minusOneMeansUnbounded() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, -1, on: CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, -1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    // MARK: - Maxima fault the edges

    @Test("Exceeding outDegreeMax reports an error against the offending edges")
    func outDegreeMaxExceeded() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)

        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
        // An edge target, not a node one: there is something concrete to blame.
        if case .edge = messages.first?.target {
        } else {
            Issue.record("expected an edge target, got \(String(describing: messages.first?.target))")
        }
    }

    /// Which edge is blamed, not just how many. The edges within the limit are
    /// fine by definition; it is the ones past it that are the fault, so a pair
    /// over a maximum of one blames the second edge rather than both or the first.
    @Test("A maximum blames the edges past the limit, in graph order")
    func outDegreeMaxBlamesTheLaterEdge() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)

        #expect(messages.count == 1)
        #expect(messages.first?.target == .edge(from: "a", to: "r2"))
    }

    @Test("Staying within outDegreeMax reports nothing")
    func outDegreeMaxRespected() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    @Test("Exceeding inDegreeMax reports an error")
    func inDegreeMaxExceeded() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try concept("b", "Cat", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "b", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.inDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
    }

    /// The duplicate rule the drag gesture reads (ADR-0012): same ordered pair,
    /// same edge type, twice.
    @Test("samePairMax 1 rejects a second edge of the same type between the same pair")
    func samePairMaxRejectsDuplicate() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
    }

    /// Degree and uniqueness are different constraints: two edges from one Concept
    /// to *different* Relations are two out-edges but not a duplicated pair.
    @Test("samePairMax does not constrain degree")
    func samePairMaxIsNotDegree() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    // MARK: - Minima fault the node

    /// The IBIS case in ConceptMap clothing: the fault is the *absence* of an edge,
    /// so there is nothing to blame but the node that is short.
    @Test("An unmet outDegreeMin reports a warning against the node, not an edge")
    func outDegreeMinUnmetFaultsTheNode() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)

        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.target == .node("a"))
        #expect(messages.first?.message.contains("Dog") == true)
    }

    @Test("A met outDegreeMin reports nothing")
    func outDegreeMinMet() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    /// A minimum is a statement about every node of the source type, so a second
    /// Concept that is short is faulted independently.
    @Test("Every node of the source type is checked against a minimum")
    func outDegreeMinChecksEveryNode() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try concept("b", "Cat", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("b"))
    }

    @Test("An unmet inDegreeMin faults the node at the arriving end")
    func inDegreeMinUnmetFaultsTheNode() throws {
        var graph = try conceptMap()
        graph = try relation("r1", "likes", in: graph)
        graph = try bound(Attributes.Edge.inDegreeMin, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("r1"))
    }

    /// A per-pair minimum is about pairs that are already joined — "if you connect
    /// these two at all, connect them at least N times".
    @Test("An unmet samePairMin reports against the pair")
    func samePairMinUnmet() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.samePairMin, 2, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .edge(from: "a", to: "r1"))
        #expect(messages.first?.severity == .warning)
    }

    /// The limit of what a per-pair minimum can say: two nodes with no edge between
    /// them are not a pair at all. Requiring an edge to exist is `outDegreeMin`'s
    /// job, and a per-pair bound that also meant that would demand every Concept
    /// connect to every Relation.
    @Test("samePairMin says nothing about a pair that is not joined")
    func samePairMinIgnoresUnjoinedPairs() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try bound(Attributes.Edge.samePairMin, 2, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    // MARK: - What the menu is allowed to offer

    @Test("An exhausted outDegreeMax removes the candidate")
    func exhaustedPerSourceMaxIsNotOffered() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r", "is a", in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(graph.successorCandidates(from: Node(string: "a")).isEmpty)
    }

    /// The two overloads differ in exactly this, which is the only reason both
    /// exist: a bound is spent at a *node*, and a node type has no edges to count.
    @Test("The node-type overload ignores bounds")
    func theTypeOverloadIgnoresBounds() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r", "is a", in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(graph.successorCandidates(from: Node(string: "a")).isEmpty)
        #expect(graph.successorCandidates(of: CM.NodeTypes.concept).count == 1)
    }

    /// The node a candidate would create starts life with exactly one edge, so a
    /// far end admitting none rules it out before it exists.
    @Test("A far end that admits no incoming edge is not offered")
    func farEndAdmittingNothingIsNotOffered() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMax.attribute(0))

        #expect(graph.successorCandidates(from: Node(string: "a")).isEmpty)
    }

    @Test("A outDegreeMax with room left still offers the candidate")
    func unspentPerSourceMaxIsOffered() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r", "is a", in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.outDegreeMax, 2, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(graph.successorCandidates(from: Node(string: "a")).count == 1)
    }

    @Test("An exhausted totalOutDegreeMax removes every candidate")
    func exhaustedTotalOutMaxClosesTheList() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r", "is a", in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMax.attribute(1))

        #expect(graph.successorCandidates(from: Node(string: "a")).isEmpty)
    }

    /// The mirror: `Add predecessor` reads the bound at the arriving end. Relation
    /// is reachable from two node types, and bounding one leaves the other — the
    /// list is pruned per edge type, not closed wholesale.
    @Test("An exhausted inDegreeMax removes only that candidate")
    func exhaustedPerTargetMaxIsNotOffered() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r", "is a", in: graph)
        graph = try edge("e1", "a", "r", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try bound(Attributes.Edge.inDegreeMax, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let candidates = graph.predecessorCandidates(to: Node(string: "r"))
        #expect(candidates.map(\.nodeType) == [CM.NodeTypes.emphasizedConcept])
    }

    @Test("A minimum never removes a candidate")
    func minimaDoNotPrune() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 5, on: CM.EdgeTypes.conceptToRelation, in: graph)

        #expect(graph.successorCandidates(from: Node(string: "a")).count == 1)
    }

    // MARK: - Aggregate bounds on a node type

    /// What an edge-type bound cannot say: "at least one edge of *any* type".
    @Test("totalOutDegreeMin counts every edge type together")
    func totalOutMinAggregates() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMin.attribute(1))

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("a"))
        #expect(messages.first?.severity == .warning)
    }

    @Test("totalOutDegreeMin is satisfied by an edge of any type")
    func totalOutMinSatisfiedByAnyType() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMin.attribute(1))

        #expect(GenericQualityChecks.brokenBounds(graph: graph).isEmpty)
    }

    @Test("totalOutDegreeMax counts every edge type together")
    func totalOutMaxAggregates() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMax.attribute(1))

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
    }

    @Test("totalInDegreeMin counts arriving edges of every type")
    func totalInMinAggregates() throws {
        var graph = try conceptMap()
        graph = try relation("r1", "likes", in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMin.attribute(1))

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.target == .node("r1"))
        #expect(messages.first?.severity == .warning)
    }

    @Test("totalInDegreeMax counts arriving edges of every type")
    func totalInMaxAggregates() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try concept("b", "Cat", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "b", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMax.attribute(1))

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .error)
    }

    @Test("A node total blames the edges past the limit, in graph order, at either end")
    func totalMaxBlamesEdgesPastTheLimit() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try concept("b", "Cat", in: graph)
        graph = try relation("r1", "likes", in: graph)
        graph = try relation("r2", "chases", in: graph)
        graph = try relation("r3", "fears", in: graph)
        graph = try edge("e1", "a", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e2", "a", "r2", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e3", "a", "r3", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try edge("e4", "b", "r1", CM.EdgeTypes.conceptToRelation, in: graph)
        graph = try graph.set(
            nodeType: CM.NodeTypes.concept, attribute: Attributes.Node.totalOutDegreeMax.attribute(1))
        graph = try graph.set(
            nodeType: CM.NodeTypes.relation, attribute: Attributes.Node.totalInDegreeMax.attribute(1))

        let blamed = GenericQualityChecks.brokenBounds(graph: graph).map { $0.target }
        #expect(
            blamed == [
                .edge(from: "a", to: "r2"), .edge(from: "a", to: "r3"),
                .edge(from: "b", to: "r1"),
            ])
    }

    // MARK: - Wiring

    /// The check has to be in the generic set, or a notation that declares bounds
    /// would be silently unchecked.
    @Test("The check runs as part of the generic analysis")
    func checkIsRegistered() throws {
        var graph = try conceptMap()
        graph = try concept("a", "Dog", in: graph)
        graph = try bound(Attributes.Edge.outDegreeMin, 1, on: CM.EdgeTypes.conceptToRelation, in: graph)

        let messages = GenericQualityChecks.analyze(graph)
        #expect(messages.contains { $0.severity == .warning && $0.target == .node("a") })
    }
}
