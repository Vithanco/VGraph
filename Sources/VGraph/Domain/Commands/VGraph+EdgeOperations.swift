//
//  VGraph+EdgeOperations.swift
//  VGraph
//
//  The graph edits behind the editing commands: reversing an edge, inserting a
//  node into one, and growing a new node off an existing one.
//
//  Graph work belongs to the graph. A session decides *whether* an operation may
//  run and records the result; what the operation does to the shape is here,
//  where the types it needs are already in scope — a session has no business
//  knowing about declaration order or minting unknown edge types.
//

extension VGraph {
    /// Reverse an edge, re-typing it as `edgeType` — the ends swap, so the type
    /// that described the old direction rarely describes the new one.
    public func reversing(_ edgeId: Edge.Id, as edgeType: EdgeType) throws(VError) -> VGraph {
        guard let edge = get(edge: edgeId) else { return self }
        return try reattach(edge: edgeId, from: edge.to, to: edge.from, edgeType: edgeType)
    }

    /// Reverse an edge the notation gives no reversal for, minting an unknown
    /// edge type for the swapped ends. A [[Notation break]], and visible as one:
    /// an unknown type renders bold red and raises a quality warning.
    public func reversingWithUnknownType(_ edgeId: Edge.Id) throws(VError) -> VGraph {
        guard let edge = get(edge: edgeId) else { return self }

        let newSource = try nodeType(for: edge.to)
        let newTarget = try nodeType(for: edge.from)
        let (withType, edgeType) = try ensureUnknownEdgeType(from: newSource, to: newTarget)
        return try withType.reattach(edge: edgeId, from: edge.to, to: edge.from, edgeType: edgeType)
    }

    /// Move one [[Edge end]] to `node`, typing the result as `edgeType`.
    ///
    /// The far end stays put, so `reattach`'s other parameter is left `nil`. The
    /// old type is never carried across: `add(edge:)` refuses a type whose
    /// declared ends do not match the actual node types, so a moved end cannot
    /// keep a type that no longer describes it (ADR-0021).
    ///
    /// `edgeType` is not optional, which is what makes "this gesture never
    /// mints" structural rather than a rule someone has to remember: there is
    /// no `nil` to fall through to `ensureUnknownEdgeType` (ADR-0024).
    public func reattaching(
        _ edgeId: Edge.Id, end: VEdgeEnd, to node: Node, using edgeType: EdgeType
    ) throws(VError) -> VGraph {
        guard get(edge: edgeId) != nil else { return self }
        switch end {
        case .from: return try reattach(edge: edgeId, from: node, edgeType: edgeType)
        case .to: return try reattach(edge: edgeId, to: node, edgeType: edgeType)
        }
    }

    /// Replace an edge with a node and the two edges that reattach it.
    ///
    /// `incoming` and `outgoing` are what the notation offered; either may be
    /// `nil` after a break, and only then is an unknown edge type minted. The
    /// returned node is the one to open an [[Inline edit]] on, or `nil` for a
    /// type that displays no text of its own.
    public func splitting(
        _ edgeId: Edge.Id, into newType: NodeType, incoming: EdgeType?, outgoing: EdgeType?
    ) throws(VError) -> (VGraph, Node?) {
        guard let edge = get(edge: edgeId) else { return (self, nil) }

        let sourceType = try nodeType(for: edge.from)
        let targetType = try nodeType(for: edge.to)

        // Ids come from the untouched graph, so nothing can land on the id the
        // old edge is about to free.
        let newNode = newNodeId(for: newType)
        // Where the edge ran is where the node replacing it belongs; read before
        // the delete, which takes the endpoints it is derived from with it.
        let group = self.group(of: edgeId)
        let carried = getOwnAttributes(edge: edgeId)
        let place = declarationPosition(of: edgeId)

        var result = try delete(edge: edgeId)

        // Either half may be missing after a break; only then is an unknown edge
        // type minted.
        let inType: EdgeType
        if let incoming {
            inType = incoming
        } else if let known = result.knownEdgeType(from: sourceType, to: newType) {
            inType = known
        } else {
            (result, inType) = try result.ensureUnknownEdgeType(from: sourceType, to: newType)
        }
        let outType: EdgeType
        if let outgoing {
            outType = outgoing
        } else if let known = result.knownEdgeType(from: newType, to: targetType) {
            outType = known
        } else {
            (result, outType) = try result.ensureUnknownEdgeType(from: newType, to: targetType)
        }

        result = try result.add(node: newNode, type: newType, group: group)
        // Explicit, never absent — an absent label does not survive a reparse
        // unchanged (ADR-0009).
        result = try result.set(
            node: newNode,
            attribute: Attributes.Node.label.attribute(Attributes.Node.placeholderLabel))

        let first = Edge(
            id: result.newEdgeId(from: edge.from, to: newNode), from: edge.from, to: newNode)
        result = try result.add(edge: first, edgeType: inType).placing(edge: first.id, at: place)
        result = try result.set(edge: first.id, attributes: carried)

        let second = Edge(
            id: result.newEdgeId(from: newNode, to: edge.to), from: newNode, to: edge.to)
        result = try result.add(edge: second, edgeType: outType)

        return (result, hasUserText(nodeType: newType) ? newNode : nil)
    }

