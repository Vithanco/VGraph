//
//  VGraph+Grouping.swift
//  VGraph
//
//  The canonical form over the group tree, which the editor's [[Effective
//  selection]] is. See ADR-0018.
//

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
        var selected = Set<String>()
        for id in ids {
            guard let target = resolveCommandTarget(id: id) else { continue }
            switch target {
            case .node(let node): selected.insert(node.id)
            case .group(let group): selected.insert(group.id.id)
            case .edge: continue
            }
        }
        guard !selected.isEmpty else { return [] }

        var changed = true
        while changed {
            changed = false
            for group in groups where !selected.contains(group.id.id) {
                let children = directChildIds(of: group)
                guard !children.isEmpty else { continue }
                var complete = true
                for child in children where !selected.contains(child) {
                    complete = false
                    break
                }
                if complete {
                    selected.insert(group.id.id)
                    changed = true
                }
            }
        }

        var result: [String] = []
        for id in selected where !isCovered(id, by: selected) {
            result.append(id)
        }
        return result.sorted()
    }

    func directChildIds(of group: Group) -> [String] {
        guard let content = try? groupStructure.getDirectContent(group: group) else { return [] }
        var ids: [String] = []
        for child in content.0 { ids.append(child.id.id) }
        for node in content.1 { ids.append(node.id) }
        return ids
    }

    private func isCovered(_ id: String, by selected: Set<String>) -> Bool {
        var parent = parentOfElement(id)
        while let group = parent {
            if selected.contains(group.id.id) { return true }
            parent = groupStructure.parentGroup(of: group)
        }
        return false
    }

    /// The root when nothing else holds it — the fallback ADR-0017 chose for an
    /// edge, so the two never disagree about what "no particular group" means.
    func parentOfElement(_ id: String) -> Group? {
        guard let target = resolveCommandTarget(id: id) else { return nil }
        switch target {
        case .node(let node): return groupStructure.group(of: node) ?? Group(rawValue: rootGroup)
        case .group(let group):
            if group.id.id == rootGroup { return nil }
            return groupStructure.parentGroup(of: group) ?? Group(rawValue: rootGroup)
        case .edge: return nil
        }
    }
}

extension VGraph {

    /// Refuses the whole set if any one member cannot go: half a move is not
    /// something a caller can undo in one step.
    ///
    /// The cycle check is the load-bearing one and it is new — the group tree has
    /// been able to hold a cycle since it was written, and nothing could reach it
    /// until a group could move. `isParent` recurses, so an unguarded move would
    /// not throw; it would hang.
    public func moving(
        _ ids: [String], into destination: String, notationBreak: VNotationBreak = .forbidden
    ) throws(VError) -> VGraph {
        let target = Group(rawValue: destination)
        guard has(group: target), !ids.isEmpty else {
            throw VError.commandUnavailable(.move, target: destination)
        }

        var result = self
        var vacated: [Group] = []
        for id in ids {
            guard canMove(id, into: target, notationBreak: notationBreak) else {
                throw VError.commandUnavailable(.move, target: id)
            }
            guard let element = resolveCommandTarget(id: id) else {
                throw VError.commandUnavailable(.move, target: id)
            }
            switch element {
            case .node(let node):
                if let held = groupStructure.group(of: node) { vacated.append(held) }
                result = try result.addTo(group: target, node: node)
            case .group(let group):
                if let held = groupStructure.parentGroup(of: group) { vacated.append(held) }
                result = try result.addTo(group: target, childGroup: group)
            case .edge:
                throw VError.commandUnavailable(.move, target: id)
            }
        }

        // Same rule `delete` follows: a command that empties a group removes it
        // (ADR-0018). Applied after every member has moved, or moving two
        // siblings out would delete their parent halfway through.
        for group in vacated {
            result = try result.removingEmptied(from: group)
        }
        return result
    }

