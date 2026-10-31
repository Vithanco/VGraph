public enum TraversalOrder {
    /// Visit groups before nodes (used by DotExporter)
    case groupsFirst
    /// Visit nodes before groups (used by VGLExporter)
    case nodesFirst
}

/// The traverser visits elements in a consistent order:
/// 1. Recursively visits groups and nodes depth-first
/// 2. Within each group, visits either groups-first or nodes-first (configurable)
/// 3. Visits all edges at the end. An edge's group is derived from its
///    endpoints, so emitting one inside a group's braces would say nothing the
///    nodes have not already said.
///
/// All elements are sorted into declaration order.
public struct GraphStructureTraverser<Result> {
    public typealias GroupEnterHandler = (Group, VGraph, _ depth: Int) throws(VError) -> Result
    public typealias GroupExitHandler = (Group, VGraph, _ depth: Int) throws(VError) -> Result
    public typealias NodeHandler = (Node, VGraph, _ depth: Int) throws(VError) -> Result
    public typealias EdgeHandler = (Edge, VGraph) throws(VError) -> Result
    public typealias Combiner = ([Result]) -> Result

    private let onEnterGroup: GroupEnterHandler
    private let onExitGroup: GroupExitHandler
    private let onNode: NodeHandler
    private let onEdge: EdgeHandler
    private let combine: Combiner
    private let order: TraversalOrder

    public init(
        onEnterGroup: @escaping GroupEnterHandler,
        onExitGroup: @escaping GroupExitHandler,
        onNode: @escaping NodeHandler,
        onEdge: @escaping EdgeHandler,
        combine: @escaping Combiner,
        order: TraversalOrder = .groupsFirst
    ) {
        self.onEnterGroup = onEnterGroup
        self.onExitGroup = onExitGroup
        self.onNode = onNode
        self.onEdge = onEdge
        self.combine = combine
        self.order = order
    }

    public func traverse(_ graph: VGraph) throws(VError) -> Result {
        var results: [Result] = []

        let (rootGroups, rootNodes) = try graph.getRootContent()
        results.append(contentsOf: try traverseStructure(graph, groups: rootGroups, nodes: rootNodes, depth: 0))

        let sortedEdges = try GraphExportOrderPreservation.sortByItemOrder(graph.edges, in: graph)
        for edge in sortedEdges {
            results.append(try onEdge(edge, graph))
        }

        return combine(results)
    }

    private func traverseStructure(
        _ graph: VGraph,
        groups: [Group],
        nodes: [Node],
        depth: Int
    ) throws(VError) -> [Result] {
        var results: [Result] = []

        let sortedGroups = try GraphExportOrderPreservation.sortByItemOrder(groups, in: graph)
        let sortedNodes = try GraphExportOrderPreservation.sortByItemOrder(nodes, in: graph)

        switch order {
        case .groupsFirst:
            for group in sortedGroups {
                results.append(contentsOf: try traverseGroup(group, in: graph, depth: depth))
            }
            for node in sortedNodes {
                results.append(try onNode(node, graph, depth))
            }

        case .nodesFirst:
            for node in sortedNodes {
                results.append(try onNode(node, graph, depth))
            }
            for group in sortedGroups {
                results.append(contentsOf: try traverseGroup(group, in: graph, depth: depth))
            }
        }

        return results
    }

    private func traverseGroup(_ group: Group, in graph: VGraph, depth: Int) throws(VError) -> [Result] {
        var results: [Result] = []

        results.append(try onEnterGroup(group, graph, depth))

        let (subGroups, subNodes) = try graph.getDirectContent(group: group)
        results.append(contentsOf: try traverseStructure(graph, groups: subGroups, nodes: subNodes, depth: depth + 1))

        results.append(try onExitGroup(group, graph, depth))

        return results
    }
}

// MARK: - Convenience initializers

extension GraphStructureTraverser where Result == String {
    public static func forStringOutput(
        onEnterGroup: @escaping GroupEnterHandler,
        onExitGroup: @escaping GroupExitHandler,
        onNode: @escaping NodeHandler,
        onEdge: @escaping EdgeHandler,
        order: TraversalOrder = .groupsFirst
    ) -> GraphStructureTraverser<String> {
        GraphStructureTraverser<String>(
            onEnterGroup: onEnterGroup,
            onExitGroup: onExitGroup,
            onNode: onNode,
            onEdge: onEdge,
            combine: { $0.joined() },
            order: order
        )
    }
}

extension GraphStructureTraverser where Result == Void {
    public static func forSideEffects(
        onEnterGroup: @escaping (Group, VGraph, Int) throws(VError) -> Void,
        onExitGroup: @escaping (Group, VGraph, Int) throws(VError) -> Void,
        onNode: @escaping (Node, VGraph, Int) throws(VError) -> Void,
        onEdge: @escaping (Edge, VGraph) throws(VError) -> Void,
        order: TraversalOrder = .groupsFirst
    ) -> GraphStructureTraverser<Void> {
        GraphStructureTraverser<Void>(
            onEnterGroup: onEnterGroup,
            onExitGroup: onExitGroup,
            onNode: onNode,
            onEdge: onEdge,
            combine: { _ in },
            order: order
        )
    }
}
