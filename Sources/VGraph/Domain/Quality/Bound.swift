// How many edges of a type a notation allows, and the check that reports a
// document that says otherwise. See ADR-0011.

public enum Bound {
    /// The notation is silent. Not `0`, which on a minimum means the same in
    /// effect but says the notation deliberately requires none.
    public static let unbounded = -1

    static func isStated(_ bound: Int) -> Bool { bound >= 0 }

    /// One row of the name table. `formerly` is the first name (ADR-0011): still
    /// parsed, never written, so a document migrates the next time it is saved.
    public struct Name: Sendable {
        public let name: String
        public let formerly: String?
        public let definition: TypedAttributeDefinition<Int>

        func matches(_ key: String) -> Bool {
            let wanted = key.lowercased()
            return name.lowercased() == wanted || formerly?.lowercased() == wanted
        }
    }

    /// The bounds a `vnotation` may write on an `edge type:` line.
    ///
    /// One table for both reading a `vnotation` and writing one back: the two
    /// lists of spellings have to agree exactly, and the only way to keep them in
    /// step is to have one.
    public static let edgeBounds: [Name] = [
        Name(name: "outDegreeMin", formerly: "perSourceMin", definition: Attributes.Edge.outDegreeMin),
        Name(name: "outDegreeMax", formerly: "perSourceMax", definition: Attributes.Edge.outDegreeMax),
        Name(name: "inDegreeMin", formerly: "perTargetMin", definition: Attributes.Edge.inDegreeMin),
        Name(name: "inDegreeMax", formerly: "perTargetMax", definition: Attributes.Edge.inDegreeMax),
        Name(name: "samePairMin", formerly: nil, definition: Attributes.Edge.samePairMin),
        Name(name: "samePairMax", formerly: nil, definition: Attributes.Edge.samePairMax),
    ]

    /// The same for a `node type:` line.
    public static let nodeBounds: [Name] = [
        Name(name: "totalOutDegreeMin", formerly: "totalOutMin", definition: Attributes.Node.totalOutDegreeMin),
        Name(name: "totalOutDegreeMax", formerly: "totalOutMax", definition: Attributes.Node.totalOutDegreeMax),
        Name(name: "totalInDegreeMin", formerly: "totalInMin", definition: Attributes.Node.totalInDegreeMin),
        Name(name: "totalInDegreeMax", formerly: "totalInMax", definition: Attributes.Node.totalInDegreeMax),
    ]

    /// Case-insensitive, because `vglKey` lowercases and a hand-written notation
    /// will use the camelCase spelling the documentation shows.
    public static func edgeBound(named key: String) -> Name? {
        edgeBounds.first { $0.matches(key) }
    }

    public static func nodeBound(named key: String) -> Name? {
        nodeBounds.first { $0.matches(key) }
    }
}

extension GenericQualityChecks {

    /// Report every declared [[Bound]] the graph breaks.
    ///
    /// Advisory rather than enforced in `adding(edge:)`, because a minimum cannot be
    /// judged while a graph is still being built — a cloud passes through one Need
    /// on its way to two (ADR-0011).
    public static func brokenBounds(graph: VGraph) -> [MessageWithSeverity] {
        let topology = GraphTopology(edges: graph.edges)
        return graph.edgeTypes.flatMap { check(edgeType: $0, in: graph) }
            + graph.nodeTypes.flatMap { check(nodeType: $0, in: graph, topology: topology) }
    }

    // MARK: - Per edge type

