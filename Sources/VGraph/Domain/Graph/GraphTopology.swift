/// Precomputed structural indexes for a graph's edges.
/// Built in a single O(E) pass. Reuse across multiple analyses to avoid redundant computation.
public struct GraphTopology {
    public let outgoingTargets: [Node: Set<Node>]

    public let incomingSources: [Node: Set<Node>]

    public let connectedNodes: Set<Node>

    /// In the order the edges were given, with a self-loop listed once. Callers
    /// write their results out in the order they walk this, so the order is part
    /// of the contract. `VGraph.edges` is grouped by source node, not by line.
    private let incident: [Node: [Edge]]

    public static func analyze(_ graph: VGraph) -> GraphTopology {
        GraphTopology(edges: graph.edges)
    }

    public init(edges: some Sequence<Edge>) {
        var outgoing: [Node: Set<Node>] = [:]
        var incoming: [Node: Set<Node>] = [:]
        var connected: Set<Node> = []
        var incident: [Node: [Edge]] = [:]

        for edge in edges {
            outgoing[edge.from, default: []].insert(edge.to)
            incoming[edge.to, default: []].insert(edge.from)
            connected.insert(edge.from)
            connected.insert(edge.to)
            incident[edge.from, default: []].append(edge)
            if edge.to != edge.from {
                incident[edge.to, default: []].append(edge)
            }
        }

        self.outgoingTargets = outgoing
        self.incomingSources = incoming
        self.connectedNodes = connected
        self.incident = incident
    }

    public func incidentEdges(of node: Node) -> [Edge] {
        incident[node] ?? []
    }

    public func incomingEdges(of node: Node) -> [Edge] {
        incidentEdges(of: node).filter { $0.to == node }
    }

    public func outgoingEdges(of node: Node) -> [Edge] {
        incidentEdges(of: node).filter { $0.from == node }
    }

    /// Treats edges as undirected (A→B means A and B are in the same component).
    /// Only considers nodes in the provided collection; isolated nodes
    /// (not in `connectedNodes`) each form their own singleton component.
    public func connectedComponents(nodes: some Collection<Node>) -> [Set<Node>] {
        var visited: Set<Node> = []
        var components: [Set<Node>] = []

        for node in nodes where !visited.contains(node) {
            var component: Set<Node> = []
            var queue: [Node] = [node]
            while !queue.isEmpty {
                let current = queue.removeLast()
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                component.insert(current)
                if let targets = outgoingTargets[current] {
                    for neighbor in targets where !visited.contains(neighbor) {
                        queue.append(neighbor)
                    }
                }
                if let sources = incomingSources[current] {
                    for neighbor in sources where !visited.contains(neighbor) {
                        queue.append(neighbor)
                    }
                }
            }
            components.append(component)
        }
        return components
    }
}
