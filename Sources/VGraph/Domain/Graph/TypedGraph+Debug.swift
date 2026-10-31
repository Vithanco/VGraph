extension TypedGraph: CustomDebugStringConvertible {
    public var debugDescription: String {
        var output = """
            TypedGraph Debug Info:
            =====================

            Graph Structure:
            ----------------
            Nodes: \(nodes.count)
            Edges: \(edges.count)
            Node Types: \(nodeTypes.count)
            Edge Types: \(edgeTypes.count)

            """

        if !nodeTypes.isEmpty {
            output += "Node Types:\n"
            for nodeType in nodeTypes {
                let nodeCount = nodeTypeMapping.getMany(one: nodeType)?.count ?? 0
                output += "  - \(nodeType.id) (\(nodeCount) nodes)\n"
            }
            output += "\n"
        }

        if !edgeTypes.isEmpty {
            output += "Edge Types:\n"
            for edgeType in edgeTypes {
                let edgeCount = edgeTypeMapping.getMany(one: edgeType.id)?.count ?? 0
                output += "  - \(edgeType.id): \(edgeType.from.id) -> \(edgeType.to.id) (\(edgeCount) edges)\n"
            }
            output += "\n"
        }

        if !nodes.isEmpty {
            output += "Nodes:\n"
            for node in nodes.prefix(20) {  // Limit to first 20 to avoid huge output
                let type = nodeType(for: node)?.id ?? "unknown"
                output += "  - \(node.id) [type: \(type)]\n"
            }
            if nodes.count > 20 {
                output += "  ... and \(nodes.count - 20) more nodes\n"
            }
            output += "\n"
        }

        if !edges.isEmpty {
            output += "Edges:\n"
            for edge in edges.prefix(20) {  // Limit to first 20
                let type = edgeType(for: edge.id)?.id ?? "unknown"
                output += "  - \(edge.id): \(edge.from.id) -> \(edge.to.id) [type: \(type)]\n"
            }
            if edges.count > 20 {
                output += "  ... and \(edges.count - 20) more edges\n"
            }
        }

        return output
    }

    public var debugSummary: String {
        return
            "TypedGraph(nodes: \(nodes.count), edges: \(edges.count), nodeTypes: \(nodeTypes.count), edgeTypes: \(edgeTypes.count))"
    }
}
