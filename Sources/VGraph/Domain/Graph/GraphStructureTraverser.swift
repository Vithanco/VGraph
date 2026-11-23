public enum TraversalOrder {
    case groupsFirst
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
        let (rootGroups, rootNodes) = try graph.directContent(of: Group.root)
        let structure = try traverseStructure(graph, groups: rootGroups, nodes: rootNodes, depth: 0)
        let edges = try graph.inDeclarationOrder(graph.edges).map { (edge) throws(VError) in try onEdge(edge, graph) }
        return combine(structure + edges)
    }

    private func traverseStructure(
        _ graph: VGraph,
        groups: [Group],
        nodes: [Node],
        depth: Int
    ) throws(VError) -> [Result] {
        // Handlers are called in the order their results appear: a handler may keep state.
        switch order {
        case .groupsFirst: return try visitGroups() + visitNodes()
        case .nodesFirst: return try visitNodes() + visitGroups()
        }

        func visitGroups() throws(VError) -> [Result] {
            try graph.inDeclarationOrder(groups).map { (group) throws(VError) in
                try traverseGroup(group, in: graph, depth: depth)
            }.flatMap { $0 }
        }

        func visitNodes() throws(VError) -> [Result] {
            try graph.inDeclarationOrder(nodes).map { (node) throws(VError) in try onNode(node, graph, depth) }
        }
    }

    private func traverseGroup(_ group: Group, in graph: VGraph, depth: Int) throws(VError) -> [Result] {
        let entered = try onEnterGroup(group, graph, depth)
        let (subGroups, subNodes) = try graph.directContent(of: group)
        let inside = try traverseStructure(graph, groups: subGroups, nodes: subNodes, depth: depth + 1)
        return [entered] + inside + [try onExitGroup(group, graph, depth)]
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
