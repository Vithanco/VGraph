import TestSupport
import Testing

@testable import VGraph

/// ADR-0032: a detailed node's fold default and unfolded frame come from its
/// node type; a plain group keeps its group type's.
@Suite
struct DetailedNodeFoldAndFrameTests {

    let ibs = Group(rawValue: "ibs")
    let softwareSystem = NodeType("SoftwareSystem")
    let dotted = GroupFrame(cornerRadius: 2, borderDash: "2,2")

    private func detailed() throws(VError) -> VGraph {
        try VGraph().adding(nodeType: softwareSystem).adding(group: ibs)
            .typing(group: ibs, as: softwareSystem)
    }

    @Test("Given a detailed node whose type declares no frame, then it has none and keeps the generic look")
    func noDeclaredFrame() throws(VError) {
        #expect(try detailed().resolvedFrame(ibs) == nil)
    }

    @Test("Given a detailed node holding a group style, then the style draws no frame: its look is its node type's")
    func aGroupStyleDoesNotReachADetailedNode() throws(VError) {
        let graph = try detailed().setting(
            group: ibs, attribute: Attributes.Group.groupStyle.attribute(GroupStyle(folded: .empty, unfolded: dotted)))

        #expect(graph.resolvedGroupStyle(ibs) != nil)
        #expect(graph.resolvedFrame(ibs) == nil)
    }

    @Test("Given a detailed node, when its node type declares a frame, then the detailed node draws it")
    func frameFollowsTheNodeType() throws(VError) {
        let graph = try detailed().setting(
            nodeType: softwareSystem, attribute: Attributes.Group.frame(dotted))

        #expect(graph.resolvedFrame(ibs)?.asString == dotted.asString)
    }

    @Test("Given a detailed node, then it is folded; given its node type unfolds, then it is not")
    func foldDefaultLivesOnTheNodeType() throws(VError) {
        let graph = try detailed()
        #expect(graph.foldState(of: ibs) == .folded)

        let unfolded = try graph.setting(nodeType: softwareSystem, attribute: Attributes.Group.isFolded(false))
        #expect(unfolded.foldState(of: ibs) == .unfolded)
    }

    @Test("Given a detailed node retyped to a plain group, then it is no longer folded by default")
    func aPlainGroupIsNotFoldedByDefault() throws(VError) {
        let graph = try detailed().typing(group: ibs, as: nil as GroupType?)

        #expect(graph.foldState(of: ibs) == .unfolded)
    }
}
