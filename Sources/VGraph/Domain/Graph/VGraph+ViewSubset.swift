/// Selectors are evaluated on the origin graph: "downstream 1" walks the model's
/// edges, never a graph earlier rules have already thinned out.
extension VGraph {
    /// Nodes and groups chosen together — what a view's [[Subset rule]]s leave,
    /// or what a copy keeps. `groups` are those chosen, as against groups that
    /// only enclose a chosen node.
    struct Subset {
        var nodes: Set<String>
        var groups: Set<String>

        static let empty = Subset(nodes: [], groups: [])
    }

    /// The nodes and groups a view shows. A view whose first rule is `include`
    /// starts empty; any other starts with everything.
    func subset(of view: String) throws(VError) -> Subset {
        guard let declaration = views.first(where: { $0.name == view }) else {
            throw VError.unknownView(view, available: views.map { $0.name })
        }
        let startsEmpty: Bool
        if case .include? = declaration.rules.first { startsEmpty = true } else { startsEmpty = false }
        var chosen = startsEmpty ? Subset.empty : everything()
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
                chosen.nodes.formUnion(try reach(from: chosen.nodes, .around(steps)))
            }
        }
        return shown(chosen)
    }

    private func everything() -> Subset {
        Subset(nodes: Set(nodes.map { $0.id }), groups: Set(groups.map { $0.id.id }))
    }

    private func resolve(_ selector: Selector) throws(VError) -> Subset {
        var picked: Subset
        switch selector.subject {
        case .everything:
            picked = everything()
        case .nodes(let names):
            let known = Set(nodes.map { $0.id })
            picked = Subset(nodes: Set(names).intersection(known), groups: [])
        case .nodeTypes(let names):
            let wanted = Set(names)
            // A detailed node is the node it was (ADR-0032), so it comes with its details.
            picked = try subset(containing: groups.filter { group in nodeType(of: group).map { wanted.contains($0.id) } ?? false })
            picked.nodes.formUnion(
                nodes.filter { node in (try? nodeType(for: node)).map { wanted.contains($0.id) } ?? false }.map { $0.id })
        case .groups(let names):
            picked = try subset(containing: groups.filter { names.contains($0.id.id) })
        case .groupTypes(let names):
            picked = try subset(containing: groups.filter { group in groupType(of: group).map { names.contains($0.id) } ?? false })
        }
        if let around = selector.reach {
            picked.nodes.formUnion(try reach(from: picked.nodes, around))
        }
        return picked
    }

    /// Each group and everything inside it.
    func subset(containing chosen: [Group]) throws(VError) -> Subset {
        var picked = Subset.empty
        for group in chosen {
            let (inner, members) = try allContent(of: group)
            picked.groups.insert(group.id.id)
            picked.groups.formUnion(inner.map { $0.id.id })
            picked.nodes.formUnion(members.map { $0.id })
        }
        return picked
    }

    /// Each round adds the [[Neighbourhood]] of the nodes the last one stopped
    /// at (ADR-0038). Direction picks only the edges an ordinary node is left
    /// by, and where the next round goes on from.
    private func reach(from start: Set<String>, _ reach: Selector.Reach) throws(VError) -> Set<String> {
        let steps: Int
        let heading: Neighborhood.Heading?
        switch reach {
        case .downstream(let n): (steps, heading) = (n, .along)
        case .upstream(let n): (steps, heading) = (n, .against)
        case .around(let n): (steps, heading) = (n, nil)
        }
        let topology = GraphTopology(edges: edges)
        let carriers = try Neighborhood.carriers(in: self)
        // A node that carries the walk is left by every edge, so it is never
        // shown with half its claim.
        func leaves(_ node: Node, by edge: Edge) -> Bool {
            carriers[node] != nil || (heading.map { $0.continues(edge, from: node) } ?? true)
        }
        var reached = start
        var frontier = Set(start.map { Node(rawValue: $0) })
        // A node first reached sideways, as another input of an AND, may be
        // reached in the reach's direction later, so this is not `reached`.
        var started = frontier
        for _ in 0..<steps where !frontier.isEmpty {
            let round = Neighborhood(
                from: frontier.map { node in .leaving(node, by: topology.incidentEdges(of: node).filter { leaves(node, by: $0) }) },
                topology: topology, carriers: carriers)
            reached.formUnion(round.nodes.map { $0.id })
            frontier = Set(round.stops.filter { stop in heading.map { $0 == stop.heading } ?? true }.map { $0.node })
                .subtracting(started)
            started.formUnion(frontier)
        }
        return reached.subtracting(start)
    }

    /// Adds the groups that enclose a shown node to the ones a rule named.
    private func shown(_ chosen: Subset) -> Subset {
        let enclosing = chosen.nodes.flatMap { groupAncestry(from: group(of: Node(rawValue: $0))) }
        return Subset(nodes: chosen.nodes, groups: chosen.groups.union(enclosing.map { $0.id.id }))
    }

    /// The origin graph without everything a view does not show. A group's members
    /// go before the group, so none is left without a place.
    func keeping(_ kept: Subset) throws(VError) -> VGraph {
        let withoutNodes = try nodes.filter { !kept.nodes.contains($0.id) }.folding(self) { (graph, node) throws(VError) in
            try graph.deleting(node: node)
        }
        return try groups.filter { !kept.groups.contains($0.id.id) }.folding(withoutNodes) { (graph, group) throws(VError) in
            try graph.deleting(group: group)
        }
    }
}
