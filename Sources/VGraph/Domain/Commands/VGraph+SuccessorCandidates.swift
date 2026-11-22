//
//  VGraph+SuccessorCandidates.swift
//  VGraph
//
//  What the notation permits when a new node grows off an existing one. See
//  ADR-0013.
//

extension VGraph {
    /// So a menu never offers what the check would flag the instant it is picked
    /// (ADR-0011).
    public func successorCandidates(from source: Node) -> [VCandidate] {
        candidatesWithinBounds(at: source, leaving: true)
    }

    public func predecessorCandidates(to target: Node) -> [VCandidate] {
        candidatesWithinBounds(at: target, leaving: false)
    }

    private func candidatesWithinBounds(at node: Node, leaving: Bool) -> [VCandidate] {
        guard let type = try? nodeType(for: node),
            !exhausted(totalDegreeMax(leaving: leaving), of: type, at: node, leaving: leaving)
        else { return [] }
        return candidates(of: type, leaving: leaving).filter { !isSpent($0) }

        func isSpent(_ candidate: VCandidate) -> Bool {
            exhausted(
                degreeMax(leaving: leaving), of: candidate.edgeType,
                count: count(edgesOf: candidate.edgeType, at: node, leaving: leaving))
                // The new node has no edges yet, so only a maximum of zero shuts it.
                || exhausted(totalDegreeMax(leaving: !leaving), of: candidate.nodeType, count: 0)
        }

        func totalDegreeMax(leaving out: Bool) -> TypedAttributeDefinition<Int> {
            out ? Attributes.Node.totalOutDegreeMax : Attributes.Node.totalInDegreeMax
        }

        func degreeMax(leaving out: Bool) -> TypedAttributeDefinition<Int> {
            out ? Attributes.Edge.outDegreeMax : Attributes.Edge.inDegreeMax
        }
    }

    /// The new node takes the declared far type, so each relationship is one
    /// candidate; the near end may be a detail of the declared one (ADR-0032).
    private func candidates(of nodeType: NodeType, leaving: Bool) -> [VCandidate] {
        let permitted = edgeTypes.filter { !$0.isUnknown && holdsAtNearEnd($0) }
        let titles = Self.menuTitles(permitted.map { (nodeType: farType($0), relationships: $0.id.id) })
        return zip(permitted, titles).map { edgeType, title in
            VCandidate(edgeType: edgeType, nodeType: farType(edgeType), title: title)
        }

        func farType(_ edgeType: EdgeType) -> NodeType { leaving ? edgeType.to : edgeType.from }

        func holdsAtNearEnd(_ edgeType: EdgeType) -> Bool {
            leaving
                ? holds(edgeType, from: nodeType, to: edgeType.to)
                : holds(edgeType, from: edgeType.from, to: nodeType)
        }
    }

    /// What a menu calls each offer: its node type, and where two offers share
    /// one, the relationships that tell them apart — rather than two rows under
    /// the same title.
    static func menuTitles(_ offers: [(nodeType: NodeType, relationships: String)]) -> [String] {
        let offersPerNodeType = Dictionary(offers.map { ($0.nodeType, 1) }, uniquingKeysWith: { $0 + $1 })
        return offers.map { offer in
            (offersPerNodeType[offer.nodeType] ?? 0) > 1
                ? "\(offer.nodeType.id) (\(offer.relationships))" : offer.nodeType.id
        }
    }
}
