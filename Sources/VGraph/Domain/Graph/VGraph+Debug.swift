extension VGraph: CustomDebugStringConvertible {
    public var debugDescription: String {
        let graphName: String = (try? get(graphAttribute: Attributes.Group.label)) ?? "none"
        var output = """
            VGraph Debug Info:
            ==================
            Name: \(graphName)
            Nodes: \(nodes.count)
            Edges: \(edges.count)
            Node Types: \(nodeTypes.count)
            Edge Types: \(edgeTypes.count)
            Groups: \(groups.count)

            """

        if !nodeTypes.isEmpty {
            output += "Node Types:\n"
            for nt in nodeTypes {
                let nodeCount = typedGraph.nodeTypeMapping.getMany(one: nt)?.count ?? 0
                output += "  - \(nt.id) (\(nodeCount) nodes)\n"
            }
            output += "\n"
        }

        if !edgeTypes.isEmpty {
            output += "Edge Types:\n"
            for et in edgeTypes {
                let edgeCount = typedGraph.edgeTypeMapping.getMany(one: et.id)?.count ?? 0
                output += "  - \(et.id): \(et.from.id) -> \(et.to.id) (\(edgeCount) edges)\n"
            }
            output += "\n"
        }

        if !groups.isEmpty {
            output += "Groups:\n"
            for group in groups.prefix(10) {
                output += "  - \(group.id)\n"
            }
            if groups.count > 10 {
                output += "  ... and \(groups.count - 10) more groups\n"
            }
            output += "\n"
        }

        if !nodes.isEmpty {
            output += "Nodes:\n"
            for node in nodes.prefix(20) {
                let typeId = (try? nodeType(for: node))?.id ?? "unknown"
                output += "  - \(node.id) [type: \(typeId)]\n"
            }
            if nodes.count > 20 {
                output += "  ... and \(nodes.count - 20) more nodes\n"
            }
            output += "\n"
        }

        if !edges.isEmpty {
            output += "Edges:\n"
            for edge in edges.prefix(20) {
                let typeId = (try? edgeType(for: edge.id))?.id ?? "unknown"
                output += "  - \(edge.id): \(edge.from.id) -> \(edge.to.id) [type: \(typeId)]\n"
            }
            if edges.count > 20 {
                output += "  ... and \(edges.count - 20) more edges\n"
            }
        }

        return output
    }

    public var debugSummary: String {
        return
            "VGraph(nodes: \(nodes.count), edges: \(edges.count), nodeTypes: \(nodeTypes.count), edgeTypes: \(edgeTypes.count), groups: \(groups.count))"
    }
}
