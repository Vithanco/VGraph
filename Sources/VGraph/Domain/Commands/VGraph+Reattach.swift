//
//  VGraph+Reattach.swift
//  VGraph
//
//  Moving an edge, or retyping a node, without losing what the user wrote.
//

extension VGraph {
    /// Re-attach an edge to new endpoints: same id and attributes. A `nil` end
    /// stays where it is, so a flip passes both and moving one arrowhead passes
    /// one. The edge's group follows the ends it is given.
    ///
    /// `delete(edge:)` drops the whole attribute item and the edge's place, so
    /// the carry-across below is what keeps the label, the comments and the
    /// place. Contrast
    /// `redirect(edge:)`, which does not carry them and is for derived graphs.
    ///
    /// The id is deliberately not a parameter: this exists to preserve the edge's
    /// identity, so an id the caller could change would defeat the point.
    /// `edgeType` is required rather than "keep the current one", because
    /// `add(edge:)` validates the type against the endpoints — a moved end
    /// usually needs a restated type, and an implicit one would turn the caller's
    /// decision into a throw.
    public func reattach(
        edge: Edge.Id, from: Node? = nil, to: Node? = nil, edgeType: EdgeType
    ) throws(VError) -> VGraph {
        guard let existing = get(edge: edge) else { throw VError.edgeNotFound(edge) }
        let replacement = Edge(id: edge, from: from ?? existing.from, to: to ?? existing.to)

        let carried = getOwnAttributes(edge: edge)
        let place = declarationPosition(of: edge)
        var result = try delete(edge: edge)
        result = try result.add(edge: replacement, edgeType: edgeType).placing(edge: replacement.id, at: place)
        return try result.set(edge: replacement.id, attributes: carried)
    }

    /// Re-attach an edge, typing it by ADR-0032's R1 rule: it keeps its type
    /// while that holds the new pair, takes a declared type holding it if not,
    /// and an unknown type if none does. It never fails for want of a type,
    /// which is what lets Decompose move every edge.
    public func reattachRetyping(
        edge: Edge.Id, from: Node? = nil, to: Node? = nil
    ) throws(VError) -> VGraph {
        guard let existing = get(edge: edge) else { throw VError.edgeNotFound(edge) }
        let fromType = try nodeType(for: from ?? existing.from)
        let toType = try nodeType(for: to ?? existing.to)

        let current = try edgeType(for: edge)
        if holds(current, from: fromType, to: toType) {
            return try reattach(edge: edge, from: from, to: to, edgeType: current)
        }
        if let declared = edgeTypes(holdingFrom: fromType, to: toType).first(where: { gains($0) }) {
            return try reattach(edge: edge, from: from, to: to, edgeType: declared)
        }
        let (minted, unknown) = try ensureUnknownEdgeType(from: fromType, to: toType)
        return try minted.reattach(edge: edge, from: from, to: to, edgeType: unknown)
    }

    /// Retype a node and put each of its edges onto the type given for it.
    /// `edgeTypes` must name every edge at the node.
    ///
    /// Neither setter validates the pairing the way `add(edge:)` does, so the
    /// result is checked here rather than surfacing as a parse failure later.
    public func retype(
        node: Node, to nodeType: NodeType, edgeTypes: [(edge: Edge.Id, type: EdgeType)]
    ) throws(VError) -> VGraph {
        var result = try setNodeType(node: node, type: nodeType)
        for retyped in edgeTypes {
            result = try result.setEdgeType(edge: retyped.edge, type: retyped.type.id)
        }

        for edge in result.edges(at: node) {
            try result.ensureEdgeTypeFits(
                edgeType: try result.edgeType(for: edge.id),
                fromType: try result.nodeType(for: edge.from),
                toType: try result.nodeType(for: edge.to))
        }
        return result
    }

    /// Re-apply a snapshot from `getOwnAttributes(edge:)`, skipping any whose
    /// definition has since gone.
    public func set(edge: Edge.Id, attributes: AttributeContainer) throws(VError) -> VGraph {
        var result = self
        let definitions = attributeDefinitions
        for (id, value) in attributes {
            guard let definition = definitions[id] else { continue }
            result = try result.set(edge: edge, def: definition, value: value)
        }
        return result
    }
}