    private static func check(edgeType: EdgeType, in graph: VGraph) -> [MessageWithSeverity] {
        let bounds = EdgeTypeBounds(of: edgeType, in: graph)
        guard bounds.statesAny else { return [] }

        let ofThisType = graph.counted(edgesOf: edgeType)
        let name = edgeType.id.description

        let excess =
            excessMessages(
                over: bounds.outDegreeMax, in: ofThisType, keyedBy: { $0.from.id },
                reason: { "leaving \(quoted(graph.name(of: $0.from)))" }, named: name)
            + excessMessages(
                over: bounds.inDegreeMax, in: ofThisType, keyedBy: { $0.to.id },
                reason: { "entering \(quoted(graph.name(of: $0.to)))" }, named: name)
            + excessMessages(
                over: bounds.samePairMax, in: ofThisType, keyedBy: { $0.pair },
                reason: { "between \(quoted(graph.name(of: $0.from))) and \(quoted(graph.name(of: $0.to)))" },
                named: name)
        let shortfall =
            shortfallMessages(
                under: bounds.outDegreeMin, of: edgeType.from, counting: ofThisType, at: .from, named: name, in: graph)
            + shortfallMessages(
                under: bounds.inDegreeMin, of: edgeType.to, counting: ofThisType, at: .to, named: name, in: graph)
            + pairShortfallMessages(under: bounds.samePairMin, in: ofThisType, named: name, in: graph)
        return excess + shortfall
    }

    private static func excessMessages(
        over max: Int, in edges: [CountedEdge], keyedBy key: (CountedEdge) -> String,
        reason: (CountedEdge) -> String, named name: String
    ) -> [MessageWithSeverity] {
        guard Bound.isStated(max) else { return [] }
        var seen: [String: Int] = [:]
        var messages: [MessageWithSeverity] = []
        for counted in edges {
            let bucket = key(counted)
            let position = (seen[bucket] ?? 0) + 1
            seen[bucket] = position
            guard position > max else { continue }
            messages.append(
                MessageWithSeverity(
                    message: "Too many \"\(name)\" edges \(reason(counted)) — at most \(max) allowed",
                    severity: .error,
                    target: .edge(from: counted.edge.from.description, to: counted.edge.to.description)))
        }
        return messages
    }

    /// The node, because there is no missing edge to point at; a warning, because
    /// every unfinished document is short of its minima (ADR-0011).
    private static func shortfallMessages(
        under min: Int, of nodeType: NodeType, counting edges: [CountedEdge], at end: VEdgeEnd,
        named name: String, in graph: VGraph
    ) -> [MessageWithSeverity] {
        guard Bound.isStated(min), min > 0 else { return [] }
        return graph.boundElements(of: nodeType).compactMap { element in
            let count = edges.filter { (end == .from ? $0.from : $0.to) == element }.count
            guard count < min else { return nil }
            return MessageWithSeverity(
                message:
                    "\(quoted(graph.name(of: element))) needs at least \(min) \"\(name)\" "
                    + "\(edgeDirection(at: end)) edge\(min == 1 ? "" : "s") — has \(count)",
                severity: .warning,
                target: .node(element.id))
        }
    }

    /// A pair with no edge of this type at all is `outDegreeMin` / `inDegreeMin`'s
    /// business, not this one's.
    private static func pairShortfallMessages(
        under min: Int, in edges: [CountedEdge], named name: String, in graph: VGraph
    ) -> [MessageWithSeverity] {
        guard Bound.isStated(min), min > 0 else { return [] }
        var counts: [String: Int] = [:]
        var firstOfPair: [String: Edge] = [:]
        for counted in edges {
            counts[counted.pair] = (counts[counted.pair] ?? 0) + 1
            if firstOfPair[counted.pair] == nil { firstOfPair[counted.pair] = counted.edge }
        }
        var messages: [MessageWithSeverity] = []
        for counted in edges {
            guard let count = counts[counted.pair], count < min, let first = firstOfPair[counted.pair],
                first.id == counted.edge.id
            else { continue }
            messages.append(
                MessageWithSeverity(
                    message:
                        "\(quoted(graph.name(of: counted.from))) → \(quoted(graph.name(of: counted.to))) "
                        + "needs at least \(min) \"\(name)\" edges — has \(count)",
                    severity: .warning,
                    target: .edge(from: counted.edge.from.description, to: counted.edge.to.description)))
        }
        return messages
    }

    // MARK: - Per node type

