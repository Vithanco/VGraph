extension TransformStep.Id {
    public static var mergeRelations: Self { "mergeRelations" }
}

extension Notations.ConceptMap {
    public static var mergeStep: TransformStep {
        TransformStep(.mergeRelations) { (g: VGraph) throws(VError) in try applyMergeRelations(to: g) }
    }
}

// MARK: - Identification

/// All nodes in the group share the same label and the same set of outgoing target nodes.
public struct MergeableGroup {
    public let label: String
    public let targets: Set<Node>
    /// In document order; the first is the survivor.
    public let nodes: [Node]
}

/// Two Relation nodes are mergeable when they have:
/// 1. The same label (name)
/// 2. The same set of outgoing target nodes
///
/// Overall: O(E + R) where E = edge count and R = Relation node count.
public func findMergeableRelations(in graph: VGraph) -> [MergeableGroup] {
    let relationNodeType = Notations.ConceptMap.NodeTypes.relation

    guard graph.has(nodeType: relationNodeType) else {
        return []
    }

    guard let relationNodes = graph.typedGraph.nodeTypeMapping.getMany(one: relationNodeType),
        relationNodes.count > 1
    else {
        return []
    }

    let topology = GraphTopology(edges: graph.edges)

    var mergeGroups: [MergeKey: [Node]] = [:]
    for node in relationNodes {
        guard let targets = topology.outgoingTargets[node], !targets.isEmpty else { continue }
        let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? ""
        let key = MergeKey(label: label, targets: targets)
        mergeGroups[key, default: []].append(node)
    }

    // `relationNodes` is a `Set` and `mergeGroups` a `Dictionary`, so neither
    // iterates the same way twice. Candidates are identical apart from their id,
    // so the survivor needs a rule — or the same document renders under a
    // different node id each run.
    var groups: [MergeableGroup] = []
    for (key, nodes) in mergeGroups where nodes.count > 1 {
        groups.append(
            MergeableGroup(label: key.label, targets: key.targets, nodes: inDocumentOrder(nodes, in: graph)))
    }

    // The merges are independent, but the order they are applied in reaches the
    // graph, so it is pinned too.
    groups.sort { left, right in
        if left.label != right.label { return left.label < right.label }
        return left.nodes[0].id.description < right.nodes[0].id.description
    }
    return groups
}

/// Document order, the same order the exporters preserve.
private func inDocumentOrder(_ nodes: [Node], in graph: VGraph) -> [Node] {
    var withOrder: [(node: Node, order: Int)] = []
    for node in nodes {
        let order = graph.declarationPosition(of: node)
        withOrder.append((node: node, order: order))
    }
    let sorted = withOrder.sorted { left, right in
        if left.order != right.order { return left.order < right.order }
        return left.node.id.description < right.node.id.description
    }
    var result: [Node] = []
    for entry in sorted { result.append(entry.node) }
    return result
}

// MARK: - Transform

/// Uses `findMergeableRelations` to identify candidates, then for each group:
/// 1. Picks the first node as the **survivor**
/// 2. For each duplicate: redirects all incoming edges to the survivor, deletes duplicate outgoing edges,
///    then deletes the duplicate node
///
public func applyMergeRelations(to graph: VGraph) throws(VError) -> VGraph {
    let mergeableGroups = findMergeableRelations(in: graph)

    guard !mergeableGroups.isEmpty else {
        return graph
    }

    let topology = GraphTopology(edges: graph.edges)

    var result = graph

    for group in mergeableGroups {
        let survivor = group.nodes[0]

        for nodeToRemove in group.nodes.dropFirst() {
            for edge in topology.incomingEdges(of: nodeToRemove) where result.has(edge: edge.id) {
                let redirected = Edge(base: edge, to: survivor)
                result = try result.redirect(edge: redirected)
            }

            for edge in topology.outgoingEdges(of: nodeToRemove) where result.has(edge: edge.id) {
                result = try result.delete(edge: edge.id)
            }

            result = try result.delete(node: nodeToRemove)
        }
    }

    return result
}

// MARK: - Private Types

/// Two Relation nodes with the same label and the same set of outgoing targets are considered duplicates.
private struct MergeKey: Hashable {
    let label: String
    let targets: Set<Node>
}
