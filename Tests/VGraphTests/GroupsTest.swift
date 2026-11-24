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
    let nt1 = NodeType("nt1")
    let nt2 = NodeType("nt2")

    @Test
    func reassignNode() throws(VError) {
        let groups = try GroupStructure()
            .adding(group: c1)
            .addingTo(group: c1, node: n1)
            .adding(group: c2)
            .addingTo(group: c2, node: n1)
        #expect(try groups.directContent(of: c1) == ([], []))
        #expect(try groups.directContent(of: c2) == ([], [n1]))
    }

    @Test("Adding a node to the group it is already in changes nothing")
    func addingAMemberAgainChangesNothing() throws(VError) {
        let once = try GroupStructure().adding(group: c1).addingTo(group: c1, node: n1)
        #expect(try once.addingTo(group: c1, node: n1) == once)
    }

    @Test
    func addgroupHierarchy() throws(VError) {
        var groups = GroupStructure()
        groups =
            try groups
            .adding(group: c1)
            .addingTo(group: c1, node: n1)
            .adding(group: c2)
            .addingTo(group: c2, node: n2)
            .addingTo(group: c1, childGroup: c2)
            .adding(group: c3)
            .addingTo(group: c3, node: n3)
            .addingTo(group: c2, childGroup: c3)
        let direct = try groups.directContent(of: c1)
        #expect(direct == ([c2], [n1]))
        #expect(try groups.allContent(of: c1) == ([c2, c3], [n1, n2, n3]))
    }

    @Test
    func reassigngroupHierarchy() throws(VError) {
        var groups = GroupStructure()
        groups =
            try groups
            .adding(group: c1)
            .addingTo(group: c1, node: n1)
            .adding(group: c2)
            .addingTo(group: c2, node: n2)
            .addingTo(group: c1, childGroup: c2)
            .adding(group: c3)
            .addingTo(group: c3, node: n3)
            .addingTo(group: c2, childGroup: c3)
            .addingTo(group: c1, childGroup: c3)
        let direct = try groups.directContent(of: c1)
        #expect(direct == ([c2, c3], [n1]))
        #expect(try groups.allContent(of: c2) == ([], [n2]))
        #expect(try groups.allContent(of: c1) == ([c2, c3], [n1, n2, n3]))
    }

    @Test
    func removeNode() throws(VError) {
        let groups = try GroupStructure()
            .adding(group: c1)
            .addingTo(group: c1, node: n1)
            .removingFromGroup(node: n1)
        #expect(try groups.directContent(of: c1) == ([], []))
        #expect(try groups.allContent(of: c1) == ([], []))
        #expect(groups.group(of: n1) == nil)
    }

    @Test
    func findgroup() throws(VError) {
        let groups = try VGraph()
            .adding(nodeType: nt1)
            .adding(node: n1, type: nt1)
            .adding(group: c1)
            .addingTo(group: c1, node: n1)
            .adding(group: c2)
            .adding(nodeType: nt2)
            .adding(node: n2, type: nt2)
            .addingTo(group: c2, node: n2)
            .addingTo(group: c1, childGroup: c2)
            .adding(group: c3)
            .addingTo(group: c2, childGroup: c3)
        #expect(groups.group(of: n1) == c1)
        #expect(groups.group(of: n2) == c2)
        #expect(groups.group(of: n3) == nil)
        #expect(groups.parentGroup(of: c1) == nil)
        #expect(groups.parentGroup(of: c2) == c1)
        #expect(groups.parentGroup(of: c3) == c2)
    }

    @Test
    func foldStates() throws(VError) {
        let groups = try VGraph()
            .adding(group: c1)
            .adding(nodeType: nt1)
            .adding(node: n1, type: nt1)
            .addingTo(group: c1, node: n1)
            .adding(group: c2)
            .adding(nodeType: nt2)
            .adding(node: n2, type: nt2)
            .addingTo(group: c2, node: n2)
            .addingTo(group: c1, childGroup: c2)
            .adding(group: c3)
            .adding(node: n3, type: nt2)
            .addingTo(group: c3, node: n3)
            .addingTo(group: c2, childGroup: c3)
            .defining(Attributes.Group.isFolded)
            .setting(group: c2, attribute: Attributes.Group.isFolded(true))
        #expect(groups.foldState(of: c1) == .unfolded)
        #expect(groups.foldState(of: c2) == .folded)
        #expect(groups.foldState(of: c3) == .hidden)
    }

    // MARK: - Deep Nesting Tests

    private func createDeeplyNestedGroups(depth: Int) throws(VError) -> (GroupStructure, Group, [Group]) {
        var groups = GroupStructure()
        var allGroups: [Group] = []

        let rootGroup = Group(rawValue: "g0")
        groups = groups.adding(group: rootGroup)
        allGroups.append(rootGroup)

        for i in 1..<depth {
            let newGroup = Group(rawValue: "g\(i)")
            let parentGroup = allGroups[i - 1]
            groups = groups.adding(group: newGroup)
            groups = try groups.addingTo(group: parentGroup, childGroup: newGroup)
            allGroups.append(newGroup)
        }

        return (groups, rootGroup, allGroups)
    }

    @Test
    func deeplyNestedGroups10Levels() throws(VError) {
        let depth = 10
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        let (nestedGroups, _) = try groups.allContent(of: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        for i in 1..<depth {
            #expect(groups.parentGroup(of: allGroups[i]) == allGroups[i - 1])
        }

        #expect(groups.isAncestor(allGroups[0], of: allGroups[depth - 1]))
    }

    @Test
    func deeplyNestedGroups200Levels() throws(VError) {
        let depth = 200
        let (groups, rootGroup, allGroups) = try createDeeplyNestedGroups(depth: depth)

        let (nestedGroups, _) = try groups.allContent(of: rootGroup)
        #expect(nestedGroups.count == depth - 1)

        #expect(groups.isAncestor(allGroups[0], of: allGroups[depth - 1]))
        #expect(groups.isAncestor(allGroups[50], of: allGroups[99]))
        #expect(!groups.isAncestor(allGroups[50], of: allGroups[25]))
    }

    @Test
    func deeplyNestedGroupsWithNodes() throws(VError) {
        let depth = 50
        var groups = GroupStructure()
        var allGroups: [Group] = []
        var allNodes: [Node] = []

        let rootGroup = Group(rawValue: "g0")
        let rootNode = Node(rawValue: "n0")
        groups = groups.adding(group: rootGroup)
        groups = try groups.addingTo(group: rootGroup, node: rootNode)
        allGroups.append(rootGroup)
        allNodes.append(rootNode)

        for i in 1..<depth {
            let newGroup = Group(rawValue: "g\(i)")
            let newNode = Node(rawValue: "n\(i)")
            let parentGroup = allGroups[i - 1]

            groups = groups.adding(group: newGroup)
            groups = try groups.addingTo(group: parentGroup, childGroup: newGroup)
            groups = try groups.addingTo(group: newGroup, node: newNode)

            allGroups.append(newGroup)
            allNodes.append(newNode)
        }

        let (nestedGroups, nestedNodes) = try groups.allContent(of: rootGroup)
        #expect(nestedGroups.count == depth - 1)
        #expect(nestedNodes.count == depth)

        for node in allNodes {
            #expect(nestedNodes.contains(node))
        }
    }

    @Test
    func wideGroupHierarchy() throws(VError) {
        let width = 100
        var groups = GroupStructure()
        let rootGroup = Group(rawValue: "root")
        groups = groups.adding(group: rootGroup)

        var childGroups: [Group] = []
        for i in 0..<width {
            let child = Group(rawValue: "child\(i)")
            groups = groups.adding(group: child)
            groups = try groups.addingTo(group: rootGroup, childGroup: child)
            childGroups.append(child)
        }

        let (nestedGroups, _) = try groups.allContent(of: rootGroup)
        #expect(nestedGroups.count == width)

        for child in childGroups {
            #expect(groups.parentGroup(of: child) == rootGroup)
            #expect(groups.isAncestor(rootGroup, of: child))
        }
    }
}
