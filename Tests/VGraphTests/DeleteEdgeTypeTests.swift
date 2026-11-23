//
//  DeleteEdgeTypeTests.swift
//  VGraph
//
//  Removing an edge type the graph no longer needs.
//
//  Untested until ADR-0024 needed it, and broken the whole time: `getMany`
//  answers **nil** for a type nothing references — which is exactly the type
//  that may be deleted — and the guard read nil as "not found". So this refused
//  every unused type, the only kind it is ever asked about.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("Deleting an edge type")
struct DeleteEdgeTypeTests {

    typealias CM = Notations.ConceptMap

    private func conceptMap() throws(VError) -> VGraph {
        var graph = VGraph()
        graph = try CM.addNotation(to: graph)
        return graph.using(notation: "ConceptMap")
    }

    private func node(_ id: String, _ type: NodeType, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(rawValue: id)
        let result = try graph.adding(node: node, type: type)
        return try result.setting(node: node, attribute: Attributes.Node.label.attribute(id))
    }

    /// A pair with an edge on it, and the minted type that joins them.
    private func withAMintedEdge() throws(VError) -> (VGraph, EdgeType) {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)
        let minted: EdgeType
        (graph, minted) = try graph.ensuringUnknownEdgeType(
            from: CM.NodeTypes.concept, to: CM.NodeTypes.concept)
        graph = try graph.adding(
            edge: Edge(string: "e1", from: "a", to: "b"), edgeType: minted)
        return (graph, minted)
    }

    @Test("A type no edge wears is removed")
    func anUnusedTypeIsRemoved() throws {
        let (graph, minted) = try withAMintedEdge()
        let without = try graph.deleting(edge: Edge.Id(rawValue: "e1"))
        #expect(without.get(edgeType: minted.id) != nil)

        let cleaned = try without.deleting(edgeType: minted.id)

        #expect(cleaned.get(edgeType: minted.id) == nil)
        #expect(!cleaned.edgeTypes.contains { $0.id == minted.id })
    }

    /// The case the guard was actually written for, and it said the wrong thing:
    /// a type still in use reported "not found" rather than naming the edge.
    @Test("A type an edge still wears is refused, naming that edge")
    func aTypeStillInUseIsRefused() throws {
        let (graph, minted) = try withAMintedEdge()

        #expect(throws: VError.edgeTypeStillInUse(Edge.Id(rawValue: "e1"))) {
            _ = try graph.deleting(edgeType: minted.id)
        }
        #expect(graph.get(edgeType: minted.id) != nil)
    }

    @Test("A type the graph never had is not found")
    func anAbsentTypeIsNotFound() throws {
        let graph = try conceptMap()
        let absent = EdgeType.Id(rawValue: "no_such_type")

        #expect(throws: VError.edgeTypeNotFound(absent)) {
            _ = try graph.deleting(edgeType: absent)
        }
    }
}
