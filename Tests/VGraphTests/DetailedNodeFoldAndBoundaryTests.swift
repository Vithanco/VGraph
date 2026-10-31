import TestSupport
import Testing

@testable import VGraph

/// ADR-0032: a detailed node's fold default and unfolded boundary come from its
/// node type; a plain group keeps its group type's.
@Suite
struct DetailedNodeFoldAndBoundaryTests {

    let ibs = Group(rawValue: "ibs")
    let softwareSystem = NodeType("SoftwareSystem")
    let dotted = BoundaryChrome(cornerRadius: 2, borderDash: "2,2")

    private func detailed() throws(VError) -> VGraph {
        try VGraph().defineStandardAttributes().add(nodeType: softwareSystem).add(group: ibs)
            .typing(group: ibs, as: softwareSystem)
    }

    @Test("Given a detailed node whose type declares no boundary, then it has none and keeps the generic look")
    func noDeclaredBoundary() throws(VError) {
        #expect(try detailed().resolvedBoundaryChrome(ibs) == nil)
    }

    @Test("Given a detailed node, when its node type declares a boundary, then the detailed node draws it")
    func boundaryFollowsTheNodeType() throws(VError) {
        let graph = try detailed().set(
            nodeType: softwareSystem, attribute: Attributes.Group.boundaryChrome(dotted))

        #expect(graph.resolvedBoundaryChrome(ibs)?.asString == dotted.asString)
    }

    @Test("Given a detailed node, then it is folded; given its node type unfolds, then it is not")
    func foldDefaultLivesOnTheNodeType() throws(VError) {
        let graph = try detailed()
        #expect(graph.foldingState(group: ibs) == .folded)

        let unfolded = try graph.set(nodeType: softwareSystem, attribute: Attributes.Group.isFolded(false))
        #expect(unfolded.foldingState(group: ibs) == .normal)
    }

    @Test("Given a detailed node retyped to a plain group, then it is no longer folded by default")
    func aPlainGroupIsNotFoldedByDefault() throws(VError) {
        let graph = try detailed().typing(group: ibs, as: nil as GroupType?)

        #expect(graph.foldingState(group: ibs) == .normal)
    }
}