    private func canMove(_ id: String, into destination: Group, notationBreak: VNotationBreak) -> Bool {
        guard id != rootGroup else { return false }
        guard let element = resolveCommandTarget(id: id) else { return false }
        if notationBreak == .forbidden, !placedTypes(of: element).allSatisfy({ allows($0, in: destination) }) {
            return false
        }
        switch element {
        case .edge: return false
        case .node(let node):
            return groupStructure.group(of: node) != destination
        case .group(let group):
            if group == destination { return false }
            // The cycle. Safe to ask because the tree is still acyclic here —
            // which is the whole point of asking before writing.
            if groupStructure.isParent(parent: group, child: destination) { return false }
            return groupStructure.parentGroup(of: group) != destination
        }
    }

    /// The same predicate `moving` uses, read the other way round, so an offered
    /// destination and an accepted one cannot diverge.
    public func moveDestinations(
        for ids: [String], notationBreak: VNotationBreak = .forbidden
    ) -> [String] {
        var destinations: [String] = []
        for candidate in groups + [Group(rawValue: rootGroup)] {
            var legal = !ids.isEmpty
            for id in ids where !canMove(id, into: candidate, notationBreak: notationBreak) { legal = false }
            if legal { destinations.append(candidate.id.id) }
        }
        return destinations.sorted()
    }

    /// Call *immediately after* removing a child, which is what makes this a rule
    /// about commands rather than an invariant on the graph: a hand-written empty
    /// group is never passed here, so it survives a parse and export unchanged
    /// (ADR-0018).
    public func removingEmptied(from group: Group?) throws(VError) -> VGraph {
        var result = self
        var current = group
        while let candidate = current, candidate.id.id != rootGroup {
            guard result.has(group: candidate), result.directChildIds(of: candidate).isEmpty else {
                break
            }
            // A detailed node is a node that has details: emptied, it is a node
            // again, which its parent still holds (ADR-0032).
            if result.isDetailed(candidate) {
                return try result.undetailing(candidate)
            }
            let parent = result.parentGroup(of: candidate)
            result = try result.delete(group: candidate)
            current = parent
        }
        return result
    }

    func undetailing(_ group: Group) throws(VError) -> VGraph {
        guard let type = nodeType(of: group) else {
            throw VError.commandUnavailable(.delete, target: group.id.id)
        }
        let node = Node(group)
        return try replacing(detailed: group, withNodeOfType: type, in: parentGroup(of: group) ?? Group(rawValue: rootGroup))
            .placing(node: node, at: declarationPosition(of: group))
            .renamingInViews(node.id, from: .group, to: .node)
    }
}

extension VGraph {

    /// Grouping's exact inverse, and why it exists beside `deletingWithContents`:
    /// the natural correction to a boundary drawn by mistake is "not that box",
    /// not "not those five nodes" (ADR-0018).
    public func ungrouping(_ group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        // A detailed node is a node, not a box around its details (ADR-0032).
        guard !isDetailed(group) else {
            throw VError.commandUnavailable(.ungroup, target: group.id.id)
        }
        let parent = parentGroup(of: group) ?? Group(rawValue: rootGroup)
        let (childGroups, childNodes) = try groupStructure.getDirectContent(group: group)

        var result = self
        for node in childNodes {
            result = try result.addTo(group: parent, node: node)
        }
        for child in childGroups {
            result = try result.addTo(group: parent, childGroup: child)
        }
        result = try result.delete(group: group)
        return try result.removingEmptied(from: parent)
    }

    /// The contents go **explicitly**. Removing only the group leaves its children
    /// in no group at all, and the exporter walks the group structure — so they
    /// stop being written out and vanish at the next reparse, which is neither
    /// deleting them nor keeping them.
    public func deletingWithContents(_ group: Group) throws(VError) -> VGraph {
        try ensureExists(group: group)
        let parent = parentGroup(of: group)
        let (descendantGroups, descendantNodes) = try groupStructure.getAllContent(group: group)

        var result = self
        for node in descendantNodes {
            result = try result.delete(node: node)
        }
        for descendant in descendantGroups where result.has(group: descendant) {
            result = try result.delete(group: descendant)
        }
        result = try result.delete(group: group)
        return try result.removingEmptied(from: parent)
    }
}

