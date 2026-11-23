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

    /// At most one edge between two nodes in the same direction.
    public static let noParallelEdges = QualityCheckSpec(name: "noParallelEdges")

    /// e.g. `"nodeCountRange(Battle, 1, 20)"` or `"treeStructure"`
    public var specString: String {
        if params.isEmpty { return name }
        return "\(name)(\(params.joined(separator: ", ")))"
    }

    /// Parse a spec string like `"nodeCountRange(Battle, 1, 20)"` or `"treeStructure"`.
    public static func parse(_ text: String) -> QualityCheckSpec {
        let trimmed = text.trimmingWhitespace()
        guard let parenStart = trimmed.firstIndex(of: "("),
            let parenEnd = trimmed.lastIndex(of: ")"),
            parenStart < parenEnd
        else {
            return QualityCheckSpec(name: trimmed)
        }
        let name = String(trimmed[trimmed.startIndex..<parenStart])
        let params = trimmed[trimmed.index(after: parenStart)..<parenEnd].split(separator: ",").map {
            String($0).trimmingWhitespace()
        }
        return QualityCheckSpec(name: name, params: params)
    }
}

public enum QualityCheckRegistry {

    private typealias Make = (QualityCheckSpec) throws(VError) -> QualityCheck

    /// One list for dispatch and for the names an unknown one is told about, so the
    /// two cannot drift.
    private static var checks: [(name: String, make: Make)] {
        [
            ("treeStructure", { _ in treeStructureCheck }),
            ("disconnectedNodes", { _ in GenericQualityChecks.disconnectedNodes }),
            ("noParallelEdges", { _ in noParallelEdgesCheck }),
            ("redundantJunctor", { _ in GenericQualityChecks.redundantJunctor }),
            (
                "exactlyOne",
                { (spec: QualityCheckSpec) throws(VError) -> QualityCheck in
                    guard let nodeTypeName = spec.params.first, spec.params.count == 1 else {
                        throw VError.parsingError(
                            "qualityCheck 'exactlyOne' requires exactly 1 parameter: exactlyOne(NodeTypeName)")
                    }
                    return exactlyOneCheck(nodeTypeName: nodeTypeName)
                }
            ),
            (
                "nodeCountRange",
                { (spec: QualityCheckSpec) throws(VError) -> QualityCheck in
                    guard spec.params.count == 3, let min = Int(spec.params[1]), let max = Int(spec.params[2]) else {
                        throw VError.parsingError(
                            "qualityCheck 'nodeCountRange' requires 3 parameters: nodeCountRange(NodeTypeName, min, max)")
                    }
                    return nodeCountRangeCheck(nodeTypeName: spec.params[0], min: min, max: max)
                }
            ),
            (
                "labelLength",
                { (spec: QualityCheckSpec) throws(VError) -> QualityCheck in
                    guard spec.params.count == 1, let maxWords = Int(spec.params[0]) else {
                        throw VError.parsingError("qualityCheck 'labelLength' requires 1 parameter: labelLength(maxWords)")
                    }
                    return labelLengthCheck(maxWords: maxWords)
                }
            ),
        ]
    }

    public static func resolve(_ spec: QualityCheckSpec) throws(VError) -> QualityCheck {
        guard let check = checks.first(where: { $0.name == spec.name }) else {
            throw VError.parsingError(
                "Unknown quality check '\(spec.name)'. Available: \(checks.map { $0.name }.joined(separator: ", "))")
        }
        return try check.make(spec)
    }

    // MARK: - Check implementations

    /// Warns if any node has more than one incoming edge (tree structure violation).
    static func treeStructureCheck(_ graph: VGraph) -> [MessageWithSeverity] {
        let topology = GraphTopology(edges: graph.edges)
        return graph.nodes.compactMap { node in
            let incomingCount = topology.incomingEdges(of: node).count
            guard incomingCount > 1 else { return nil }
            let typeName = ((try? graph.nodeType(for: node))?.id.description) ?? "Node"
            return MessageWithSeverity(
                message:
                    "\(typeName) \"\(graph.name(of: node))\" has \(incomingCount) parent nodes (tree structure expects at most 1)",
                severity: .warning,
                target: .node(node.description)
            )
        }
    }

    /// A [[Quality check]] rather than a [[Bound]] because it counts
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
                        "\"\(graph.name(of: edge.from))\" → \"\(graph.name(of: edge.to))\" "
                        + "is drawn more than once — at most one edge between two nodes",
                    severity: .error,
                    target: .edge(from: edge.from.description, to: edge.to.description)))
        }
        return messages
    }

    /// Error if the count of nodes with the given type name is not exactly 1.
    static func exactlyOneCheck(nodeTypeName: String) -> QualityCheck {
        return { graph in
            let count = nodeCount(ofTypeNamed: nodeTypeName, in: graph)
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
        return { graph in
            let count = nodeCount(ofTypeNamed: nodeTypeName, in: graph)
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

    private static func nodeCount(ofTypeNamed name: String, in graph: VGraph) -> Int {
        graph.nodes(ofType: NodeType(rawValue: name)).count
    }

    /// Warns if any label among `nodes` has more than maxWords words.
    static func labelLengthCheck(maxWords: Int, among nodes: @escaping (VGraph) -> [Node] = { $0.nodes })
        -> QualityCheck
    {
        return { graph in
            nodes(graph).compactMap { node in
                guard let label: String = try? graph.get(node: node, attribute: Attributes.Node.label) else { return nil }
                let wordCount = label.split(separator: " ").count
                guard wordCount > maxWords else { return nil }
                return MessageWithSeverity(
                    message: "Node \"\(label)\" has \(wordCount) words (recommended: \(maxWords) or fewer)",
                    severity: .warning,
                    target: .node(node.description)
                )
            }
        }
    }
}
