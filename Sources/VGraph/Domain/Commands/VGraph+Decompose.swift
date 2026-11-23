extension VGraph {
    public func canDecompose(_ node: Node) -> Bool {
        guard let type = try? nodeType(for: node) else { return false }
        return !detailTypes(of: type).isEmpty
    }

    /// The node becomes a group of the same id that carries its type and
    /// values, with one detail per edge so no edge loses its end; `undetailing`
    /// is the way back.
    public func decomposing(_ node: Node) throws(VError) -> VGraph {
        guard canDecompose(node) else {
            throw VError.commandUnavailable(.decompose, target: node.id)
        }
        let type = try nodeType(for: node)
        return try givingDetails(to: node, ofTypes: detailTypes(of: type)).becomingGroup(node, typed: type)
    }

    /// One detail per edge, or a single one for a node with no edges. The
    /// details stand beside the node until it has become their group.
    private func givingDetails(to node: Node, ofTypes detailTypes: [NodeType]) throws(VError) -> Decomposition {
        let start = Decomposition(graph: self, details: [], parent: group(of: node) ?? Group.root)
        let edgesToMove = edgesInDeclarationOrder(at: node)
        guard !edgesToMove.isEmpty else {
            return try start.addingDetail(detailTypes[0]).decomposition
        }
        return try edgesToMove.folding(start) { (soFar, edge) throws(VError) in
            try soFar.moving(edge, off: node, onto: detailTypes)
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

        func moving(_ edge: Edge, off node: Node, onto detailTypes: [NodeType]) throws(VError) -> Decomposition {
            let landing = try graph.landing(of: edge, at: node, among: detailTypes)
            let (withFrom, from) = try addingDetail(landing.from)
            let (withTo, to) = try withFrom.addingDetail(landing.to)
            return Decomposition(
                graph: try withTo.graph.reattachingAndRetyping(edge: edge.id, from: from, to: to),
                details: withTo.details, parent: parent)
        }

        /// Only once every edge has moved to a detail, while the id is still a
        /// node's, because a group may not share an id with a node.
        func becomingGroup(_ node: Node, typed type: NodeType) throws(VError) -> VGraph {
            let group = Group(rawValue: node.id)
            let regrouped = try graph.movingValues(from: ItemKey(node), to: ItemKey(group))
                .deleting(node: node)
                .adding(group: group, childOf: parent)
                .typing(group: group, as: type)
                .placing(group: group, at: graph.declarationPosition(of: node))
                .renamingInViews(node.id, from: .node, to: .group)
            return try details.folding(regrouped) { (result, detail) throws(VError) in
                try result.addingTo(group: group, node: detail)
            }
        }
    }

    /// The detail types an edge's moving ends land on: one for an edge, both
    /// for a self-loop. A landing where the edge keeps its type wins, then one
    /// some declared type holds; with neither, R1 mints unknown.
    private func landing(
        of edge: Edge, at node: Node, among detailTypes: [NodeType]
    ) throws(VError) -> (from: NodeType?, to: NodeType?) {
        let fromType = try nodeType(for: edge.from)
        let toType = try nodeType(for: edge.to)
        let current = try edgeType(for: edge.id)
        let landings = Self.possibleLandings(of: edge, at: node, among: detailTypes)

        return landings.first { holds(current, from: pair($0).from, to: pair($0).to) }
            ?? landings.first { declaredEdgeType(holdingFrom: pair($0).from, to: pair($0).to) != nil }
            ?? landings[0]

        func pair(_ landing: (from: NodeType?, to: NodeType?)) -> (from: NodeType, to: NodeType) {
            (from: landing.from ?? fromType, to: landing.to ?? toType)
        }
    }

    /// `nil` is an end that stays where it is.
    private static func possibleLandings(
        of edge: Edge, at node: Node, among detailTypes: [NodeType]
    ) -> [(from: NodeType?, to: NodeType?)] {
        switch (edge.from == node, edge.to == node) {
        case (true, true): return detailTypes.flatMap { from in detailTypes.map { (from: from, to: $0) } }
        case (true, false): return detailTypes.map { (from: $0, to: nil) }
        default: return detailTypes.map { (from: nil, to: $0) }
        }
    }

    private func movingValues(from old: ItemKey, to new: ItemKey) -> VGraph {
        updatedSelfWith(attributeStore: attributeStore.rekeying(from: old, to: new))
    }
}

extension VGraph {
    /// Decompose unfolds the node where the author is looking, and nowhere else
    /// (ADR-0032). `nil` is the default view: it reads the model, which the
    /// declared views inherit, so a view whose fold state that would change
    /// keeps the one it had.
    public func unfolding(_ group: Group, onlyIn view: String?) throws(VError) -> VGraph {
        if let view {
            return try settingInView(view, Attributes.Group.isFolded.attribute(false), for: ItemKey(group))
        }
        let unfolded = try setting(group: group, attribute: Attributes.Group.isFolded.attribute(false))
        return try views.folding(unfolded) { (result, declared) throws(VError) in
            let wasFolded = try isFolded(in: self, view: declared.name)
            guard try isFolded(in: result, view: declared.name) != wasFolded else { return result }
            return try result.settingInView(declared.name, Attributes.Group.isFolded.attribute(wasFolded), for: ItemKey(group))
        }

        func isFolded(in graph: VGraph, view: String) throws(VError) -> Bool {
            try VGraph(base: graph, readLayer: Self.layer(ofView: view)).get(group: group, attribute: Attributes.Group.isFolded)
        }
    }
}
