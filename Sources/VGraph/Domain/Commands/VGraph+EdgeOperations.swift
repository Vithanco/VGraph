//
//  VGraph+EdgeOperations.swift
//  VGraph
//
//  The graph edits behind the edge commands.
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
        let edge = try existingEdge(edgeId)
        return try reattach(edge: edgeId, from: edge.to, to: edge.from, edgeType: edgeType)
    }

    /// Reverse an edge the notation gives no reversal for, minting an unknown
    /// edge type for the swapped ends. A [[Notation break]], and visible as one:
    /// an unknown type renders bold red and raises a quality warning.
    public func reversingWithUnknownType(_ edgeId: Edge.Id) throws(VError) -> VGraph {
        let edge = try existingEdge(edgeId)
        let newSourceType = try nodeType(for: edge.to)
        let newTargetType = try nodeType(for: edge.from)
        let (withType, edgeType) = try ensureUnknownEdgeType(from: newSourceType, to: newTargetType)
        return try withType.reattach(edge: edgeId, from: edge.to, to: edge.from, edgeType: edgeType)
    }

    /// Move one [[Edge end]] to `node`, the far end staying put, and type the
    /// result as `edgeType`.
    ///
    /// The old type is never carried across: `add(edge:)` refuses a type whose
    /// declared ends do not match the actual node types, so a moved end cannot
    /// keep a type that no longer describes it (ADR-0021).
    ///
    /// `edgeType` is not optional, which is what makes "this gesture never
    /// mints" structural rather than a rule someone has to remember: there is
    /// no `nil` to fall through to `ensureUnknownEdgeType` (ADR-0024).
    public func reattaching(
        _ edgeId: Edge.Id, end: VEdgeEnd, to node: Node, using edgeType: EdgeType
    ) throws(VError) -> VGraph {
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
        let edge = try existingEdge(edgeId)
        // Ids come from the untouched graph, so nothing can land on the id the
        // old edge is about to free.
        let newNode = newNodeId(for: newType)
        // Where the edge ran is where the node replacing it belongs; read before
        // the delete, which takes the endpoints it is derived from with it.
        let group = self.group(of: edgeId)
        let written = writing(on: edgeId)

        let withNode = try delete(edge: edgeId).adding(placeholder: newNode, ofType: newType, in: group)
        let (withIncoming, incomingHalf) = try withNode.connectingHalf(from: edge.from, to: newNode, offered: incoming)
        let (result, _) = try withIncoming.restoring(written, onto: incomingHalf)
            .connectingHalf(from: newNode, to: edge.to, offered: outgoing)
        return (result, nodeForInlineEdit(newNode, ofType: newType))
    }

    /// Either half may be missing after a break; only then, and only where the
    /// notation has no type for the pair, is an unknown edge type minted.
    private func connectingHalf(
        from: Node, to: Node, offered: EdgeType?
    ) throws(VError) -> (VGraph, Edge.Id) {
        let fallback = knownEdgeType(from: try nodeType(for: from), to: try nodeType(for: to))
        return try connecting(from, to: to, offeredOrUnknown: offered ?? fallback)
    }

    /// Join two nodes that already exist.
    ///
    /// `edgeType` is what the notation allows between them, or one `declaring`
    /// has just added. Not optional: there is no `nil` to fall through to
    /// `ensureUnknownEdgeType`, so this gesture cannot mint (ADR-0024). Unlike
    /// `addingRelated`, a drag can span two groups — the edge then belongs to
    /// whichever group holds both ends, up to the root.
    public func connecting(_ from: Node, to: Node, using edgeType: EdgeType) throws(VError) -> VGraph {
        try add(edge: newEdge(from: from, to: to), edgeType: edgeType)
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
        let newNode = newNodeId(for: newType)
        let withNode = try adding(
            placeholder: newNode, ofType: newType,
            in: newNodeGroup(relatedTo: source, by: edgeType, outgoing: outgoing))
        let (result, _) =
            outgoing
            ? try withNode.connecting(source, to: newNode, offeredOrUnknown: edgeType)
            : try withNode.connecting(newNode, to: source, offeredOrUnknown: edgeType)
        return (result, nodeForInlineEdit(newNode, ofType: newType))

        /// Beside what the source counts for: on a gained pair that is the
        /// enclosing detailed node of the declared type, where the far type
        /// belongs (ADR-0032).
        func newNodeGroup(relatedTo source: Node, by edgeType: EdgeType?, outgoing: Bool) -> Group? {
            guard let edgeType,
                case .detailedNode(let holder) = boundElement(
                    at: source, declared: outgoing ? edgeType.from : edgeType.to)
            else { return group(of: source) }
            return parentGroup(of: holder)
        }
    }

    /// `nil` is the [[Notation break]]: an unknown type for the pair, which
    /// renders as such.
    private func connecting(
        _ from: Node, to: Node, offeredOrUnknown offered: EdgeType?
    ) throws(VError) -> (VGraph, Edge.Id) {
        let (withType, edgeType) = try offeredOrUnknownType(offered, from: from, to: to)
        let edge = withType.newEdge(from: from, to: to)
        return (try withType.add(edge: edge, edgeType: edgeType), edge.id)

        func offeredOrUnknownType(_ offered: EdgeType?, from: Node, to: Node) throws(VError) -> (VGraph, EdgeType) {
            if let offered { return (self, offered) }
            return try ensureUnknownEdgeType(from: try nodeType(for: from), to: try nodeType(for: to))
        }
    }
}
