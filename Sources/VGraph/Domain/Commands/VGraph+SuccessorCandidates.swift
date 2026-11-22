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
        candidatesWithinBounds(at: source, end: .from)
    }

    public func predecessorCandidates(to target: Node) -> [VCandidate] {
        candidatesWithinBounds(at: target, end: .to)
    }

    private func candidatesWithinBounds(at node: Node, end: VEdgeEnd) -> [VCandidate] {
        guard let type = try? nodeType(for: node),
            !exhausted(totalDegreeMax(at: end), of: type, at: node, end: end)
        else { return [] }
        return candidates(of: type, at: end).filter { !isSpent($0) }

        func isSpent(_ candidate: VCandidate) -> Bool {
            exhausted(
                degreeMax(at: end), of: candidate.edgeType,
                count: count(edgesOf: candidate.edgeType, at: node, end: end))
                // The new node has no edges yet, so only a maximum of zero shuts it.
                || exhausted(totalDegreeMax(at: end.opposite), of: candidate.nodeType, count: 0)
        }

        func totalDegreeMax(at end: VEdgeEnd) -> TypedAttributeDefinition<Int> {
            end == .from ? Attributes.Node.totalOutDegreeMax : Attributes.Node.totalInDegreeMax
        }

        func degreeMax(at end: VEdgeEnd) -> TypedAttributeDefinition<Int> {
            end == .from ? Attributes.Edge.outDegreeMax : Attributes.Edge.inDegreeMax
        }
    }

    /// The new node takes the declared far type, so each relationship is one
    /// candidate; the near end may be a detail of the declared one (ADR-0032).
    private func candidates(of nodeType: NodeType, at end: VEdgeEnd) -> [VCandidate] {
        let permitted = edgeTypes.filter { !$0.isUnknown && holdsAtNearEnd($0) }
        let titles = Self.menuTitles(permitted.map { (nodeType: farType($0), relationships: $0.id.id) })
        return zip(permitted, titles).map { edgeType, title in
            VCandidate(edgeType: edgeType, nodeType: farType(edgeType), title: title)
        }

        func farType(_ edgeType: EdgeType) -> NodeType { edgeType.nodeType(at: end.opposite) }

        func holdsAtNearEnd(_ edgeType: EdgeType) -> Bool {
            switch end {
            case .from: return holds(edgeType, from: nodeType, to: edgeType.to)
            case .to: return holds(edgeType, from: edgeType.from, to: nodeType)
            }
        }
    }

    /// Two offers of one node type would be two rows under the same title, so
    /// those also name their relationships.
    static func menuTitles(_ offers: [(nodeType: NodeType, relationships: String)]) -> [String] {
        let offersPerNodeType = Dictionary(offers.map { ($0.nodeType, 1) }, uniquingKeysWith: { $0 + $1 })
        return offers.map { offer in
            (offersPerNodeType[offer.nodeType] ?? 0) > 1
                ? "\(offer.nodeType.id) (\(offer.relationships))" : offer.nodeType.id
        }
    }
}
