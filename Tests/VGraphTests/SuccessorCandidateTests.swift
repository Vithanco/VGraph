// Candidates offered when adding a successor or predecessor. A candidate is an
// edge type shown as its far-end node type. See ADR-0013.

import TestSupport
import Testing

@testable import VGraph

struct SuccessorCandidateTests {

    private func causalLoopDiagram() throws -> VGraph {
        try Notations.CausalLoopDiagram.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    /// A Causal Loop Diagram has a single node type and two edge types between it,
    /// so the node type alone cannot name a candidate — "add a Stock this one
    /// reduces" is only expressible as the `opposite` edge type.
    @Test func candidatesSharingANodeTypePairAreNamedByTheirEdgeType() throws {
        let graph = try causalLoopDiagram()
        let stock = Notations.CausalLoopDiagram.NodeTypes.stock

        let candidates = graph.successorCandidates(of: stock)

        #expect(Set(candidates.map(\.title)) == ["Stock (same)", "Stock (opposite)"])
        #expect(candidates.allSatisfy { $0.nodeType == stock })
    }

    private func conceptMap() throws -> VGraph {
        try Notations.ConceptMap.addNotation(addTo: VGraph().defineStandardAttributes())
    }

    /// With nothing to disambiguate against, a candidate is named by its node type
    /// alone — and the two directions see different halves of the notation.
    @Test func unambiguousCandidatesAreNamedByNodeTypeAlone() throws {
        let graph = try conceptMap()
        let types = Notations.ConceptMap.NodeTypes.self

        let after = graph.successorCandidates(of: types.concept)
        #expect(after.map(\.title) == ["Relation"])
        #expect(after.map(\.nodeType) == [types.relation])

        let before = graph.predecessorCandidates(of: types.relation)
        #expect(Set(before.map(\.title)) == ["Concept", "EmphasizedConcept"])
    }

    /// Menu order is the notation's declaration order. Asserted because the menu
    /// should not reshuffle between sessions, and nothing else pins the order
    /// `edgeTypes` comes back in.
    @Test func candidatesFollowTheNotationsDeclarationOrder() throws {
        let graph = try conceptMap()
        let types = Notations.ConceptMap.NodeTypes.self

        // EdgeTypes.all declares relationToConcept before relationToEmphasizedConcept.
        #expect(
            graph.predecessorCandidates(of: types.relation).map(\.nodeType)
                == [types.concept, types.emphasizedConcept])
    }

}
