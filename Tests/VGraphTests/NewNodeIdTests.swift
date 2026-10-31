//
//  NewNodeIdTests.swift
//  VGraph
//
//  Ids for nodes a VCommand creates.
//

import TestSupport
import Testing

@testable import VGraph

struct NewNodeIdTests {
    /// A graph with `count` Concepts, named `c0…`, plus the ConceptMap notation.
    private func conceptMap(concepts count: Int) throws -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try Notations.ConceptMap.addNotation(addTo: graph)
        for index in 0..<count {
            graph = try graph.add(
                node: Node(string: "c\(index)"), type: Notations.ConceptMap.NodeTypes.concept)
        }
        return graph
    }

    /// The search starts at "one more than there are", so a map with 12 Concepts
    /// mints `concept_13` — not `concept_1`. On a graph whose ids already follow
    /// the scheme that is the answer outright, which is the point: the free-id
    /// probe below it runs once instead of once per existing node.
    @Test func startsCountingFromHowManyOfThatTypeExist() throws {
        let graph = try conceptMap(concepts: 12)

        #expect(graph.newNodeId(for: Notations.ConceptMap.NodeTypes.concept) == Node(string: "concept_13"))
    }

    /// An empty map still starts at 1.
    @Test func theFirstOfATypeIsAlwaysOne() throws {
        let graph = try conceptMap(concepts: 0)

        #expect(graph.newNodeId(for: Notations.ConceptMap.NodeTypes.concept) == Node(string: "concept_1"))
    }

    /// Counting is only where the search *starts* — it cannot stand in for the
    /// free-id check. Ids are not dense (deleting one leaves a hole) and nodes,
    /// edges and groups share one keyspace, so the count routinely lands on a
    /// taken id and the search has to walk past it.
    @Test func countingOnlyPicksTheStartAndTheSearchStillProbes() throws {
        var graph = try conceptMap(concepts: 2)
        // Two Concepts, so the search starts at 3 — and something else already
        // holds that id, in a different element kind.
        graph = try graph.add(node: Node(string: "concept_3"), type: Notations.ConceptMap.NodeTypes.relation)

        #expect(graph.newNodeId(for: Notations.ConceptMap.NodeTypes.concept) == Node(string: "concept_4"))
    }

    /// The count is per node type, not per graph: Relations do not push Concepts
    /// along.
    @Test func eachTypeCountsOnlyItsOwn() throws {
        var graph = try conceptMap(concepts: 1)
        graph = try graph.add(node: Node(string: "r0"), type: Notations.ConceptMap.NodeTypes.relation)
        graph = try graph.add(node: Node(string: "r1"), type: Notations.ConceptMap.NodeTypes.relation)

        #expect(graph.newNodeId(for: Notations.ConceptMap.NodeTypes.concept) == Node(string: "concept_2"))
        #expect(graph.newNodeId(for: Notations.ConceptMap.NodeTypes.relation) == Node(string: "relation_3"))
    }
}
