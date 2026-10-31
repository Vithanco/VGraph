import Testing

@testable import VGraph

@Suite
struct GroupsTest {
    let c1 = Group(rawValue: "c1")
    let c2 = Group(rawValue: "c2")
    let c3 = Group(rawValue: "c3")
    let n1 = Node("n1")
    let n2 = Node("n2")
    let n3 = Node("n3")
    let n4 = Node("n4")
    let nt1 = NodeType("nt1")
    let nt2 = NodeType("nt2")

    @Test
    func createEmpty() throws(VError) {
        let groups = GroupStructure()
        #expect(groups.counts == GroupStructure.Counts(groupCount: 0, nodeCount: 0, groupsInGroupCount: 0))
    }

    @Test
    func addgroupAndNode() throws(VError) {
        var groups = GroupStructure()
        groups = try groups.add(group: c1).addTo(group: c1, node: n1)
        #expect(groups.counts == GroupStructure.Counts(groupCount: 1, nodeCount: 1, groupsInGroupCount: 0))
        #expect(try groups.getDirectContent(group: c1) == ([], [n1]))
        #expect(try groups.getAllContent(group: c1) == ([], [n1]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 1, nodeCount: 1, groupsInGroupCount: 0))
    }

    @Test
    func reassignNode() throws(VError) {
        let groups = try GroupStructure()
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .addTo(group: c2, node: n1)
        #expect(groups.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 1, groupsInGroupCount: 0))
        #expect(try groups.getDirectContent(group: c1) == ([], []))
        #expect(try groups.getDirectContent(group: c2) == ([], [n1]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 1, groupsInGroupCount: 0))
    }

