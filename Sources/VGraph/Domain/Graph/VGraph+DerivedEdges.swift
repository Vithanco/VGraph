extension Attributes.Group {
    public static let derivedEdges = TypedAttributeDefinition<Bool>(
        id: "graph.derivedEdges",
        name: "derivedEdges",
        description: "Whether a view draws a dotted edge for a chain it hides",
        defaultValue: true,
        target: .group
    )
}

extension VGraph {
    public var drawsDerivedEdges: Bool {
        (try? get(attribute: Attributes.Group.derivedEdges)) ?? true
    }

    func addingDerivedEdges(of origin: VGraph, visible: Set<String>) throws(VError) -> VGraph {
        let pairs = Self.derivedPairs(edges: origin.edges.map { (from: $0.from.id, to: $0.to.id) }, visible: visible)
        return try pairs.folding(self) { (graph, pair) throws(VError) in
            let (typed, type) = try graph.derivedEdgeType(
                from: try graph.nodeType(for: Node(rawValue: pair.from)), to: try graph.nodeType(for: Node(rawValue: pair.to)))
            let edge = Edge(string: "derived-\(pair.from)-\(pair.to)", from: pair.from, to: pair.to)
            return try typed.adding(edge: edge, edgeType: type)
        }
    }

    /// One dotted engine type per pair of node types, made on first use.
    private func derivedEdgeType(from: NodeType, to: NodeType) throws(VError) -> (VGraph, EdgeType) {
        let type = EdgeType(id: "\(EdgeType.derivedPrefix)\(from.id)__\(to.id)", from: from, to: to)
        guard get(edgeType: type.id) == nil else { return (self, type) }
        let content = NotationContent(edgeTypes: [type], values: [.edgeType(type, [Attributes.Edge.style(.dotted)])])
        return (try placing(content, in: .engine), type)
    }

    /// Each visible pair a hidden chain joins and no real edge already does.
    private static func derivedPairs(edges: [(from: String, to: String)], visible: Set<String>) -> [(from: String, to: String)] {
        var successors: [String: [String]] = [:]
        var real: Set<String> = []
        for edge in edges {
            successors[edge.from, default: []].append(edge.to)
            if visible.contains(edge.from) && visible.contains(edge.to) { real.insert(pairKey(edge.from, edge.to)) }
        }
        var result: [(from: String, to: String)] = []
        for start in visible.sorted() {
            var stack = (successors[start] ?? []).filter { !visible.contains($0) }
            var seen: Set<String> = []
            var reached: Set<String> = []
            while let hidden = stack.popLast() {
                if !seen.insert(hidden).inserted { continue }
                for next in successors[hidden] ?? [] {
                    if visible.contains(next) { reached.insert(next) } else { stack.append(next) }
                }
            }
            for end in reached.sorted() where !real.contains(pairKey(start, end)) {
                result.append((from: start, to: end))
            }
        }
        return result
    }

    private static func pairKey(_ from: String, _ to: String) -> String { from + "\u{1F}" + to }
}
