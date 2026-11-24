public struct GroupStructure: VProtocol {

    /// No `edge` case: an edge's group is derived from its endpoints, so there is
    /// nothing here to keep in step with them.
    private enum GroupEntry: VProtocol {
        case node(Node)
        case subGroup(Group)
    }

    private typealias SubGroupMapping = OneToManyLookup<Group, GroupEntry>

    let allGroups: [Group]
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
        let root = Group.root
        allGroups = [root]
        groupSet = [root]
        mapping = OneToManyLookup()
        types = [:]
    }

    private init(groups: [Group], groupSet: Set<Group>, mapping: SubGroupMapping, types: [Group: Typing]) {
        self.allGroups = groups
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
        try ensureExists(group: group)
        var newTypes = types
        newTypes[group] = typing
        return GroupStructure(groups: allGroups, groupSet: groupSet, mapping: mapping, types: newTypes)
    }

    func adding(group: Group) -> GroupStructure {
        if groupSet.contains(group) {
            return self
        }
        return GroupStructure(groups: allGroups + [group], groupSet: groupSet.union([group]), mapping: mapping, types: types)
    }

    func removing(group: Group) throws(VError) -> GroupStructure {
        try ensureExists(group: group)
        var newTypes = types
        newTypes[group] = nil
        return GroupStructure(
            groups: allGroups.filter { $0 != group }, groupSet: groupSet.subtracting([group]),
            mapping: mapping.removing(one: group).removing(many: .subGroup(group)), types: newTypes)
    }

    private func removingGroupEntry(_ manyEntry: GroupStructure.GroupEntry) -> GroupStructure {
        guard mapping.getOne(many: manyEntry) != nil else { return self }
        return GroupStructure(groups: allGroups, groupSet: groupSet, mapping: mapping.removing(many: manyEntry), types: types)
    }

    private func addingEntry(manyEntry: GroupStructure.GroupEntry, group: Group) -> GroupStructure {
        return GroupStructure(
            groups: allGroups, groupSet: groupSet, mapping: mapping.adding(many: manyEntry, one: group),
            types: types)
    }

    func removingFromGroup(node: Node) -> GroupStructure {
        let manyEntry = GroupEntry.node(node)
        return removingGroupEntry(manyEntry)
    }

    /// Moves the node out of any group it was in; adding it where it is changes nothing.
    func addingTo(group: Group, node: Node) throws(VError) -> GroupStructure {
        try ensureExists(group: group)
        return addingEntry(manyEntry: GroupEntry.node(node), group: group)
    }

    private func ensureExists(group: Group) throws(VError) {
        guard groupSet.contains(group) else {
            throw VError.groupNotFound(group)
        }
    }

    func addingTo(group: Group, childGroup: Group) throws(VError) -> GroupStructure {
        try ensureExists(group: group)
        return addingEntry(manyEntry: GroupEntry.subGroup(childGroup), group: group)
    }

    private func splitEntries(_ content: Set<GroupStructure.GroupEntry>) -> (groups: [Group], nodes: [Node]) {
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

    public func directContent(of group: Group) throws(VError) -> (groups: [Group], nodes: [Node]) {
        try ensureExists(group: group)
        let content = mapping.getMany(one: group) ?? Set<GroupStructure.GroupEntry>()
        return splitEntries(content)
    }

    public func allContent(of group: Group) throws(VError) -> (groups: [Group], nodes: [Node]) {
        let (directGroups, directNodes) = try directContent(of: group)
        let nested = try directGroups.map { (child) throws(VError) in try allContent(of: child) }
        return (directGroups + nested.flatMap { $0.groups }, directNodes + nested.flatMap { $0.nodes })
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

    /// At any depth: a group's parent, its parent's parent, and so on.
    public func isAncestor(_ ancestor: Group, of descendant: Group) -> Bool {
        guard let parent = parentGroup(of: descendant) else { return false }
        return parent == ancestor || isAncestor(ancestor, of: parent)
    }
}
