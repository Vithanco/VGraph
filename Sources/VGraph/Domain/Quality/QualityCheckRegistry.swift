// Named quality check resolution for dynamic notations.
// Users reference checks by name in vnotation blocks; this registry
// maps those names to compiled QualityCheck closures.

/// Example: `"nodeCountRange(Battle, 1, 20)"` → name="nodeCountRange", params=["Battle","1","20"]
public struct QualityCheckSpec: VProtocol {
    public let name: String
    public let params: [String]

    public init(name: String, params: [String] = []) {
        self.name = name
        self.params = params
    }

    /// At most one edge between two nodes in the same direction. See [[Graph criterion]].
    public static let noParallelEdges = QualityCheckSpec(name: "noParallelEdges")

    /// e.g. `"nodeCountRange(Battle, 1, 20)"` or `"treeStructure"`
    public var specString: String {
        if params.isEmpty { return name }
        return "\(name)(\(params.joined(separator: ", ")))"
    }

    /// Parse a spec string like `"nodeCountRange(Battle, 1, 20)"` or `"treeStructure"`.
    public static func parse(_ s: String) -> QualityCheckSpec {
        let trimmed = s.trimmingWhitespace()
        guard let parenStart = trimmed.firstIndex(of: "("),
            let parenEnd = trimmed.lastIndex(of: ")"),
            parenStart < parenEnd
        else {
            return QualityCheckSpec(name: trimmed)
        }
        let name = String(trimmed[trimmed.startIndex..<parenStart])
        let paramsStr = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])
        let params = paramsStr.split(separator: ",").map { String($0).trimmingWhitespace() }
        return QualityCheckSpec(name: name, params: params)
    }
}

public enum QualityCheckRegistry {

    public static func resolve(_ spec: QualityCheckSpec) throws(VError) -> QualityCheck {
        switch spec.name {

        case "treeStructure":
            return treeStructureCheck

        case "disconnectedNodes":
            return GenericQualityChecks.disconnectedNodes

        case "noParallelEdges":
            return noParallelEdgesCheck

        case "redundantJunctor":
            return GenericQualityChecks.redundantJunctor

        case "exactlyOne":
            guard let nodeTypeName = spec.params.first, spec.params.count == 1 else {
                throw VError.parsingError("qualityCheck 'exactlyOne' requires exactly 1 parameter: exactlyOne(NodeTypeName)")
            }
            return exactlyOneCheck(nodeTypeName: nodeTypeName)

        case "nodeCountRange":
            guard spec.params.count == 3,
                let min = Int(spec.params[1]),
                let max = Int(spec.params[2])
            else {
                throw VError.parsingError("qualityCheck 'nodeCountRange' requires 3 parameters: nodeCountRange(NodeTypeName, min, max)")
            }
            return nodeCountRangeCheck(nodeTypeName: spec.params[0], min: min, max: max)

        case "labelLength":
            guard spec.params.count == 1, let maxWords = Int(spec.params[0]) else {
                throw VError.parsingError("qualityCheck 'labelLength' requires 1 parameter: labelLength(maxWords)")
            }
            return labelLengthCheck(maxWords: maxWords)

        default:
            throw VError.parsingError(
                "Unknown qualityCheck '\(spec.name)'. Available: treeStructure, disconnectedNodes, noParallelEdges, redundantJunctor, exactlyOne, nodeCountRange, labelLength"
            )
        }
    }

    // MARK: - Check implementations

    /// Warns if any node has more than one incoming edge (tree structure violation).
    static func treeStructureCheck(_ graph: VGraph) -> [MessageWithSeverity] {
        let topology = GraphTopology(edges: graph.edges)
        var messages: [MessageWithSeverity] = []
        for node in graph.nodes {
            let incomingCount = topology.incomingEdges(of: node).count
            if incomingCount > 1 {
                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                let typeName = ((try? graph.nodeType(for: node))?.id.description) ?? "Node"
                messages.append(
                    MessageWithSeverity(
                        message: "\(typeName) \"\(label)\" has \(incomingCount) parent nodes (tree structure expects at most 1)",
                        severity: .warning,
                        target: .node(node.description)
                    ))
            }
        }
        return messages
    }

    /// A [[Graph criterion]] rather than a [[Bound]] bound because it counts
    /// across every edge type at once, which a bound declared on one edge type
    /// cannot (ADR-0011).
    static func noParallelEdgesCheck(_ graph: VGraph) -> [MessageWithSeverity] {
        var seen: Set<String> = []
        var messages: [MessageWithSeverity] = []
        for edge in graph.edges {
            let pair = "\(edge.from.description)\u{1}\(edge.to.description)"
            guard seen.contains(pair) else {
                seen.insert(pair)
                continue
            }
            messages.append(
                MessageWithSeverity(
                    message:
                        "\(nodeLabel(edge.from, in: graph)) → \(nodeLabel(edge.to, in: graph)) "
                        + "is drawn more than once — at most one edge between two nodes",
                    severity: .error,
                    target: .edge(from: edge.from.description, to: edge.to.description)))
        }
        return messages
    }

    private static func nodeLabel(_ node: Node, in graph: VGraph) -> String {
        guard let label: String = try? graph.get(node: node, attribute: Attributes.Node.label),
            !label.isEmpty
        else { return "\"\(node.description)\"" }
        return "\"\(label)\""
    }

    /// Error if the count of nodes with the given type name is not exactly 1.
    static func exactlyOneCheck(nodeTypeName: String) -> QualityCheck {
        let targetType = NodeType(string: nodeTypeName)
        return { graph in
            let count = graph.nodes.filter { (try? graph.nodeType(for: $0)) == targetType }.count
            if count == 0 {
                return [
                    MessageWithSeverity(
                        message: "Expected exactly 1 \(nodeTypeName) node but found none",
                        severity: .error
                    )
                ]
            } else if count > 1 {
                return [
                    MessageWithSeverity(
                        message: "Expected exactly 1 \(nodeTypeName) node but found \(count)",
                        severity: .error
                    )
                ]
            }
            return []
        }
    }

    /// Warns if the count of nodes with the given type name is outside [min, max].
    static func nodeCountRangeCheck(nodeTypeName: String, min: Int, max: Int) -> QualityCheck {
        let targetType = NodeType(string: nodeTypeName)
        return { graph in
            let count = graph.nodes.filter { (try? graph.nodeType(for: $0)) == targetType }.count
            if count < min || count > max {
                return [
                    MessageWithSeverity(
                        message: "\(nodeTypeName) count is \(count) (recommended: \(min)-\(max))",
                        severity: .warning
                    )
                ]
            }
            return []
        }
    }

    /// Warns if any node label has more than maxWords words.
    static func labelLengthCheck(maxWords: Int) -> QualityCheck {
        return { graph in
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let label: String = try? graph.get(node: node, attribute: Attributes.Node.label) else { continue }
                let wordCount = label.split(separator: " ").count
                if wordCount > maxWords {
                    messages.append(
                        MessageWithSeverity(
                            message: "Node \"\(label)\" has \(wordCount) words (recommended: \(maxWords) or fewer)",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }
    }
}
