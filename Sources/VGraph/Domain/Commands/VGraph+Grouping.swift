// Making and unmaking groups, and the canonical form over the group tree that
// the editor's [[Effective selection]] is. See ADR-0018.

extension VGraph {

    /// The outermost elements of a set: complete groups collapsed upward, to a
    /// fixpoint. What the editor's [[Effective selection]] is (ADR-0018).
    ///
    /// Promotion needs **all direct children**, not the same nodes underneath: a
    /// group holding a node and an empty subgroup must not promote on the node
    /// alone, or the untouched subgroup joins whatever runs next.
    ///
    /// It also stops below the [[Root group]], which is the one group that cannot
    /// be pointed at — a click on blank canvas clears — so it has no business in a
    /// set assembled by pointing, however true an answer it is.
    public func outermostElements(of ids: [String]) -> [String] {
        let promoted = promotingCompleteGroups(in: nodeAndGroupIds(among: ids))
        return promoted.filter { !isCovered($0, by: promoted) }.sorted()

        func nodeAndGroupIds(among ids: [String]) -> Set<String> {
            Set(ids.compactMap { resolveCommandTarget(id: $0) }.filter { $0.kind != .edge }.map { $0.elementId })
        }

        func promotingCompleteGroups(in selected: Set<String>) -> Set<String> {
            let complete = groups.filter { !selected.contains($0.id.id) && isComplete($0, within: selected) }
            guard !complete.isEmpty else { return selected }
            return promotingCompleteGroups(in: selected.union(complete.map { $0.id.id }))
        }

        /// An empty group is never complete, or promotion would invent it.
        func isComplete(_ group: Group, within selected: Set<String>) -> Bool {
            let children = directChildIds(of: group)
            return !children.isEmpty && children.allSatisfy { selected.contains($0) }
        }

        func isCovered(_ id: String, by selected: Set<String>) -> Bool {
            groupAncestry(from: parentOfElement(id)).contains { selected.contains($0.id.id) }
        }
    }

    func directChildIds(of group: Group) -> [String] {
        guard let (childGroups, childNodes) = try? directContent(of: group) else { return [] }
        return childGroups.map { $0.id.id } + childNodes.map { $0.id }
    }

    /// The root when nothing else holds it — the fallback ADR-0017 chose for an
    /// edge, so the two never disagree about what "no particular group" means.
    func parentOfElement(_ id: String) -> Group? {
        guard let target = resolveCommandTarget(id: id) else { return nil }
        switch target {
        case .node(let node): return group(of: node) ?? Group.root
        case .group(let group):
            if group == Group.root { return nil }
            return parentGroup(of: group) ?? Group.root
        case .edge: return nil
        }
    }
}

extension VGraph {

    /// Call *immediately after* removing a child, which is what makes this a rule
    /// about commands rather than an invariant on the graph: a hand-written empty
    /// group is never passed here, so it survives a parse and export unchanged
    /// (ADR-0018).
    public func removingEmptied(from group: Group?) throws(VError) -> VGraph {
        guard let group, group != Group.root, has(group: group), directChildIds(of: group).isEmpty else {
            return self
        }
        // A detailed node is a node that has details: emptied, it is a node
        // again, which its parent still holds (ADR-0032).
        if let type = nodeType(of: group) { return try undetailing(group, ofType: type) }
        return try deleting(group: group).removingEmptied(from: parentGroup(of: group))
    }

    private func undetailing(_ detailedNode: Group, ofType type: NodeType) throws(VError) -> VGraph {
        let node = Node(detailedNode)
        return try replacing(detailed: detailedNode, withNodeOfType: type, in: parentGroup(of: detailedNode) ?? Group.root)
            .placing(node: node, at: declarationPosition(of: detailedNode))
            .renamingInViews(node.id, from: .group, to: .node)
    }
}

extension VGraph {

    /// Grouping's exact inverse, and why it exists beside `deletingWithContents`:
    /// the natural correction to a group drawn by mistake is "not that box",
    /// not "not those five nodes" (ADR-0018).
    public func ungrouping(_ group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        // A detailed node is a node, not a box around its details (ADR-0032).
        guard !isDetailed(group) else {
            throw VError.commandUnavailable(.ungroup, target: group.id.id)
        }
        let parent = parentGroup(of: group) ?? Group.root
        let (childGroups, childNodes) = try directContent(of: group)

        let withNodesOut = try childNodes.folding(self) { (result, node) throws(VError) in
            try result.addingTo(group: parent, node: node)
        }
        let withAllOut = try childGroups.folding(withNodesOut) { (result, child) throws(VError) in
            try result.addingTo(group: parent, childGroup: child)
        }
        return try withAllOut.deleting(group: group).removingEmptied(from: parent)
    }

