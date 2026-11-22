//
//  EdgeOperationsTests.swift
//  VGraph
//
//  The graph edits behind the editing commands, asked of the graph directly.
//

import Testing

@testable import VGraph

struct EdgeOperationsTests {

    private let types = Notations.ConceptMap.NodeTypes.self
    private let missing = Edge.Id(string: "no-such-edge")

    private func conceptMap() throws -> VGraph {
        try Notations.ConceptMap.addNotation(addTo: VGraph().defineStandardAttributes())
            .add(node: Node(string: "a"), type: Notations.ConceptMap.NodeTypes.concept)
    }

    /// The new edge's id shares the node/edge/group keyspace, so it is probed
    /// like any other minted id rather than assumed free.
    @Test func aRelatedNodesEdgeStepsPastATakenId() throws {
        // One Relation already, so the new one is `relation_2` and its edge
        // would be `a_relation_2` — which a node already holds.
        let graph = try conceptMap().add(node: Node(string: "a_relation_2"), type: types.relation)
        let source = Node(string: "a")
        let candidate = try #require(graph.successorCandidates(from: source).first)

        let (changed, created) = try graph.addingRelated(
            to: source, ofType: candidate.nodeType, using: candidate.edgeType, newNodeAt: .to)

        #expect(created == Node(string: "relation_2"))
        #expect(changed.get(edge: Edge.Id(string: "a_relation_2_2")) != nil)
    }

    /// A node in no group is never drawn, so a new node whose neighbour has no
    /// group lands in the root, as `addingNode`'s does.
    @Test func aNewNodeBesideAGrouplessNodeLandsInTheRoot() throws {
        let graph = try conceptMap()
        let source = Node(string: "a")
        let candidate = try #require(graph.successorCandidates(from: source).first)

        let (related, relation) = try graph.addingRelated(
            to: source, ofType: candidate.nodeType, using: candidate.edgeType, newNodeAt: .to)
        #expect(related.group(of: try #require(relation)) == Group.root)

        let edge = try #require(related.edges.first).id
        let (split, inserted) = try related.splitting(edge, into: types.concept, incoming: nil, outgoing: nil)
        #expect(split.group(of: try #require(inserted)) == Group.root)
    }

    /// An edit of an edge that is not there is refused, not silently skipped:
    /// a graph handed back unchanged reads as success.
    @Test func editingAMissingEdgeIsRefused() throws {
        let graph = try conceptMap()
        let edgeType = Notations.ConceptMap.EdgeTypes.conceptToRelation

        #expect(throws: VError.edgeNotFound(missing)) { _ = try graph.reversing(missing, as: edgeType) }
        #expect(throws: VError.edgeNotFound(missing)) { _ = try graph.reversingWithUnknownType(missing) }
        #expect(throws: VError.edgeNotFound(missing)) {
            _ = try graph.reattaching(missing, end: .to, to: Node(string: "a"), using: edgeType)
        }
        #expect(throws: VError.edgeNotFound(missing)) {
            _ = try graph.splitting(missing, into: types.relation, incoming: nil, outgoing: nil)
        }
    }
}
