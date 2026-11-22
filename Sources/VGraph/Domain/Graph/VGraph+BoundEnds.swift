/// What a [[Bound]] counts an edge end against: a node, or the detailed node an
/// end on a gained pair stands in for (ADR-0032).
enum BoundElement: Hashable, Sendable {
    case node(Node)
    case detailedNode(Group)

    var id: String {
        switch self {
        case .node(let node): return node.description
        case .detailedNode(let group): return group.id.id
        }
    }
}

extension VGraph {
    /// An end on its type's declared node type counts for itself. An end moved
    /// onto a detail counts for the enclosing detailed node of the declared type,
    /// so decomposing takes no edge out of any count.
    func boundElement(at end: Node, declared: NodeType) -> BoundElement {
        guard let type = try? nodeType(for: end), type != declared,
            let holder = groupAncestry(from: group(of: end)).first(where: { nodeType(of: $0) == declared })
        else { return .node(end) }
        return .detailedNode(holder)
    }

    func boundEnds(of edge: Edge, typed edgeType: EdgeType) -> (from: BoundElement, to: BoundElement) {
        (boundElement(at: edge.from, declared: edgeType.from), boundElement(at: edge.to, declared: edgeType.to))
    }

    func boundElements(of nodeType: NodeType) -> [BoundElement] {
        let nodes = self.nodes.filter { (try? self.nodeType(for: $0)) == nodeType }.map { BoundElement.node($0) }
        let detailed = groups.filter { self.nodeType(of: $0) == nodeType }.map { BoundElement.detailedNode($0) }
        return nodes + detailed
    }

    /// What a candidate list counts against a maximum: the edges of `edgeType`
    /// that already count for the element `node` would count for, so an offer and
    /// the check never disagree (ADR-0011).
    func count(edgesOf edgeType: EdgeType, at node: Node, leaving: Bool) -> Int {
        let declared = leaving ? edgeType.from : edgeType.to
        let element = boundElement(at: node, declared: declared)
        return counted(edgesOf: edgeType).filter { (leaving ? $0.from : $0.to) == element }.count
    }

    func count(edgesOf edgeType: EdgeType, from: Node, to: Node) -> Int {
        let pair = (boundElement(at: from, declared: edgeType.from), boundElement(at: to, declared: edgeType.to))
        return counted(edgesOf: edgeType).filter { $0.from == pair.0 && $0.to == pair.1 }.count
    }

    private func counted(edgesOf edgeType: EdgeType) -> [(from: BoundElement, to: BoundElement)] {
        edges.compactMap { edge in
            guard let actual = try? self.edgeType(for: edge.id), actual.id == edgeType.id else { return nil }
            return boundEnds(of: edge, typed: edgeType)
        }
    }
}

extension VGraph {
    /// Shared by `connectCandidates(from:to:)` and `successorCandidates(from:)`,
    /// so the two offers count a [[Bound]] the same way.
    func exhausted(
        _ definition: TypedAttributeDefinition<Int>, of nodeType: NodeType, at node: Node, leaving: Bool
    ) -> Bool {
        exhausted(definition, of: nodeType, count: degree(of: node, leaving: leaving))
    }

    func exhausted(_ definition: TypedAttributeDefinition<Int>, of nodeType: NodeType, count: Int) -> Bool {
        Self.isReached((try? get(nodeType: nodeType, attribute: definition)) ?? Bound.unbounded, by: count)
    }

    func exhausted(_ definition: TypedAttributeDefinition<Int>, of edgeType: EdgeType, count: Int) -> Bool {
        Self.isReached((try? get(edgeType: edgeType.id, attribute: definition)) ?? Bound.unbounded, by: count)
    }

    /// An unstated maximum is never reached.
    private static func isReached(_ max: Int, by count: Int) -> Bool {
        Bound.isStated(max) && count >= max
    }

    private func degree(of node: Node, leaving: Bool) -> Int {
        edges.filter { (leaving ? $0.from : $0.to) == node }.count
    }
}
