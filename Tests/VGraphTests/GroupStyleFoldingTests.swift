import TestSupport
import Testing

@testable import VGraph

@Suite
struct GroupStyleFoldingTests {

    let group1 = Group(rawValue: "group1")
    let n1 = Node("n1")
    let nt1 = NodeType("nt1")

    private func baseGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nt1)
        graph = try Notations.FoldGroups.addExtension(addTo: graph)
        return graph
    }

    private func customFolded() -> NodeStyleLayout {
        return .nodeText(color: SemanticColor(id: "test.c4.folded", lightHex: "#0b5cad"))
    }

    private func groupNode(for group: Group) -> Node {
        return Node(group)
    }

    @Test("Given a group assigned a custom collapsed-box appearance, when the group is folded, then the collapsed box uses that appearance")
    func foldedGroupUsesItsOwnCollapsedAppearance() throws(VError) {
        let style = GroupStyle(folded: customFolded(), unfolded: .default)
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.label.attribute("System"))
        graph = try graph.set(group: group1, attribute: Attributes.Group.groupStyle.attribute(style))
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        // The style is compared in canonical (round-tripped) form because reading it back
        // through the attribute store re-serializes it — see GroupStyleTests.
        let proxyStyle = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.style)
        let expected = try NodeStyleLayout.fromString(customFolded().asString)
        #expect(proxyStyle == expected)
    }

    @Test("Given a group with a custom collapsed-box style, when it is folded, then the collapsed box still records its item count")
    func foldedStyledGroupStillRecordsItemCount() throws(VError) {
        let style = GroupStyle(folded: customFolded(), unfolded: .default)
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.groupStyle.attribute(style))
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        let count = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.foldedNodeCount)
        #expect(count == 1)
    }

    @Test("Given a group with no assigned style, when the group is folded, then the collapsed box keeps the default folded appearance")
    func unstyledFoldedGroupKeepsDefaultAppearance() throws(VError) {
        var graph = try baseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.label.attribute("Plain"))
        graph = try graph.set(group: group1, def: Attributes.Group.isFolded, value: true)

        let result = try applyFoldingLayoutStep(to: graph)

        let proxyStyle = try result.get(node: groupNode(for: group1), attribute: Attributes.Node.style)
        let base = NodeStyleLayout.foldedGroupNode(
            label: "Plain",
            count: 1,
            fill: Notations.FoldGroups.foldedGroupFill,
            border: Notations.FoldGroups.foldedGroupBorder,
            textColor: Notations.FoldGroups.foldedGroupText
        )
        let expected = try NodeStyleLayout.fromString(base.asString)
        #expect(proxyStyle == expected)
    }
}
