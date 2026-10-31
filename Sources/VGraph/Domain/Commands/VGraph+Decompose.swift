extension VGraph {
    public func canDecompose(_ node: Node) -> Bool {
        guard let type = try? nodeType(for: node) else { return false }
        return !detailTypes(of: type).isEmpty
    }

    /// The node becomes a group of the same id that carries its type and
    /// values, with one detail per edge so no edge loses its end; `undetailing`
    /// is the way back. Its edges move to new details first, while the id is still a
    /// node's, because a group may not share an id with a node.
    public func decomposing(_ node: Node) throws(VError) -> VGraph {
        guard canDecompose(node) else {
            throw VError.commandUnavailable(.decompose, target: node.id)
        }
        let type = try nodeType(for: node)
        let details = detailTypes(of: type)
        let parent = group(of: node) ?? Group(rawValue: rootGroup)
        let place = declarationPosition(of: node)
        let moving = edges(at: node).sorted { declarationPosition(of: $0.id) < declarationPosition(of: $1.id) }

        let start = Decomposition(graph: self, details: [], parent: parent)
        let detailed =
            moving.isEmpty
            ? try start.addingDetail(details[0]).decomposition
            : try moving.folding(start) { (sofar, edge) throws(VError) in
                try sofar.moving(edge, off: node, onto: details)
            }

        let group = Group(rawValue: node.id)
        let regrouped = try detailed.graph
            .updatedSelfWith(ads: detailed.graph.ads.rekeying(from: Self.key(node), to: Self.key(group)))
            .delete(node: node)
            .add(group: group, childOf: parent)
            .typing(group: group, as: type)
            .placing(group: group, at: place)
            .renamingInViews(node.id, from: .node, to: .group)
        return try detailed.details.folding(regrouped) { (graph, detail) throws(VError) in
            try graph.addTo(group: group, node: detail)
        }
    }

    /// The graph part-way through a decompose, and the details made so far,
    /// which join the new group once the node has become it.
    private struct Decomposition {
        let graph: VGraph
        let details: [Node]
        let parent: Group

        func addingDetail(_ type: NodeType?) throws(VError) -> (decomposition: Decomposition, detail: Node?) {
            guard let type else { return (self, nil) }
            let (added, detail) = try graph.addingPlaceholderNode(ofType: type, in: parent)
            return (Decomposition(graph: added, details: details + [detail], parent: parent), detail)
        }

        func moving(_ edge: Edge, off node: Node, onto types: [NodeType]) throws(VError) -> Decomposition {
            let landing = try graph.landing(of: edge, at: node, among: types)
            let (withFrom, from) = try addingDetail(landing.from)
            let (withTo, to) = try withFrom.addingDetail(landing.to)
            return Decomposition(
                graph: try withTo.graph.reattachRetyping(edge: edge.id, from: from, to: to),
                details: withTo.details, parent: parent)
        }
    }

    /// The detail types an edge's moving ends land on: one for an edge, both
    /// for a self-loop. A landing where the edge keeps its type wins, then one
    /// some declared type holds; with neither, R1 mints unknown.
    private func landing(
        of edge: Edge, at node: Node, among details: [NodeType]
    ) throws(VError) -> (from: NodeType?, to: NodeType?) {
        let fromType = try nodeType(for: edge.from)
        let toType = try nodeType(for: edge.to)
        var candidates: [(from: NodeType?, to: NodeType?)] = []
        if edge.from == node && edge.to == node {
            for from in details {
                for to in details { candidates.append((from: from, to: to)) }
            }
        } else if edge.from == node {
            candidates = details.map { (from: $0, to: nil) }
        } else {
            candidates = details.map { (from: nil, to: $0) }
        }

        let current = try edgeType(for: edge.id)
        func pair(_ landing: (from: NodeType?, to: NodeType?)) -> (from: NodeType, to: NodeType) {
            (from: landing.from ?? fromType, to: landing.to ?? toType)
        }
        if let kept = candidates.first(where: { holds(current, from: pair($0).from, to: pair($0).to) }) {
            return kept
        }
        if let retyped = candidates.first(where: {
            edgeTypes(holdingFrom: pair($0).from, to: pair($0).to).contains { gains($0) }
        }) {
            return retyped
        }
        return candidates[0]
    }
}

extension VGraph {
    /// Decompose unfolds the node where the author is looking, and nowhere else
    /// (ADR-0032). `nil` is the default view: it reads the model, which the
    /// declared views inherit, so a view whose fold state that would change
    /// keeps the one it had.
    public func unfolding(_ group: Group, onlyIn view: String?) throws(VError) -> VGraph {
        let isFolded = Attributes.Group.isFolded
        if let view {
            return try settingInView(view, isFolded.attribute(false), for: Self.key(group))
        }
        func foldState(in graph: VGraph, _ view: String) throws(VError) -> Bool {
            try VGraph(base: graph, readLayer: Self.layer(ofView: view)).get(group: group, attribute: isFolded)
        }
        var result = try set(group: group, attribute: isFolded.attribute(false))
        for declared in views {
            let before = try foldState(in: self, declared.name)
            if try foldState(in: result, declared.name) != before {
                result = try result.settingInView(declared.name, isFolded.attribute(before), for: Self.key(group))
            }
        }
        return result
    }
}
