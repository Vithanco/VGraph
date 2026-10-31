public struct NodeTypePair: Hashable, Sendable {
    public let from: NodeType
    public let to: NodeType

    public init(from: NodeType, to: NodeType) {
        self.from = from
        self.to = to
    }
}

/// Which `(from, to)` pairs an edge type holds (ADR-0032). Gained pairs are
/// derived from the installed detailings on every ask, so they follow each
/// layer that installs and never reach a file.
extension VGraph {
    public func pairs(of edgeType: EdgeType) -> [NodeTypePair] {
        [NodeTypePair(from: edgeType.from, to: edgeType.to)] + gainedPairs(of: edgeType, declared: declaredPairs)
    }

    /// A pair some type declares is never also gained.
    public func edgeTypes(holdingFrom from: NodeType, to: NodeType) -> [EdgeType] {
        let pair = NodeTypePair(from: from, to: to)
        let exact = edgeTypes.filter { $0.from == from && $0.to == to }
        let declared = declaredPairs
        if declared.contains(pair) { return exact }
        return exact + edgeTypes.filter { gainedPairs(of: $0, declared: declared).contains(pair) }
    }

    /// Unknown (already-broken) types excluded: what a candidate list offers.
    func knownEdgeTypes(from: NodeType, to: NodeType) -> [EdgeType] {
        edgeTypes(holdingFrom: from, to: to).filter { !$0.isUnknown }
    }

    /// The first of them — only where the caller does not care which.
    func knownEdgeType(from: NodeType, to: NodeType) -> EdgeType? {
        knownEdgeTypes(from: from, to: to).first
    }

    func holds(_ edgeType: EdgeType, from: NodeType, to: NodeType) -> Bool {
        (edgeType.from == from && edgeType.to == to)
            || gainedPairs(of: edgeType, declared: declaredPairs).contains(NodeTypePair(from: from, to: to))
    }

    /// Unknown and derived types stand for one pair only; they neither gain nor block.
    func gains(_ edgeType: EdgeType) -> Bool {
        !edgeType.isUnknown && !edgeType.isDerived
    }

    private var declaredPairs: Set<NodeTypePair> {
        Set(edgeTypes.filter { gains($0) }.map { NodeTypePair(from: $0.from, to: $0.to) })
    }

    /// One end replaced, never both.
    private func gainedPairs(of edgeType: EdgeType, declared: Set<NodeTypePair>) -> [NodeTypePair] {
        guard gains(edgeType) else { return [] }
        let candidates =
            allDetailTypes(of: edgeType.from).map { NodeTypePair(from: $0, to: edgeType.to) }
            + allDetailTypes(of: edgeType.to).map { NodeTypePair(from: edgeType.from, to: $0) }
        var result: [NodeTypePair] = []
        for pair in candidates where !declared.contains(pair) && !result.contains(pair) {
            result.append(pair)
        }
        return result
    }

    /// Breadth first, so nearer detail types come first.
    func allDetailTypes(of nodeType: NodeType) -> [NodeType] {
        var result: [NodeType] = []
        var frontier = [nodeType]
        while !frontier.isEmpty {
            var next: [NodeType] = []
            for type in frontier {
                for detail in detailTypes(of: type) where !result.contains(detail) {
                    result.append(detail)
                    next.append(detail)
                }
            }
            frontier = next
        }
        return result
    }
}