    private static func check(nodeType: NodeType, in graph: VGraph, topology: GraphTopology)
        -> [MessageWithSeverity]
    {
        let bounds = NodeTypeBounds(of: nodeType, in: graph)
        guard bounds.statesAny else { return [] }

        return graph.nodes(ofType: nodeType).flatMap { node in
            totalMessages(
                node: node, edges: topology.outgoingEdges(of: node), min: bounds.outDegreeMin, max: bounds.outDegreeMax,
                at: .from, in: graph)
                + totalMessages(
                    node: node, edges: topology.incomingEdges(of: node), min: bounds.inDegreeMin,
                    max: bounds.inDegreeMax, at: .to, in: graph)
        }
    }

    private static func totalMessages(
        node: Node, edges: [Edge], min: Int, max: Int, at end: VEdgeEnd, in graph: VGraph
    ) -> [MessageWithSeverity] {
        let direction = edgeDirection(at: end)
        // Same rule as an edge-type maximum, so the two read alike in the
        // diagnostics box: every edge past the allowed ones is flagged.
        let pastMaximum = Bound.isStated(max) ? Array(edges.dropFirst(max)) : []
        let excess = pastMaximum.map { edge in
            MessageWithSeverity(
                message: "\(quoted(graph.name(of: node))) has too many \(direction) edges — at most \(max) allowed",
                severity: .error,
                target: .edge(from: edge.from.description, to: edge.to.description))
        }
        guard Bound.isStated(min), min > 0, edges.count < min else { return excess }
        return excess + [
            MessageWithSeverity(
                message:
                    "\(quoted(graph.name(of: node))) needs at least \(min) \(direction) "
                    + "edge\(min == 1 ? "" : "s") — has \(edges.count)",
                severity: .warning,
                target: .node(node.description))
        ]
    }

    // MARK: - Naming

    private static func quoted(_ text: String) -> String { "\"\(text)\"" }
}

private func edgeDirection(at end: VEdgeEnd) -> String {
    switch end {
    case .from: return "outgoing"
    case .to: return "incoming"
    }
}

/// Read once, so the check can skip a type that declares nothing without touching
/// the graph's edges at all.
private struct EdgeTypeBounds {
    let outDegreeMin: Int
    let outDegreeMax: Int
    let inDegreeMin: Int
    let inDegreeMax: Int
    let samePairMin: Int
    let samePairMax: Int

    init(of edgeType: EdgeType, in graph: VGraph) {
        func read(_ definition: TypedAttributeDefinition<Int>) -> Int {
            (try? graph.get(edgeType: edgeType.id, attribute: definition)) ?? Bound.unbounded
        }
        self.outDegreeMin = read(Attributes.Edge.outDegreeMin)
        self.outDegreeMax = read(Attributes.Edge.outDegreeMax)
        self.inDegreeMin = read(Attributes.Edge.inDegreeMin)
        self.inDegreeMax = read(Attributes.Edge.inDegreeMax)
        self.samePairMin = read(Attributes.Edge.samePairMin)
        self.samePairMax = read(Attributes.Edge.samePairMax)
    }

    var statesAny: Bool {
        [outDegreeMin, outDegreeMax, inDegreeMin, inDegreeMax, samePairMin, samePairMax].contains { Bound.isStated($0) }
    }
}

/// The node type's totals, read once for the same reason.
private struct NodeTypeBounds {
    let outDegreeMin: Int
    let outDegreeMax: Int
    let inDegreeMin: Int
    let inDegreeMax: Int

    init(of nodeType: NodeType, in graph: VGraph) {
        func read(_ definition: TypedAttributeDefinition<Int>) -> Int {
            (try? graph.get(nodeType: nodeType, attribute: definition)) ?? Bound.unbounded
        }
        self.outDegreeMin = read(Attributes.Node.totalOutDegreeMin)
        self.outDegreeMax = read(Attributes.Node.totalOutDegreeMax)
        self.inDegreeMin = read(Attributes.Node.totalInDegreeMin)
        self.inDegreeMax = read(Attributes.Node.totalInDegreeMax)
    }

    var statesAny: Bool {
        [outDegreeMin, outDegreeMax, inDegreeMin, inDegreeMax].contains { Bound.isStated($0) }
    }
}
