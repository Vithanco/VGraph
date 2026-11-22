//
//  VGraph+Reattach.swift
//  VGraph
//
//  Moving an edge without losing what the user wrote.
//

extension VGraph {
    /// Re-attach an edge to new endpoints: same id and attributes. A `nil` end
    /// stays where it is, so a flip passes both and moving one end passes one.
    /// The edge's group follows the ends it is given.
    ///
    /// `delete(edge:)` drops the whole attribute item and the edge's place, so
    /// restoring its `EdgeWriting` is what keeps the label, the comments and the
    /// place. Contrast `redirect(edge:)`, which does not carry them and is for
    /// derived graphs.
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
        let existing = try existingEdge(edge)
        let replacement = Edge(id: edge, from: from ?? existing.from, to: to ?? existing.to)
        let written = writing(on: edge)
        return try delete(edge: edge).add(edge: replacement, edgeType: edgeType).restoring(written, onto: replacement.id)
    }

    /// Re-attach an edge, typing it by ADR-0032's R1 rule: it keeps its type
    /// while that holds the new pair, takes a declared type holding it if not,
    /// and an unknown type if none does. It never fails for want of a type,
    /// which is what lets Decompose move every edge.
    public func reattachRetyping(
        edge: Edge.Id, from: Node? = nil, to: Node? = nil
    ) throws(VError) -> VGraph {
        let existing = try existingEdge(edge)
        let fromType = try nodeType(for: from ?? existing.from)
        let toType = try nodeType(for: to ?? existing.to)

        let current = try edgeType(for: edge)
        if holds(current, from: fromType, to: toType) {
            return try reattach(edge: edge, from: from, to: to, edgeType: current)
        }
        if let declared = declaredEdgeType(holdingFrom: fromType, to: toType) {
            return try reattach(edge: edge, from: from, to: to, edgeType: declared)
        }
        let (minted, unknown) = try ensureUnknownEdgeType(from: fromType, to: toType)
        return try minted.reattach(edge: edge, from: from, to: to, edgeType: unknown)
    }

    func writing(on edge: Edge.Id) -> EdgeWriting {
        EdgeWriting(attributes: getOwnAttributes(edge: edge), place: declarationPosition(of: edge))
    }

    /// Skips any value whose definition has since gone.
    func restoring(_ writing: EdgeWriting, onto edge: Edge.Id) throws(VError) -> VGraph {
        let definitions = attributeDefinitions
        return try writing.attributes.folding(placing(edge: edge, at: writing.place)) { (result, written) throws(VError) in
            guard let definition = definitions[written.key] else { return result }
            return try result.set(edge: edge, def: definition, value: written.value)
        }
    }
}

/// Everything written on an edge — its label, its comments, its place in the
/// document — which a delete takes with it and a replacement has to restore.
struct EdgeWriting {
    let attributes: AttributeContainer
    let place: Int
}
