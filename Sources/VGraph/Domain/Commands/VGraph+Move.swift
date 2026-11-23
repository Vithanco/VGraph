// Changing which group elements belong to. See ADR-0019.

extension VGraph {

    /// Refuses the whole set if any one member cannot go: half a move is not
    /// something a caller can undo in one step.
    ///
    /// The cycle check is the load-bearing one: the group tree can hold a cycle,
    /// and `isAncestor` recurses, so an unguarded move into a descendant would not
    /// throw; it would hang.
    public func moving(
        _ ids: [String], into destination: String, notationBreak: VNotationBreak = .forbidden
    ) throws(VError) -> VGraph {
        let target = Group(rawValue: destination)
        guard has(group: target), !ids.isEmpty else {
            throw VError.commandUnavailable(.move, target: destination)
        }

        let elements = try ids.map { (id) throws(VError) -> VCommandTarget in
            guard canMove(id, into: target, notationBreak: notationBreak),
                let element = resolveCommandTarget(id: id)
            else { throw VError.commandUnavailable(.move, target: id) }
            return element
        }
        let vacated = ids.compactMap { parentOfElement($0) }

        let moved = try elements.folding(self) { (result, element) throws(VError) in
            try result.adding(element, to: target)
        }
        // Same rule `delete` follows: a command that empties a group removes it
        // (ADR-0018). Applied after every member has moved, or moving two
        // siblings out would delete their parent halfway through.
        return try vacated.folding(moved) { (result, group) throws(VError) in
            try result.removingEmptied(from: group)
        }
    }

    private func canMove(_ id: String, into destination: Group, notationBreak: VNotationBreak) -> Bool {
        guard id != Group.rootId else { return false }
        guard let element = resolveCommandTarget(id: id) else { return false }
        if notationBreak == .forbidden, misplacedType(of: element, in: destination) != nil {
            return false
        }
        switch element {
        case .edge: return false
        case .node(let node):
            return group(of: node) != destination
        case .group(let group):
            if group == destination { return false }
            // The cycle. Safe to ask because the tree is still acyclic here —
            // which is the whole point of asking before writing.
            if groupStructure.isAncestor(group, of: destination) { return false }
            return parentGroup(of: group) != destination
        }
    }

    /// The same predicate `moving` uses, read the other way round, so an offered
    /// destination and an accepted one cannot diverge.
    public func moveDestinations(
        for ids: [String], notationBreak: VNotationBreak = .forbidden
    ) -> [String] {
        guard !ids.isEmpty else { return [] }
        return (groups + [Group.root])
            .filter { candidate in ids.allSatisfy { canMove($0, into: candidate, notationBreak: notationBreak) } }
            .map { $0.id.id }
            .sorted()
    }
}
