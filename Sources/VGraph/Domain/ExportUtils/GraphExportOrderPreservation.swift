/// Sorts elements into the order the document declared them in.
public struct GraphExportOrderPreservation {

    public static func sortByItemOrder(_ groups: [Group], in graph: VGraph) throws(VError) -> [Group] {
        var groupsWithOrder: [(Group, Int)] = []
        for group in groups {
            let order = graph.declarationPosition(of: group)
            groupsWithOrder.append((group, order))
        }
        return groupsWithOrder.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    public static func sortByItemOrder(_ nodes: [Node], in graph: VGraph) throws(VError) -> [Node] {
        var nodesWithOrder: [(Node, Int)] = []
        for node in nodes {
            let order = graph.declarationPosition(of: node)
            nodesWithOrder.append((node, order))
        }
        return nodesWithOrder.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    public static func sortByItemOrder(_ edges: [Edge], in graph: VGraph) throws(VError) -> [Edge] {
        var edgesWithOrder: [(Edge, Int)] = []
        for edge in edges {
            let order = graph.declarationPosition(of: edge.id)
            edgesWithOrder.append((edge, order))
        }
        return edgesWithOrder.sorted { $0.1 < $1.1 }.map { $0.0 }
    }
}
