//
//  VGraph+RetypeNode.swift
//  VGraph
//
//  What a node may be retyped to, what that leaves to ask about its edges, and
//  the retype itself once the answers are in.
//

extension VGraph {
    /// The types `node` may become with every one of its edges still carried by a
    /// declared edge type, and standing where it stands (ADR-0032) — the allowed
    /// substitutions.
    public func retypeCandidates(for node: Node) -> [NodeType] {
        guard let current = try? nodeType(for: node) else { return [] }
        let attached = edges(at: node)
        return retypeOffers(replacing: current, in: group(of: node)).filter { candidate in
            attached.allSatisfy { !edgeTypeOptions(for: $0, at: node, as: candidate).isEmpty }
        }
    }

    /// The types a detailed node may become: allowed where it stands, and
    /// detailed by every type it already holds (ADR-0032). It has no edges of its
    /// own, since edges end at its details, so none constrain it.
    public func retypeCandidates(for detailedNode: Group) -> [NodeType] {
        guard let current = nodeType(of: detailedNode) else { return [] }
        let held = detailTypesHeld(by: detailedNode)
        return retypeOffers(replacing: current, in: parentGroup(of: detailedNode)).filter { candidate in
            let admitted = detailTypes(of: candidate)
            return held.allSatisfy { admitted.contains($0) }
        }
    }

    private func retypeOffers(replacing current: NodeType, in enclosing: Group?) -> [NodeType] {
        nodeTypes.filter { candidate in
            candidate != current && !candidate.isUnknown && allows(candidate, in: enclosing)
        }
    }

    /// The edges that become ambiguous when `node` becomes `type`, **in the
    /// order the change consumes the answers** — the caller's array is
    /// positional, so this order is part of the contract rather than a detail.
    ///
    /// Empty in the common case: retyping usually leaves every edge with exactly
    /// one possible type, and then there is nothing to ask.
    public func ambiguousEdges(ifRetyping node: Node, to type: NodeType) -> [VAmbiguousEdge] {
        edgesInDeclarationOrder(at: node).compactMap { edge in
            let options = edgeTypeOptions(for: edge, at: node, as: type)
            guard Self.isAmbiguous(options) else { return nil }
            return VAmbiguousEdge(edgeId: edge.id.id, prompt: name(of: edge), options: options)
        }
    }

    /// `edgeTypes` answers `ambiguousEdges(ifRetyping:to:)` positionally — one per
    /// ambiguous edge, in the same order. An edge the new type determines on its
    /// own needs no answer, and one the notation has no type for at all gets an
    /// unknown one, which is how a [[Notation break]] stays visible.
    public func retyping(
        _ node: Node, to newType: NodeType, edgeTypes answers: [EdgeType.Id]
    ) throws(VError) -> VGraph {
        var result = self
        var retyped: [(edge: Edge.Id, type: EdgeType)] = []
        var remainingAnswers = answers.makeIterator()

        for edge in edgesInDeclarationOrder(at: node) {
            let options = edgeTypeOptions(for: edge, at: node, as: newType)
            let type: EdgeType
            if Self.isAmbiguous(options) {
                type = try chosenEdgeType(answer: remainingAnswers.next(), among: options)
            } else if let only = options.first {
                type = only
            } else {
                (result, type) = try mintingUnknownEdgeType(for: edge, in: result)
            }
            retyped.append((edge.id, type))
        }

        // A leftover means the caller's answers came from a different question
        // list than the one just walked.
        guard remainingAnswers.next() == nil else {
            throw VError.commandAnswersMismatched(.changeType, target: node.id)
        }
        return try result.settingTypes(of: node, to: newType, retyped: retyped)

        func chosenEdgeType(answer: EdgeType.Id?, among options: [EdgeType]) throws(VError) -> EdgeType {
            guard let answer else {
                throw VError.commandAnswersMismatched(.changeType, target: node.id)
            }
            guard let chosen = options.named(answer) else {
                throw VError.commandOptionNotOffered(.changeType, target: node.id, option: answer.id)
            }
            return chosen
        }

        /// An end with no node type at all is a broken graph rather than a bad
        /// argument, but still not something to swallow.
        func mintingUnknownEdgeType(for edge: Edge, in graph: VGraph) throws(VError) -> (VGraph, EdgeType) {
            guard let fromType = endType(edge.from, at: node, as: newType) else {
                throw VError.nodeWithoutNodeType(edge.from)
            }
            guard let toType = endType(edge.to, at: node, as: newType) else {
                throw VError.nodeWithoutNodeType(edge.to)
            }
            return try graph.ensureUnknownEdgeType(from: fromType, to: toType)
        }
    }

    /// One rule for both `ambiguousEdges` and `retyping`, since the second
    /// consumes answers to exactly the questions the first asks.
    private static func isAmbiguous(_ options: [EdgeType]) -> Bool {
        options.count > 1
    }

    /// `retyped` must name every edge at the node.
    private func settingTypes(
        of node: Node, to nodeType: NodeType, retyped: [(edge: Edge.Id, type: EdgeType)]
    ) throws(VError) -> VGraph {
        let result = try retyped.folding(try setNodeType(node: node, type: nodeType)) { (graph, change) throws(VError) in
            try graph.setEdgeType(edge: change.edge, type: change.type.id)
        }
        try result.ensureEdgesFitTheirTypes(at: node)
        return result
    }

    /// Neither setter validates the pairing the way `add(edge:)` does, so the
    /// result is checked here rather than surfacing as a parse failure later.
    private func ensureEdgesFitTheirTypes(at node: Node) throws(VError) {
        for edge in edges(at: node) {
            try ensureEdgeTypeFits(
                edgeType: try edgeType(for: edge.id),
                fromType: try nodeType(for: edge.from),
                toType: try nodeType(for: edge.to))
        }
    }

    private func edgeTypeOptions(for edge: Edge, at node: Node, as newType: NodeType) -> [EdgeType] {
        guard let from = endType(edge.from, at: node, as: newType),
            let to = endType(edge.to, at: node, as: newType)
        else { return [] }
        return knownEdgeTypes(from: from, to: to)
    }

    private func endType(_ end: Node, at node: Node, as newType: NodeType) -> NodeType? {
        end == node ? newType : try? nodeType(for: end)
    }
}
