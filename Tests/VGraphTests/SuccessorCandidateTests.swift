// Candidates offered when adding a successor or predecessor. A candidate is an
// edge type shown as its far-end node type. See ADR-0013.

import TestSupport
import Testing

@testable import VGraph

struct SuccessorCandidateTests {

    private func causalLoopDiagram() throws -> VGraph {
        try Notations.CausalLoopDiagram.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    private func adding(_ id: String, _ type: NodeType, to graph: VGraph) throws -> (VGraph, Node) {
        let node = Node(string: id)
        return (try graph.add(node: node, type: type), node)
    }

    /// A Causal Loop Diagram has a single node type and two edge types between it,
    /// so the node type alone cannot name a candidate — "add a Stock this one
    /// reduces" is only expressible as the `opposite` edge type.
    @Test func candidatesSharingANodeTypePairAreNamedByTheirEdgeType() throws {
        let stock = Notations.CausalLoopDiagram.NodeTypes.stock
        let (graph, source) = try adding("s", stock, to: causalLoopDiagram())

        let candidates = graph.successorCandidates(from: source)

        #expect(Set(candidates.map(\.title)) == ["Stock (same)", "Stock (opposite)"])
        #expect(candidates.allSatisfy { $0.nodeType == stock })
    }

    private func conceptMap() throws -> VGraph {
        try Notations.ConceptMap.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    /// With nothing to disambiguate against, a candidate is named by its node type
    /// alone — and the two directions see different halves of the notation.
    @Test func unambiguousCandidatesAreNamedByNodeTypeAlone() throws {
        let types = Notations.ConceptMap.NodeTypes.self
        let (withConcept, concept) = try adding("c", types.concept, to: conceptMap())
        let (graph, relation) = try adding("r", types.relation, to: withConcept)

        let after = graph.successorCandidates(from: concept)
        #expect(after.map(\.title) == ["Relation"])
        #expect(after.map(\.nodeType) == [types.relation])

        let before = graph.predecessorCandidates(to: relation)
        #expect(Set(before.map(\.title)) == ["Concept", "EmphasizedConcept"])
    }

    /// Menu order is the notation's declaration order. Asserted because the menu
    /// should not reshuffle between sessions, and nothing else pins the order
    /// `edgeTypes` comes back in.
    @Test func candidatesFollowTheNotationsDeclarationOrder() throws {
        let types = Notations.ConceptMap.NodeTypes.self
        let (graph, relation) = try adding("r", types.relation, to: conceptMap())

        // EdgeTypes.all declares relationToConcept before relationToEmphasizedConcept.
        #expect(
            graph.predecessorCandidates(to: relation).map(\.nodeType)
                == [types.concept, types.emphasizedConcept])
    }

}