    /// Join two nodes that already exist.
    ///
    /// `edgeType` is what the notation allows between them, or one `declaring`
    /// has just added. Not optional: there is no `nil` to fall through to
    /// `ensureUnknownEdgeType`, so this gesture cannot mint (ADR-0024). Unlike
    /// `addingRelated`, a drag can span two groups — the edge then belongs to
    /// whichever group holds both ends, up to the root.
    public func connecting(_ from: Node, to: Node, using edgeType: EdgeType) throws(VError) -> VGraph {
        let edge = Edge(id: newEdgeId(from: from, to: to), from: from, to: to)
        return try add(edge: edge, edgeType: edgeType)
    }

    /// Create a node at the far end of a new edge.
    ///
    /// `edgeType` is the relationship the notation offered; `nil` mints an
    /// unknown one for the pair, which is the [[Notation break]] and renders as
    /// such. `outgoing` decides which end the new node lands on — the only
    /// difference between adding a successor and adding a predecessor.
    ///
    /// The returned node is the one to open an [[Inline edit]] on, or `nil` for
    /// a type that displays no text of its own.
    public func addingRelated(
        to source: Node, ofType newType: NodeType, using edgeType: EdgeType?, outgoing: Bool
    ) throws(VError) -> (VGraph, Node?) {
        let sourceType = try nodeType(for: source)
        let group = place(relatedTo: source, by: edgeType, outgoing: outgoing)

        let newNode = newNodeId(for: newType)
        var result = try add(node: newNode, type: newType, group: group)
        // Explicit, never absent — an absent label does not survive a reparse
        // unchanged (ADR-0009).
        result = try result.set(
            node: newNode,
            attribute: Attributes.Node.label.attribute(Attributes.Node.placeholderLabel))

        let from = outgoing ? source : newNode
        let to = outgoing ? newNode : source

        let joining: EdgeType
        if let edgeType {
            joining = edgeType
        } else {
            let fromType = outgoing ? sourceType : newType
            let toType = outgoing ? newType : sourceType
            (result, joining) = try result.ensureUnknownEdgeType(from: fromType, to: toType)
        }

        let edge = Edge(id: "\(from.id)_\(to.id)", from: from, to: to)
        result = try result.add(edge: edge, edgeType: joining)

        return (result, hasUserText(nodeType: newType) ? newNode : nil)
    }

    /// Beside what the source counts for: on a gained pair that is the enclosing
    /// detailed node of the declared type, where the far type belongs (ADR-0032).
    private func place(relatedTo source: Node, by edgeType: EdgeType?, outgoing: Bool) -> Group? {
        guard let edgeType,
            case .detailedNode(let holder) = boundElement(
                at: source, declared: outgoing ? edgeType.from : edgeType.to)
        else { return group(of: source) }
        return parentGroup(of: holder)
    }
}
