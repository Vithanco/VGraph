extension TransformStep.Id {
    public static var mergeRelations: Self { "mergeRelations" }
}

extension Notations.ConceptMap {
    public static var mergeStep: TransformStep {
        TransformStep(.mergeRelations) { (graph: VGraph) throws(VError) in try applyMergeRelations(to: graph) }
    }
}

// MARK: - Identification

/// Relation nodes that share a label and the same set of outgoing target nodes.
public struct MergeableRelations {
    public let label: String
    public let targets: Set<Node>
    /// In document order; the first is the survivor.
    public let nodes: [Node]
}

/// Two Relation nodes are mergeable when they have:
/// 1. The same label (name)
/// 2. The same set of outgoing target nodes
public func findMergeableRelations(in graph: VGraph) -> [MergeableRelations] {
    let relations = graph.nodes(ofType: Notations.ConceptMap.NodeTypes.relation)
    guard relations.count > 1 else { return [] }
    let topology = GraphTopology(edges: graph.edges)

    let relationsByKey = Dictionary(
        relations.compactMap { relation -> (MergeKey, [Node])? in
            guard let targets = topology.outgoingTargets[relation], !targets.isEmpty else { return nil }
            let label = (try? graph.get(node: relation, attribute: Attributes.Node.label)) ?? ""
            return (MergeKey(label: label, targets: targets), [relation])
        },
        uniquingKeysWith: +)

    // Candidates are identical apart from their id, so the survivor needs a rule
    // — or the same document renders under a different node id each run. The
    // merges are independent, but the order they are applied in reaches the
    // graph, so it is pinned too.
    return relationsByKey.filter { $0.value.count > 1 }
        .map { key, nodes in MergeableRelations(label: key.label, targets: key.targets, nodes: inDocumentOrder(nodes, in: graph)) }
        .sorted { left, right in
            left.label != right.label ? left.label < right.label : left.nodes[0].id < right.nodes[0].id
        }
}

/// Document order, the same order the exporters preserve; the id breaks a tie.
private func inDocumentOrder(_ nodes: [Node], in graph: VGraph) -> [Node] {
    nodes.sorted { left, right in
        let leftPosition = graph.declarationPosition(of: left)
        let rightPosition = graph.declarationPosition(of: right)
        return leftPosition != rightPosition ? leftPosition < rightPosition : left.id < right.id
    }
}

// MARK: - Transform

/// The first of each set survives: the others' incoming edges move to it, and
/// their outgoing edges go with them, since the survivor already has the same.
public func applyMergeRelations(to graph: VGraph) throws(VError) -> VGraph {
    let topology = GraphTopology(edges: graph.edges)
    return try findMergeableRelations(in: graph).folding(graph) { (result, mergeable) throws(VError) in
        try mergeable.nodes.dropFirst().folding(result) { (merged, duplicate) throws(VError) in
            try merged.merging(duplicate, into: mergeable.nodes[0], topology: topology)
        }
    }
}

extension VGraph {
    fileprivate func merging(_ duplicate: Node, into survivor: Node, topology: GraphTopology) throws(VError) -> VGraph {
        let redirected = try topology.incomingEdges(of: duplicate).filter { has(edge: $0.id) }.folding(self) {
            (graph, edge) throws(VError) in try graph.redirecting(edge: Edge(base: edge, to: survivor))
        }
        let pruned = try topology.outgoingEdges(of: duplicate).filter { redirected.has(edge: $0.id) }.folding(redirected) {
            (graph, edge) throws(VError) in try graph.deleting(edge: edge.id)
        }
        return try pruned.deleting(node: duplicate)
    }
}

// MARK: - Private Types

/// Two Relation nodes with the same label and the same set of outgoing targets are considered duplicates.
private struct MergeKey: Hashable {
    let label: String
    let targets: Set<Node>
}
