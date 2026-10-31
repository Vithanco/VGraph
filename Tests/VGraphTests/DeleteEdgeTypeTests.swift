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
        var graph = try VGraph().defineStandardAttributes()
        graph = try CM.addNotation(addTo: graph)
        return graph.using(notation: "ConceptMap")
    }

    private func node(_ id: String, _ type: NodeType, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        let result = try graph.add(node: node, type: type)
        return try result.set(node: node, attribute: Attributes.Node.label.attribute(id))
    }

    /// A pair with an edge on it, and the minted type that joins them.
    private func withAMintedEdge() throws(VError) -> (VGraph, EdgeType) {
        var graph = try conceptMap()
        graph = try node("a", CM.NodeTypes.concept, in: graph)
        graph = try node("b", CM.NodeTypes.concept, in: graph)
        let minted: EdgeType
        (graph, minted) = try graph.ensureUnknownEdgeType(
            from: CM.NodeTypes.concept, to: CM.NodeTypes.concept)
        graph = try graph.add(
            edge: Edge(string: "e1", from: "a", to: "b"), edgeType: minted)
        return (graph, minted)
    }

    @Test("A type no edge wears is removed")
    func anUnusedTypeIsRemoved() throws {
        let (graph, minted) = try withAMintedEdge()
        let without = try graph.delete(edge: Edge.Id(string: "e1"))
        #expect(without.get(edgeType: minted.id) != nil)

        let cleaned = try without.delete(edgeType: minted.id)

        #expect(cleaned.get(edgeType: minted.id) == nil)
        #expect(!cleaned.edgeTypes.contains { $0.id == minted.id })
    }

    /// The case the guard was actually written for, and it said the wrong thing:
    /// a type still in use reported "not found" rather than naming the edge.
    @Test("A type an edge still wears is refused, naming that edge")
    func aTypeStillInUseIsRefused() throws {
        let (graph, minted) = try withAMintedEdge()

        #expect(throws: VError.edgeTypeStillInUse(Edge.Id(string: "e1"))) {
            _ = try graph.delete(edgeType: minted.id)
        }
        #expect(graph.get(edgeType: minted.id) != nil)
    }

    @Test("A type the graph never had is not found")
    func anAbsentTypeIsNotFound() throws {
        let graph = try conceptMap()
        let absent = EdgeType.Id(string: "no_such_type")

        #expect(throws: VError.edgeTypeNotFound(absent)) {
            _ = try graph.delete(edgeType: absent)
        }
    }

    /// Declared types are ordinary here — nothing about this is special to a
    /// minted one.
    @Test("A declared type the notation brought is removable once unused")
    func aDeclaredTypeIsRemovableTooWhenUnused() throws {
        let graph = try conceptMap()
        let declared = CM.EdgeTypes.conceptToRelation.id
        #expect(graph.get(edgeType: declared) != nil)

        let cleaned = try graph.delete(edgeType: declared)

        #expect(cleaned.get(edgeType: declared) == nil)
    }
}