    /// The contents go **explicitly**. Removing only the group leaves its children
    /// in no group at all, and the exporter walks the group structure — so they
    /// stop being written out and vanish at the next reparse, which is neither
    /// deleting them nor keeping them.
    public func deletingWithContents(_ group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        let (descendantGroups, descendantNodes) = try allContent(of: group)

        let withoutNodes = try descendantNodes.folding(self) { (result, node) throws(VError) in
            try result.deleting(node: node)
        }
        let withoutDescendants = try descendantGroups.folding(withoutNodes) { (result, descendant) throws(VError) in
            result.has(group: descendant) ? try result.deleting(group: descendant) : result
        }
        return try withoutDescendants.deleting(group: group).removingEmptied(from: parentGroup(of: group))
    }
}

extension VGraph {

    public func groupingTarget(for ids: [String]) -> VGroupingTarget? {
        let members = groupMembers(for: ids)
        guard !members.isEmpty else { return nil }

        let parents = members.map { parentOfElement($0) ?? Group.root }
        let destination = nearestCommonAncestor(of: parents)
        let detachedCount = parents.filter { $0 != destination }.count
        return VGroupingTarget(parentId: destination.id.id, detachedCount: detachedCount)

        /// Always exists: every ancestry chain ends at the root.
        func nearestCommonAncestor(of holders: [Group]) -> Group {
            let others = holders.dropFirst().map { Set(groupAncestry(from: $0)) }
            return groupAncestry(from: holders.first).first { candidate in others.allSatisfy { $0.contains(candidate) } }
                ?? Group.root
        }
    }

    /// A node has exactly one parent group and groups are strictly nested, so a
    /// new group cannot overlap an existing one: members of another group have to
    /// *leave* it. This form refuses rather than move them; `addingGroup(moving:)`
    /// is the same command having been told that is intended — a pair, not a
    /// flag (ADR-0018).
    ///
    /// Edges go unmentioned because they need no mention — an edge is in the
    /// innermost group holding both its ends, derived on demand (ADR-0017), so one
    /// between two members is already inside the result.
    public func addingGroup(containing ids: [String]) throws(VError) -> (VGraph, Group) {
        guard let target = groupingTarget(for: ids), !target.detachesAny else {
            throw VError.commandUnavailable(.addGroup, target: ids.first ?? "")
        }
        return try addingGroup(of: ids, under: target)
    }

    public func addingGroup(moving ids: [String]) throws(VError) -> (VGraph, Group) {
        guard let target = groupingTarget(for: ids) else {
            throw VError.commandUnavailable(.addGroup, target: ids.first ?? "")
        }
        return try addingGroup(of: ids, under: target)
    }

    private func addingGroup(of ids: [String], under target: VGroupingTarget) throws(VError) -> (VGraph, Group) {
        let created = newGroupId()
        // Explicit, never absent, for the reason ADR-0009 gives about nodes: it is
        // what the [[Inline edit]] opens on, and must read the same after a reparse.
        let labeled = try adding(group: created, childOf: Group(rawValue: target.parentId)).setting(
            group: created,
            attribute: Attributes.Group.label(Attributes.Node.placeholderLabel))

        let members = groupMembers(for: ids).compactMap { resolveCommandTarget(id: $0) }
        let result = try members.folding(labeled) { (result, member) throws(VError) in
            try result.adding(member, to: created)
        }
        return (result, created)
    }

    /// The whole diagram has no outside to be wrapped in, but its *contents* do —
    /// which is what a caller naming the [[Root group]] means (ADR-0018).
    private func groupMembers(for ids: [String]) -> [String] {
        let members = outermostElements(of: ids)
        guard members.count == 1, members[0] == Group.rootId else { return members }
        return directChildIds(of: Group.root).sorted()
    }

    func adding(_ element: VCommandTarget, to group: Group) throws(VError) -> VGraph {
        switch element {
        case .node(let node): return try addingTo(group: group, node: node)
        case .group(let child): return try addingTo(group: group, childGroup: child)
        case .edge: return self
        }
    }
}
