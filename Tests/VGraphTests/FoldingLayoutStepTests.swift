import TestSupport
import Testing

@testable import VGraph

@Suite
struct FoldingLayoutStepTests {

    // MARK: - Test Fixtures

    let group1 = Group(rawValue: "group1")
    let group2 = Group(rawValue: "group2")
    let group3 = Group(rawValue: "group3")
    let group4 = Group(rawValue: "group4")

    let n1 = Node("n1")
    let n2 = Node("n2")
    let n3 = Node("n3")
    let n4 = Node("n4")
    let n5 = Node("n5")
    let n6 = Node("n6")

    let nt1 = NodeType("nt1")
    let nt2 = NodeType("nt2")

    private func createBaseGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nt1)
            .add(nodeType: nt2)
        graph = try Notations.FoldGroups.addExtension(addTo: graph)
        return graph
    }

    private func addEdgeType(to graph: VGraph, from: NodeType, to: NodeType, id: String) throws(VError) -> VGraph {
        let et = EdgeType(string: id, from: from.id.description, to: to.id.description)
        return try graph.add(edgeType: et)
    }

    private func foldGroup(_ group: Group, in graph: VGraph) throws(VError) -> VGraph {
        return try graph.set(group: group, def: Attributes.Group.isFolded, value: true)
    }

    private func groupNode(for group: Group) -> Node {
        return Node(group)
    }

    // MARK: - Display types (ADR-0030)

    @Test("Given a fold, when the stand-in's type is installed, then its values are the engine's")
    func theStandInTypeIsTheEngines() throws(VError) {
        var graph = try VGraph().defineStandardAttributes().add(nodeType: nt1)
            .add(group: group1).add(node: n1, type: nt1, group: group1)
        graph = try foldGroup(group1, in: graph)
        let result = try applyFoldingLayoutStep(to: graph)
        let key = ItemKey(.nodeType, Notations.FoldGroups.NodeTypes.foldedGroup.description)
        #expect(try !result.attributes(in: .engine, of: key).isEmpty)
        #expect(try result.attributes(in: .vnotation, of: key).isEmpty)
    }

    @Test("Given an edge into a folded group, when it is redirected, then its new type takes its values from the original")
    func aRedirectedEdgeTypeFollowsItsOriginal() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1).add(node: n1, type: nt1, group: group1).add(node: n2, type: nt1)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let original = EdgeType.Id(string: "e_nt1_nt1")
        graph = try graph.set(edgeType: original, attribute: Attributes.Edge.color.attribute(VColor.red))
        graph = try graph.add(edge: Edge(string: "e1", from: "n2", to: "n1"), edgeType: graph.get(edgeType: "e_nt1_nt1")!)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        let redirected = try result.edgeType(for: Edge.Id(string: "e1")).id
        #expect(redirected != original)
        for layer in [AttributeLayer.engine, .builtin, .vnotation] {
            #expect(try result.attributes(in: layer, of: ItemKey(.edgeType, redirected.description)).isEmpty)
        }
        #expect(try result.get(edgeType: redirected, attribute: Attributes.Edge.color) == VColor.red)
        #expect(try result.get(edge: Edge.Id(string: "e1"), attribute: Attributes.Edge.color) == VColor.red)
    }

    // MARK: - NotationExtension Does Not Write to Notation Attribute

    @Test
    func foldGroups_doesNotOverwriteNotationAttribute() throws(VError) {
        var graph = try VGraph()
            .defineStandardAttributes()
        graph = try Notations.Ibis.addNotation(addTo: graph)
        graph = graph.using(notation: "IBIS")

        graph = try Notations.FoldGroups.addExtension(addTo: graph)

        let notationValue: String = graph.notationName
        #expect(notationValue == "IBIS")
    }

    // MARK: - No Folded Groups: Return Unchanged

    @Test
    func noFoldedGroups_returnsUnchangedGraph() throws(VError) {
        let graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.nodes.count == 2)
        #expect(result.groups.count == 1)
        #expect(result.has(node: n1))
        #expect(result.has(node: n2))
    }

    @Test
    func emptyGraph_returnsUnchangedGraph() throws(VError) {
        let graph = try createBaseGraph()

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.nodes.isEmpty)
        #expect(result.groups.isEmpty)
    }

    // MARK: - Rule 1: Folded Group Becomes FoldedGroup Node

    @Test
    func foldedGroup_becomesNodeOfTypeFoldedGroup() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        let expectedGroupNode = groupNode(for: group1)
        #expect(result.has(node: expectedGroupNode))
        let nodeType = try result.nodeType(for: expectedGroupNode)
        #expect(nodeType == Notations.FoldGroups.NodeTypes.foldedGroup)
        #expect(result.nodes.count == 1)
    }

    @Test
    func foldedGroup_groupNodeGetsGroupLabel() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try graph.set(group: group1, attribute: Attributes.Group.label.attribute("My Group"))
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        // Then: GroupNode preserves the original-case label (the rendered title is uppercased
        // by the layout via NodeStyleLayout.typeLabel); count is stored as foldedNodeCount.
        let expectedGroupNode = groupNode(for: group1)
        let label = try result.get(node: expectedGroupNode, attribute: Attributes.Node.label)
        #expect(label == "My Group")
        let count = try result.get(node: expectedGroupNode, attribute: Attributes.Node.foldedNodeCount)
        #expect(count == 1)
    }

    @Test
    func multipleFoldedGroups_eachBecomesGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
            .add(node: n2, type: nt1, group: group2)
        graph = try foldGroup(group1, in: graph)
        graph = try foldGroup(group2, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.has(node: groupNode(for: group2)))
        #expect(!result.has(node: n1))
        #expect(!result.has(node: n2))
        #expect(result.nodes.count == 2)
    }

    // MARK: - Rule 2: Internal Edges Are Deleted

    @Test
    func edgeWithinFoldedGroup_isDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.isEmpty)
        #expect(result.nodes.count == 1)
    }

    @Test
    func edgeWithinNestedSubgroup_isDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph =
            try graph
            .add(node: n1, type: nt1, group: group2)
            .add(node: n2, type: nt1, group: group2)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.isEmpty)
    }

    @Test
    func edgeBetweenDirectAndNestedNodes_isDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.add(node: n2, type: nt1, group: group2)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.isEmpty)
    }

    // MARK: - Rule 3: Crossing Edges Are Redirected

    @Test
    func edgeFromOutsideToInsideFoldedGroup_redirectsToGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)  // inside
            .add(node: n2, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n2.id.description, to: n1.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == n2)
        #expect(resultEdge.to == groupNode(for: group1))
    }

    @Test
    func edgeFromInsideFoldedGroupToOutside_redirectsFromGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)  // inside
            .add(node: n2, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == groupNode(for: group1))
        #expect(resultEdge.to == n2)
    }

    @Test
    func edgeFromSubgroupToOutside_redirectsFromGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph =
            try graph
            .add(node: n1, type: nt1, group: group2)  // inside subgroup
            .add(node: n2, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == groupNode(for: group1))
        #expect(resultEdge.to == n2)
    }

    @Test
    func edgeBetweenTwoFoldedGroups_redirectsBothEnds() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
            .add(node: n2, type: nt1, group: group2)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)
        graph = try foldGroup(group2, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == groupNode(for: group1))
        #expect(resultEdge.to == groupNode(for: group2))
    }

    @Test
    func multipleEdgesCrossingFoldedGroup_allRedirected() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
            .add(node: n3, type: nt1)  // outside
            .add(node: n4, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!

        let edge1 = Edge(string: "e1", from: n3.id.description, to: n1.id.description)
        graph = try graph.add(edge: edge1, edgeType: edgeType)

        let edge2 = Edge(string: "e2", from: n4.id.description, to: n2.id.description)
        graph = try graph.add(edge: edge2, edgeType: edgeType)

        let edge3 = Edge(string: "e3", from: n1.id.description, to: n3.id.description)
        graph = try graph.add(edge: edge3, edgeType: edgeType)

        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 3)
        for edge in result.edges {
            let touchesGroupNode = edge.from == groupNode(for: group1) || edge.to == groupNode(for: group1)
            #expect(touchesGroupNode)
        }
    }

    @Test
    func edgeWithDifferentNodeTypes_createsCorrectEdgeType() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)  // inside, type nt1
            .add(node: n2, type: nt2)  // outside, type nt2
        graph = try addEdgeType(to: graph, from: nt2, to: nt1, id: "e_nt2_nt1")
        let edge = Edge(string: "e1", from: n2.id.description, to: n1.id.description)
        let edgeType = graph.get(edgeType: "e_nt2_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == n2)
        #expect(resultEdge.to == groupNode(for: group1))

        let resultEdgeType = try result.edgeType(for: resultEdge)
        #expect(resultEdgeType.from == nt2)
        #expect(resultEdgeType.to == Notations.FoldGroups.NodeTypes.foldedGroup)
    }

    // MARK: - Rule 4: Subgroups Are Deleted

    @Test
    func subgroupsOfFoldedGroup_areDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(group: group2)
            .add(group: group3)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.addTo(group: group2, childGroup: group3)
        graph =
            try graph
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group2)
            .add(node: n3, type: nt1, group: group3)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(!result.has(group: group1))
        #expect(!result.has(group: group2))
        #expect(!result.has(group: group3))
    }

    @Test
    func deeplyNestedSubgroups_allDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(group: group2)
            .add(group: group3)
            .add(group: group4)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.addTo(group: group2, childGroup: group3)
        graph = try graph.addTo(group: group3, childGroup: group4)
        graph = try graph.add(node: n1, type: nt1, group: group4)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(!result.has(group: group1))
        #expect(!result.has(group: group2))
        #expect(!result.has(group: group3))
        #expect(!result.has(group: group4))
    }

    // MARK: - Rule 5: Nodes Within Folded Group Are Deleted

    @Test
    func directNodesInFoldedGroup_areDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
            .add(node: n3, type: nt1)  // outside
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(!result.has(node: n1))
        #expect(!result.has(node: n2))
        #expect(result.has(node: n3))
        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.nodes.count == 2)  // n3 + GroupNode
    }

    @Test
    func nodesInNestedSubgroups_areDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.add(node: n2, type: nt1, group: group2)
        graph = try graph.add(group: group3)
        graph = try graph.addTo(group: group2, childGroup: group3)
        graph = try graph.add(node: n3, type: nt1, group: group3)
        graph = try graph.add(node: n4, type: nt1)  // outside
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(!result.has(node: n1))
        #expect(!result.has(node: n2))
        #expect(!result.has(node: n3))
        #expect(result.has(node: n4))
        #expect(result.has(node: groupNode(for: group1)))
    }

    // MARK: - Nested Folded Groups (Hidden Groups Are Not Processed)

    @Test
    func nestedFoldedGroup_isHiddenNotProcessedSeparately() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.add(node: n2, type: nt1, group: group2)

        graph = try foldGroup(group1, in: graph)
        graph = try foldGroup(group2, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: groupNode(for: group1)))
        #expect(!result.has(node: groupNode(for: group2)))
        #expect(result.nodes.count == 1)  // Only GroupNode for group1
    }

    @Test
    func siblingFoldedGroups_bothProcessed() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(group: group2)
            .add(node: n2, type: nt1, group: group2)
        graph = try foldGroup(group1, in: graph)
        graph = try foldGroup(group2, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.has(node: groupNode(for: group2)))
        #expect(result.nodes.count == 2)
    }

    // MARK: - Edge Cases

    @Test
    func foldedGroupWithNoNodes_becomesEmptyGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.nodes.count == 1)
    }

    @Test
    func foldedGroupWithOnlySubgroups_becomesGroupNode() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(group: group2)
        graph = try graph.addTo(group: group1, childGroup: group2)
        graph = try graph.add(node: n1, type: nt1, group: group2)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: groupNode(for: group1)))
        #expect(!result.has(node: n1))
        #expect(!result.has(group: group2))
    }

    @Test
    func selfLoopEdgeInFoldedGroup_isDeleted() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n1.id.description, to: n1.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.isEmpty)
    }

    @Test
    func nodesOutsideFoldedGroup_remainUnchanged() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1)  // outside, no group
            .add(group: group2)
            .add(node: n3, type: nt1, group: group2)  // outside, different group
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.has(node: n2))
        #expect(result.has(node: n3))
        #expect(result.has(group: group2))
    }

    @Test
    func edgesBetweenNodesOutsideFoldedGroup_remainUnchanged() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1)  // outside
            .add(node: n3, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n2.id.description, to: n3.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 1)
        let resultEdge = result.edges.first!
        #expect(resultEdge.from == n2)
        #expect(resultEdge.to == n3)
    }

    // MARK: - Edge Type Creation Tests

    @Test
    func multipleEdgesWithSameRedirection_reuseEdgeType() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
            .add(node: n3, type: nt1)  // outside
            .add(node: n4, type: nt1)  // outside
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!

        // Two edges from outside to inside (same pattern: nt1 -> FoldedGroup)
        let edge1 = Edge(string: "e1", from: n3.id.description, to: n1.id.description)
        let edge2 = Edge(string: "e2", from: n4.id.description, to: n2.id.description)
        graph = try graph.add(edge: edge1, edgeType: edgeType)
        graph = try graph.add(edge: edge2, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        #expect(result.edges.count == 2)
        var edgeTypes: [EdgeType] = []
        for edge in result.edges {
            edgeTypes.append(try result.edgeType(for: edge))
        }
        #expect(edgeTypes[0].id == edgeTypes[1].id)
    }

    // MARK: - Integration Tests

    @Test
    func complexScenario_multipleFoldedGroupsWithCrossingEdges() throws(VError) {
        var graph = try createBaseGraph()

        graph = try graph.add(group: group1)
        graph = try graph.add(node: n1, type: nt1, group: group1)
        graph = try graph.add(node: n2, type: nt1, group: group1)

        graph = try graph.add(group: group2)
        graph = try graph.add(group: group3)
        graph = try graph.addTo(group: group2, childGroup: group3)
        graph = try graph.add(node: n3, type: nt1, group: group3)

        graph = try graph.add(node: n4, type: nt1)

        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!

        // Internal edge in group1
        let e1 = Edge(string: "e1", from: n1.id.description, to: n2.id.description)
        graph = try graph.add(edge: e1, edgeType: edgeType)

        // Crossing edge: group1 -> group2
        let e2 = Edge(string: "e2", from: n1.id.description, to: n3.id.description)
        graph = try graph.add(edge: e2, edgeType: edgeType)

        // Crossing edge: outside -> group1
        let e3 = Edge(string: "e3", from: n4.id.description, to: n2.id.description)
        graph = try graph.add(edge: e3, edgeType: edgeType)

        graph = try foldGroup(group1, in: graph)
        graph = try foldGroup(group2, in: graph)

        let result = try applyFoldingLayoutStep(to: graph)

        // Then:
        // - n1, n2, n3 deleted
        // - n4 remains
        // - GroupNode(group1) and GroupNode(group2) created
        // - e1 deleted (internal)
        // - e2 redirected: GroupNode(group1) -> GroupNode(group2)
        // - e3 redirected: n4 -> GroupNode(group1)
        // - group3 deleted

        #expect(!result.has(node: n1))
        #expect(!result.has(node: n2))
        #expect(!result.has(node: n3))
        #expect(result.has(node: n4))
        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.has(node: groupNode(for: group2)))

        #expect(result.edges.count == 2)
        #expect(!result.has(group: group3))

        let edgeE2 = result.get(edge: Edge.Id(string: "e2"))!
        #expect(edgeE2.from == groupNode(for: group1))
        #expect(edgeE2.to == groupNode(for: group2))

        let edgeE3 = result.get(edge: Edge.Id(string: "e3"))!
        #expect(edgeE3.from == n4)
        #expect(edgeE3.to == groupNode(for: group1))
    }

    // MARK: - Pipeline Integration Tests

    @Test
    func foldingLayoutStep_worksWithLayoutPipelineCompose() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1)
        graph = try addEdgeType(to: graph, from: nt1, to: nt1, id: "e_nt1_nt1")
        let edge = Edge(string: "e1", from: n2.id.description, to: n1.id.description)
        let edgeType = graph.get(edgeType: "e_nt1_nt1")!
        graph = try graph.add(edge: edge, edgeType: edgeType)
        graph = try foldGroup(group1, in: graph)

        let pipeline = TransformPipeline.compose(applyFoldingLayoutStep)
        let result = try pipeline(graph)

        #expect(!result.has(node: n1))
        #expect(result.has(node: n2))
        #expect(result.has(node: groupNode(for: group1)))
        #expect(result.edges.count == 1)

        let redirectedEdge = result.edges.first!
        #expect(redirectedEdge.to == groupNode(for: group1))
    }

    @Test
    func foldingLayoutStep_composesWithOtherTransforms() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1)
        graph = try foldGroup(group1, in: graph)

        // A simple transform that adds a node to the graph (to verify composition works)
        let extraNode = Node("extraNode")
        let addExtraNode: GraphTransform = { g in
            return try g.add(node: extraNode, type: Notations.FoldGroups.NodeTypes.foldedGroup)
        }

        let pipeline = TransformPipeline.compose(
            applyFoldingLayoutStep,
            addExtraNode
        )
        let result = try pipeline(graph)

        // Then: Both transforms were applied
        #expect(!result.has(node: n1))
        #expect(result.has(node: groupNode(for: group1)))

        #expect(result.has(node: extraNode))
    }

    @Test
    func foldingLayoutStep_firstInPipeline_subsequentTransformsOperateOnFoldedGraph() throws(VError) {
        var graph = try createBaseGraph()
            .add(group: group1)
            .add(node: n1, type: nt1, group: group1)
            .add(node: n2, type: nt1, group: group1)
            .add(node: n3, type: nt1)
        graph = try foldGroup(group1, in: graph)

        var nodeCountDuringTransform = 0
        let countNodes: GraphTransform = { g in
            nodeCountDuringTransform = g.nodes.count
            return g
        }

        let pipeline = TransformPipeline.compose(
            applyFoldingLayoutStep,
            countNodes
        )
        _ = try pipeline(graph)

        // Then: The count transform sees the folded graph (2 nodes: GroupNode + n3)
        // not the original (3 nodes: n1, n2, n3)
        #expect(nodeCountDuringTransform == 2)
    }
}
