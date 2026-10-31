/// Selectors are evaluated on the origin graph: "downstream 1" walks the model's
/// edges, never a graph earlier rules have already thinned out.
extension VGraph {
    struct Selection {
        var nodes: Set<String>
        /// Groups a rule named, as against groups that only enclose a shown node.
        var groups: Set<String>
    }

    /// The nodes and groups a view shows. A view whose first rule is `include`
    /// starts empty; any other starts with everything.
    func selection(of view: String) throws(VError) -> (nodes: Set<String>, groups: Set<String>) {
        guard let declaration = views.first(where: { $0.name == view }) else {
            throw VError.unknownView(view, available: views.map { $0.name })
        }
        let startsEmpty: Bool
        if case .include? = declaration.rules.first { startsEmpty = true } else { startsEmpty = false }
        var chosen = startsEmpty ? Selection(nodes: [], groups: []) : everything()
        for rule in declaration.rules {
            switch rule {
            case .include(let selector):
                let picked = try resolve(selector)
                chosen.nodes.formUnion(picked.nodes)
                chosen.groups.formUnion(picked.groups)
            case .exclude(let selector):
                let picked = try resolve(selector)
                chosen.nodes.subtract(picked.nodes)
                chosen.groups.subtract(picked.groups)
            case .expand(let steps):
                chosen.nodes.formUnion(reach(from: chosen.nodes, .around(steps)))
            }
        }
        return shown(chosen)
    }

    private func everything() -> Selection {
        Selection(nodes: Set(nodes.map { $0.id }), groups: Set(groups.map { $0.id.id }))
    }

    private func resolve(_ selector: Selector) throws(VError) -> Selection {
        var picked: Selection
        switch selector.subject {
        case .everything:
            picked = everything()
        case .nodes(let names):
            let known = Set(nodes.map { $0.id })
            picked = Selection(nodes: Set(names).intersection(known), groups: [])
        case .nodeTypes(let names):
            let wanted = Set(names)
            // A detailed node is the node it was (ADR-0032), so it comes with its details.
            picked = try containing(groups.filter { group in nodeType(of: group).map { wanted.contains($0.id) } ?? false })
            picked.nodes.formUnion(
                nodes.filter { node in (try? nodeType(for: node)).map { wanted.contains($0.id) } ?? false }.map { $0.id })
        case .groups(let names):
            picked = try containing(groups.filter { names.contains($0.id.id) })
        case .groupTypes(let names):
            picked = try containing(groups.filter { group in groupType(of: group).map { names.contains($0.id) } ?? false })
        }
        if let around = selector.reach {
            picked.nodes.formUnion(reach(from: picked.nodes, around))
        }
        return picked
    }

    /// A group and everything inside it.
    private func containing(_ some: [Group]) throws(VError) -> Selection {
        var picked = Selection(nodes: [], groups: [])
        for group in some {
            let (inner, members) = try getAllContent(group: group)
            picked.groups.insert(group.id.id)
            picked.groups.formUnion(inner.map { $0.id.id })
            picked.nodes.formUnion(members.map { $0.id })
        }
        return picked
    }

    private func reach(from start: Set<String>, _ reach: Selector.Reach) -> Set<String> {
        let steps: Int
        var forward = false
        var backward = false
        switch reach {
        case .downstream(let n):
            steps = n
            forward = true
        case .upstream(let n):
            steps = n
            backward = true
        case .around(let n):
            steps = n
            forward = true
            backward = true
        }
        var seen = start
        var frontier = start
        var taken = 0
        while taken < steps, !frontier.isEmpty {
            var next: Set<String> = []
            for edge in edges {
                let from = edge.from.id
                let to = edge.to.id
                if forward, frontier.contains(from), !seen.contains(to) { next.insert(to) }
                if backward, frontier.contains(to), !seen.contains(from) { next.insert(from) }
            }
            seen.formUnion(next)
            frontier = next
            taken += 1
        }
        return seen.subtracting(start)
    }

    /// Adds the groups that enclose a shown node to the ones a rule named.
    private func shown(_ chosen: Selection) -> (nodes: Set<String>, groups: Set<String>) {
        var groups = chosen.groups
        for id in chosen.nodes {
            var enclosing = group(of: Node(rawValue: id))
            while let group = enclosing {
                groups.insert(group.id.id)
                enclosing = parentGroup(of: group)
            }
        }
        return (chosen.nodes, groups)
    }

    /// The origin graph without everything a view does not show. A group's members
    /// go before the group, so none is left without a place.
    func keeping(nodes keptNodes: Set<String>, groups keptGroups: Set<String>) throws(VError) -> VGraph {
        var result = self
        for node in self.nodes where !keptNodes.contains(node.id) {
            result = try result.delete(node: node)
        }
        for group in self.groups where !keptGroups.contains(group.id.id) {
            result = try result.delete(group: group)
        }
        return result
    }
}