    @Test
    func addNodeTwiceLeadsToError() throws(VError) {
        #expect(throws: VError.nodeAlreadyInGroup(group: c1, node: n1)) {
            _ = try GroupStructure()
                .add(group: c1)
                .addTo(group: c1, node: n1)
                .addTo(group: c1, node: n1)
        }
    }

    @Test
    func addgroupTogroup() throws(VError) {
        var groups = GroupStructure()
        groups =
            try groups
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
        let direct = try groups.getDirectContent(group: c1)
        #expect(direct == ([c2], [n1]))
        #expect(try groups.getAllContent(group: c1) == ([c2], [n1, n2]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 2, groupsInGroupCount: 1))
    }

    @Test
    func addgroupHierarchy() throws(VError) {
        var groups = GroupStructure()
        groups =
            try groups
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .add(group: c3)
            .addTo(group: c3, node: n3)
            .addTo(group: c2, childGroup: c3)
        let direct = try groups.getDirectContent(group: c1)
        #expect(direct == ([c2], [n1]))
        #expect(try groups.getAllContent(group: c1) == ([c2, c3], [n1, n2, n3]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 3, nodeCount: 3, groupsInGroupCount: 2))
    }

    @Test
    func reassigngroupHierarchy() throws(VError) {
        var groups = GroupStructure()
        groups =
            try groups
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .add(group: c3)
            .addTo(group: c3, node: n3)
            .addTo(group: c2, childGroup: c3)
            .addTo(group: c1, childGroup: c3)
        let direct = try groups.getDirectContent(group: c1)
        #expect(direct == ([c2, c3], [n1]))
        #expect(try groups.getAllContent(group: c2) == ([], [n2]))
        #expect(try groups.getAllContent(group: c1) == ([c2, c3], [n1, n2, n3]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 3, nodeCount: 3, groupsInGroupCount: 2))
    }

    @Test
    func removeNode() throws(VError) {
        let groups = try GroupStructure()
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .removeFromGroup(node: n1)
        #expect(try groups.getDirectContent(group: c1) == ([], []))
        #expect(try groups.getAllContent(group: c1) == ([], []))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 1, nodeCount: 0, groupsInGroupCount: 0))
    }

    @Test
    func removegroup() throws(VError) {
        let groups = try GroupStructure()
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .removeFromGroup(subGroup: c2)
        #expect(try groups.getDirectContent(group: c1) == ([], [n1]))
        #expect(try groups.getAllContent(group: c1) == ([], [n1]))
        #expect(try groups.getAllContent(group: c2) == ([], [n2]))
        #expect(groups.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 2, groupsInGroupCount: 0))
    }

    @Test
    func findgroup() throws(VError) {
        let groups = try VGraph()
            .add(nodeType: nt1)
            .add(node: n1, type: nt1)
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .add(nodeType: nt2)
            .add(node: n2, type: nt2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .add(group: c3)
            .addTo(group: c2, childGroup: c3)
        #expect(groups.group(of: n1) == c1)
        #expect(groups.group(of: n2) == c2)
        #expect(groups.group(of: n3) == nil)
        #expect(groups.parentGroup(of: c1) == nil)
        #expect(groups.parentGroup(of: c2) == c1)
        #expect(groups.parentGroup(of: c3) == c2)
    }

    @Test
    func isParent() throws(VError) {
        let groups = try VGraph()
            .add(group: c3)
            .add(group: c1)
            .add(group: c2)
            .addTo(group: c1, childGroup: c2)
            .addTo(group: c2, childGroup: c3)
        #expect(groups.groupsOrderedByOwnership == [c1, c2, c3])
    }

    @Test
    func nodeVisibility() throws(VError) {
        let groups = try VGraph()
            .add(group: c1)
            .add(nodeType: nt1)
            .add(node: n1, type: nt1)
            .addTo(group: c1, node: n1)
            .add(group: c2)
            .add(nodeType: nt2)
            .add(node: n2, type: nt2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .add(group: c3)
            .add(node: n3, type: nt2)
            .addTo(group: c3, node: n3)
            .addTo(group: c2, childGroup: c3)
            .define(attribute: Attributes.Group.isFolded)
            .set(group: c2, def: Attributes.Group.isFolded, value: true)
        #expect(try groups.getAllContent(group: c1) == ([c2, c3], [n1, n2, n3]))
        #expect(groups.isVisible(node: n1))
        #expect(!groups.isVisible(node: n2))
        #expect(!groups.isVisible(node: n3))
        #expect(groups.foldingState(group: c1) == .normal)
        #expect(groups.foldingState(group: c2) == .folded)
        #expect(groups.foldingState(group: c3) == .hidden)
    }

    @Test
    func groupForNode() throws(VError) {
        let groups = try VGraph()
            .add(nodeType: nt1)
            .add(node: n1, type: nt1)
            .add(group: c1)
            .addTo(group: c1, node: n1)
            .add(nodeType: nt2)
            .add(node: n2, type: nt2)
            .add(group: c2)
            .addTo(group: c2, node: n2)
            .addTo(group: c1, childGroup: c2)
            .add(group: c3)
            .add(node: n3, type: nt2)
            .addTo(group: c3, node: n3)
            .addTo(group: c2, childGroup: c3)
            .define(attribute: Attributes.Group.isFolded)
            .set(group: c2, def: Attributes.Group.isFolded, value: true)
        #expect(groups.getVisibleNode(for: n1) == n1)
        #expect(groups.getVisibleNode(for: n2) == Node(c2))
        #expect(groups.getVisibleNode(for: n3) == Node(c2))
        #expect(groups.getVisibleNode(for: n4) == n4)
    }

    @Test
    func notChangingOldValues() throws(VError) {
        let groups = try GroupStructure()
            .add(group: c1)
        let groups2 =
            try groups
            .addTo(group: c1, node: n1)
        #expect(groups.counts == GroupStructure.Counts(groupCount: 1, nodeCount: 0, groupsInGroupCount: 0))
        #expect(groups2.counts == GroupStructure.Counts(groupCount: 1, nodeCount: 1, groupsInGroupCount: 0))
    }

    // MARK: - Deep Nesting Tests

    /// Helper to create a deeply nested group hierarchy
    private func createDeeplyNestedGroups(depth: Int) throws(VError) -> (GroupStructure, Group, [Group]) {
        var groups = GroupStructure()
        var allGroups: [Group] = []

        let rootGroup = Group(rawValue: "g0")
        groups = try groups.add(group: rootGroup)
        allGroups.append(rootGroup)

        for i in 1..<depth {
            let newGroup = Group(rawValue: "g\(i)")
            let parentGroup = allGroups[i - 1]
            groups = try groups.add(group: newGroup)
            groups = try groups.addTo(group: parentGroup, childGroup: newGroup)
            allGroups.append(newGroup)
        }

        return (groups, rootGroup, allGroups)
    }

    @Test
    func deeplyNestedGroups10Levels() throws(VError) {
        let depth = 10
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        #expect(groups.counts.groupCount == depth)
        #expect(groups.counts.groupsInGroupCount == depth - 1)

        // getAllContent from root should return all nested groups
        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        for i in 1..<depth {
            #expect(groups.parentGroup(of: allGroups[i]) == allGroups[i - 1])
        }

        #expect(groups.isParent(parent: allGroups[0], child: allGroups[depth - 1]))
    }

    @Test
    func deeplyNestedGroups50Levels() throws(VError) {
        let depth = 50
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        #expect(groups.counts.groupCount == depth)

        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        #expect(groups.isParent(parent: allGroups[0], child: allGroups[depth - 1]))
    }

    @Test
    func deeplyNestedGroups100Levels() throws(VError) {
        let depth = 100
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        #expect(groups.counts.groupCount == depth)

        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        #expect(groups.isParent(parent: allGroups[0], child: allGroups[depth - 1]))
        #expect(groups.isParent(parent: allGroups[50], child: allGroups[99]))
        #expect(!groups.isParent(parent: allGroups[50], child: allGroups[25]))
    }

    @Test
    func deeplyNestedGroupsWithNodes() throws(VError) {
        let depth = 50
        var groups = GroupStructure()
        var allGroups: [Group] = []
        var allNodes: [Node] = []

        let rootGroup = Group(rawValue: "g0")
        let rootNode = Node(rawValue: "n0")
        groups = try groups.add(group: rootGroup)
        groups = try groups.addTo(group: rootGroup, node: rootNode)
        allGroups.append(rootGroup)
        allNodes.append(rootNode)

        for i in 1..<depth {
            let newGroup = Group(rawValue: "g\(i)")
            let newNode = Node(rawValue: "n\(i)")
            let parentGroup = allGroups[i - 1]

            groups = try groups.add(group: newGroup)
            groups = try groups.addTo(group: parentGroup, childGroup: newGroup)
            groups = try groups.addTo(group: newGroup, node: newNode)

            allGroups.append(newGroup)
            allNodes.append(newNode)
        }

        #expect(groups.counts.groupCount == depth)
        #expect(groups.counts.nodeCount == depth)

        // getAllContent should return all groups and all nodes
        let (nestedGroups, nestedNodes) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == depth - 1)
        #expect(nestedNodes.count == depth)

        for node in allNodes {
            #expect(nestedNodes.contains(node))
        }
    }

    @Test
    func deeplyNestedGroups200Levels() throws(VError) {
        let depth = 200
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        #expect(groups.counts.groupCount == depth)

        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        #expect(groups.isParent(parent: allGroups[0], child: allGroups[depth - 1]))
    }

    @Test
    func wideGroupHierarchy() throws(VError) {
        // Test many siblings at the same level (breadth vs depth)
        let width = 100
        var groups = GroupStructure()
        let rootGroup = Group(rawValue: "root")
        groups = try groups.add(group: rootGroup)

        var childGroups: [Group] = []
        for i in 0..<width {
            let child = Group(rawValue: "child\(i)")
            groups = try groups.add(group: child)
            groups = try groups.addTo(group: rootGroup, childGroup: child)
            childGroups.append(child)
        }

        #expect(groups.counts.groupCount == width + 1)
        #expect(groups.counts.groupsInGroupCount == width)

        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == width)

        // All children have root as parent
        for child in childGroups {
            #expect(groups.parentGroup(of: child) == rootGroup)
            #expect(groups.isParent(parent: rootGroup, child: child))
        }
    }

    @Test
    func mixedDeepAndWideHierarchy() throws(VError) {
        // Create a tree: 5 levels deep, 3 children at each level
        let depth = 5
        let width = 3
        var groups = GroupStructure()

        let rootGroup = Group(rawValue: "root")
        groups = try groups.add(group: rootGroup)

        // Build iteratively using a queue to avoid closure capture issues
        var queue: [(parent: Group, depth: Int)] = [(rootGroup, 1)]
        var totalGroups = 1  // root

        while let current = queue.first {
            queue.removeFirst()

            guard current.depth < depth else { continue }

            for w in 0..<width {
                let child = Group(rawValue: "g_\(current.depth)_\(w)_\(totalGroups)")
                groups = try groups.add(group: child)
                groups = try groups.addTo(group: current.parent, childGroup: child)
                totalGroups += 1
                queue.append((child, current.depth + 1))
            }
        }

        #expect(groups.counts.groupCount == totalGroups)

        // getAllContent should return all descendant groups
        let (nestedGroups, _) = try groups.getAllContent(group: rootGroup)
        #expect(nestedGroups.count == totalGroups - 1)
    }
}
