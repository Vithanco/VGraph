extension VGraph: CustomDebugStringConvertible {
    public var debugDescription: String {
        let graphName: String = (try? get(graphAttribute: Attributes.Group.label)) ?? "none"
        let summary = """
            VGraph Debug Info:
            ==================
            Name: \(graphName)
            Nodes: \(nodes.count)
            Edges: \(edges.count)
            Node Types: \(nodeTypes.count)
            Edge Types: \(edgeTypes.count)
            Groups: \(groups.count)

            """
        let nodeTypeLines = nodeTypes.map { type in
            "\(type.id) (\(typedGraph.nodeTypeMapping.getMany(one: type)?.count ?? 0) nodes)"
        }
        let edgeTypeLines = edgeTypes.map { type in
            "\(type.id): \(type.from.id) -> \(type.to.id) (\(typedGraph.edgeTypeMapping.getMany(one: type.id)?.count ?? 0) edges)"
        }
        let nodeLines = nodes.map { node in "\(node.id) [type: \((try? nodeType(for: node))?.id ?? "unknown")]" }
        let edgeLines = edges.map { edge in
            "\(edge.id): \(edge.from.id) -> \(edge.to.id) [type: \((try? edgeType(for: edge.id))?.id ?? "unknown")]"
        }
        let lists = [
            DebugList(title: "Node Types", lines: nodeTypeLines),
            DebugList(title: "Edge Types", lines: edgeTypeLines),
            DebugList(title: "Groups", lines: groups.map { "\($0.id)" }, limit: 10),
            DebugList(title: "Nodes", lines: nodeLines, limit: 20),
        ]
        return summary + lists.map { $0.text.isEmpty ? "" : $0.text + "\n" }.joined()
            + DebugList(title: "Edges", lines: edgeLines, limit: 20).text
    }
}

/// Long lists are cut short, so a debugger's console stays readable.
private struct DebugList {
    let title: String
    let lines: [String]
    let limit: Int

    init(title: String, lines: [String], limit: Int = .max) {
        self.title = title
        self.lines = lines
        self.limit = limit
    }

    var text: String {
        guard !lines.isEmpty else { return "" }
        let listed = lines.prefix(limit).map { "  - \($0)\n" }.joined()
        let more = lines.count > limit ? "  ... and \(lines.count - limit) more \(title.lowercased())\n" : ""
        return "\(title):\n" + listed + more
    }
}
