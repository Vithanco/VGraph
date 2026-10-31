public struct GroupStructure: VProtocol {

    /// No `edge` case: an edge's group is derived from its endpoints, so there is
    /// nothing here to keep in step with them.
    private enum GroupEntry: VProtocol {
        case node(Node)
        case subGroup(Group)
    }

    private typealias SubGroupMapping = OneToManyLookup<Group, GroupEntry>

    let subGroups: [Group]
    private let groupSet: Set<Group>
    private let mapping: SubGroupMapping
    /// ADR-0032: a group is plain, its group type optional (ADR-0030), or a
    /// detailed node carrying a node type. One enum so it is never both.
    private enum Typing: VProtocol {
        case plain(GroupType)
        case detailed(NodeType)
    }

    private let types: [Group: Typing]

    init() {
        let root = Group(rawValue: rootGroup)
        subGroups = [root]
        groupSet = [root]
        mapping = OneToManyLookup()
        types = [:]
    }

    private init(subgraphs: [Group], groupSet: Set<Group>, mapping: SubGroupMapping, types: [Group: Typing]) {
        self.subGroups = subgraphs
        self.groupSet = groupSet
        self.mapping = mapping
        self.types = types
    }

    public func type(of group: Group) -> GroupType? {
        guard case .plain(let type) = types[group] else { return nil }
        return type
    }

    public func nodeType(of group: Group) -> NodeType? {
        guard case .detailed(let type) = types[group] else { return nil }
        return type
    }

    func typing(_ group: Group, as type: GroupType?) throws(VError) -> GroupStructure {
        try retyping(group, as: type.map { Typing.plain($0) })
    }

    func typing(_ group: Group, as type: NodeType) throws(VError) -> GroupStructure {
        try retyping(group, as: .detailed(type))
    }

    private func retyping(_ group: Group, as typing: Typing?) throws(VError) -> GroupStructure {
        try assertGroupExists(group)
        var newTypes = types
        newTypes[group] = typing
        return GroupStructure(subgraphs: subGroups, groupSet: groupSet, mapping: mapping, types: newTypes)
    }

    func add(group: Group) throws(VError) -> GroupStructure {
        if groupSet.contains(group) {
            return self
        }
        let newSubgraphs = subGroups + [group]
        let newGroupSet = groupSet.union([group])
        return GroupStructure(subgraphs: newSubgraphs, groupSet: newGroupSet, mapping: mapping, types: types)
    }

    func remove(group: Group) throws(VError) -> GroupStructure {
        if let index = subGroups.firstIndex(of: group) {
            var newGroups = subGroups
            newGroups.remove(at: index)
            let newGroupSet = groupSet.subtracting([group])
            var newMapping = mapping
            newMapping = newMapping.remove(one: group)
            newMapping = newMapping.remove(many: .subGroup(group))
            var newTypes = types
            newTypes[group] = nil
            return GroupStructure(subgraphs: newGroups, groupSet: newGroupSet, mapping: newMapping, types: newTypes)
        }
        throw VError.groupNotFound(group)
    }

    private func removeGroupEntry(_ manyEntry: GroupStructure.GroupEntry) -> GroupStructure {
        if mapping.getOne(many: manyEntry) != nil {
            var newMapping = mapping
            newMapping = newMapping.remove(many: manyEntry)
            return GroupStructure(subgraphs: subGroups, groupSet: groupSet, mapping: newMapping, types: types)
        }
        return self
    }
    private func addEntry(manyEntry: GroupStructure.GroupEntry, subgraph: Group) -> GroupStructure {
        return GroupStructure(
            subgraphs: subGroups, groupSet: groupSet, mapping: mapping.add(many: manyEntry, one: subgraph),
            types: types)
    }

    func removeFromGroup(node: Node) -> GroupStructure {
        let manyEntry = GroupEntry.node(node)
        return removeGroupEntry(manyEntry)
    }

    func removeFromGroup(subGroup: Group) -> GroupStructure {
        let manyEntry = GroupEntry.subGroup(subGroup)
        return removeGroupEntry(manyEntry)
    }

    func addTo(group: Group?, node: Node) throws(VError) -> GroupStructure {
        guard let group = group else {
            return removeFromGroup(node: node)
        }
        try assertGroupExists(group)
        if mapping.getOne(many: GroupEntry.node(node)) == group {
            throw VError.nodeAlreadyInGroup(group: group, node: node)
        }
        return addEntry(manyEntry: GroupEntry.node(node), subgraph: group)
    }

    fileprivate func assertGroupExists(_ group: Group) throws(VError) {
        if !groupSet.contains(group) {
            throw VError.groupNotFound(group)
        }
    }

    func addTo(group: Group, childGroup: Group) throws(VError) -> GroupStructure {
        try assertGroupExists(group)

        let manyEntry = GroupEntry.subGroup(childGroup)
        if mapping.getOne(many: manyEntry) == group {
            return self
        }

        return addEntry(manyEntry: manyEntry, subgraph: group)
    }

    private func splitEntries(_ content: Set<GroupStructure.GroupEntry>) -> ([Group], [Node]) {
        let groups: [Group] = content.compactMap { element in
            guard case .subGroup(let group) = element else {
                return nil
            }
            return group
        }
        let nodes: [Node] = content.compactMap { element in
            guard case .node(let nodeId) = element else {
                return nil
            }
            return nodeId
        }
        return (groups.sorted(), nodes.sorted())
    }

    public func getDirectContent(group: Group) throws(VError) -> ([Group], [Node]) {
        try assertGroupExists(group)
        let content = mapping.getMany(one: group) ?? Set<GroupStructure.GroupEntry>()
        return splitEntries(content)
    }

    public func getAllContent(group: Group) throws(VError) -> ([Group], [Node]) {
        try assertGroupExists(group)
        let (directGroups, directNodes) = try getDirectContent(group: group)
        var resultGroups = directGroups
        var resultNodes = directNodes
        for childGroup in directGroups {
            let (nestedGroups, nestedNodes) = try getAllContent(group: childGroup)
            resultGroups.append(contentsOf: nestedGroups)
            resultNodes.append(contentsOf: nestedNodes)
        }
        return (resultGroups, resultNodes)
    }

    public func has(group: Group) -> Bool {
        return groupSet.contains(group)
    }

    public func group(of node: Node) -> Group? {
        return mapping.getOne(many: GroupEntry.node(node))
    }

    public func parentGroup(of group: Group) -> Group? {
        return mapping.getOne(many: GroupEntry.subGroup(group))
    }

    public func isParent(parent: Group, child: Group) -> Bool {
        if let childParent = parentGroup(of: child) {
            if childParent == parent {
                return true
            }
            return isParent(parent: parent, child: childParent)
        }
        return false
    }
}

extension GroupStructure {
    public struct Counts: VProtocol {
        let groupCount: Int
        let nodeCount: Int
        let groupsInGroupCount: Int
    }

    public var counts: Counts {
        let (groupEntries, nodeEntries) = splitEntries(mapping.getAllManys)
        // Exclude the internal rootGroup from the public count (always present)
        return Counts(
            groupCount: subGroups.count - 1, nodeCount: nodeEntries.count, groupsInGroupCount: groupEntries.count)
    }
}