/// One answer to three questions — may the command run, where does the group
/// land, and what should the menu row say — so the greyed row and the executed
/// command cannot disagree (ADR-0018).
public struct VGroupingTarget: Sendable, Equatable {
    public let parentId: String
    /// How many elements would leave a group they are in. Zero is the only case
    /// `addGroup(containing:)` accepts.
    public let detached: Int

    public init(parentId: String, detached: Int) {
        self.parentId = parentId
        self.detached = detached
    }
}

extension VGraph {

    /// Counting only picks where the probe starts: ids are not dense and all three
    /// kinds share one keyspace, so the count routinely lands on a taken id. Same
    /// scheme as `newNodeId(for:)`.
    public func newGroupId() -> Group {
        var index = groups.count + 1
        while true {
            let candidate = "group_\(index)"
            if resolveCommandTarget(id: candidate) == nil {
                return Group(rawValue: candidate)
            }
            index += 1
        }
    }

    /// The whole diagram has no outside to be wrapped in, but its *contents* do —
    /// which is what a caller naming the [[Root group]] means (ADR-0018).
    func groupMembers(for ids: [String]) -> [String] {
        let members = outermostElements(of: ids)
        guard members.count == 1, members[0] == rootGroup else { return members }
        return directChildIds(of: Group(rawValue: rootGroup)).sorted()
    }

    public func groupingTarget(for ids: [String]) -> VGroupingTarget? {
        let members = groupMembers(for: ids)
        guard !members.isEmpty else { return nil }

        let root = Group(rawValue: rootGroup)
        var parents: [Group] = []
        for member in members {
            parents.append(parentOfElement(member) ?? root)
        }

        let destination = nearestCommonAncestor(of: parents)
        var detached = 0
        for parent in parents where parent != destination {
            detached += 1
        }
        return VGroupingTarget(parentId: destination.id.id, detached: detached)
    }

    /// Always exists: every ancestry chain ends at the root.
    private func nearestCommonAncestor(of groups: [Group]) -> Group {
        let root = Group(rawValue: rootGroup)
        guard var common = groups.first else { return root }
        for group in groups.dropFirst() {
            while common != group && !groupStructure.isParent(parent: common, child: group) {
                guard let up = groupStructure.parentGroup(of: common) else { return root }
                common = up
            }
        }
        return common
    }

    /// A node has exactly one parent group and clusters are strictly nested, so a
    /// new group cannot overlap an existing one: members of another group have to
    /// *leave* it. `detaching` is whether the caller has said that is intended.
    ///
    /// Edges go unmentioned because they need no mention — an edge is in the
    /// innermost group holding both its ends, derived on demand (ADR-0017), so one
    /// between two members is already inside the result.
    public func addingGroup(of ids: [String], detaching: Bool) throws(VError) -> (VGraph, Group) {
        guard let target = groupingTarget(for: ids) else {
            throw VError.commandUnavailable(.addGroup, target: ids.first ?? "")
        }
        if target.detached > 0 && !detaching {
            throw VError.commandUnavailable(.addGroup, target: ids.first ?? "")
        }

        let members = groupMembers(for: ids)
        let created = newGroupId()
        var result = try add(group: created, childOf: Group(rawValue: target.parentId))

        // Explicit, never absent, for the reason ADR-0009 gives about nodes: it is
        // what the [[Inline edit]] opens on, and must read the same after a reparse.
        result = try result.set(
            group: created,
            attribute: Attributes.Group.label.attribute(Attributes.Node.placeholderLabel))

        for member in members {
            guard let element = resolveCommandTarget(id: member) else { continue }
            switch element {
            case .node(let node): result = try result.addTo(group: created, node: node)
            case .group(let group): result = try result.addTo(group: created, childGroup: group)
            case .edge: continue
            }
        }
        return (result, created)
    }
}
