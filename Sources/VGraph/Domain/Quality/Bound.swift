//
//  Bound.swift
//  VGraph
//
//  How many edges of a type a notation allows, and the check that reports a
//  document that says otherwise. See ADR-0011.
//

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
    /// One table rather than six more cases in `applyEdgeTypeAttributes` and six
    /// more hand-written diffs in `reconstructEdgeTypeSpec`: those two lists have
    /// to agree exactly, and the only way to keep them in step is to have one.
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

    var statesNothing: Bool {
        !Bound.isStated(outDegreeMin) && !Bound.isStated(outDegreeMax)
            && !Bound.isStated(inDegreeMin) && !Bound.isStated(inDegreeMax)
            && !Bound.isStated(samePairMin) && !Bound.isStated(samePairMax)
    }
}

extension GenericQualityChecks {

    /// Report every declared [[Bound]] bound the graph breaks.
    ///
    /// Advisory rather than enforced in `add(edge:)`, because a minimum cannot be
    /// judged while a graph is still being built — a cloud passes through one Need
    /// on its way to two (ADR-0011).
    public static func brokenBounds(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        for edgeType in graph.edgeTypes {
            messages.append(contentsOf: check(edgeType: edgeType, in: graph))
        }
        let topology = GraphTopology(edges: graph.edges)
        for nodeType in graph.nodeTypes {
            messages.append(contentsOf: check(nodeType: nodeType, in: graph, topology: topology))
        }
        return messages
    }

    // MARK: - Per edge type

    /// An edge with the elements its ends count for (ADR-0032).
    private struct Counted {
        let edge: Edge
        let from: BoundElement
        let to: BoundElement

        var pair: String { "\(from.id)\u{1}\(to.id)" }
    }

    private static func check(edgeType: EdgeType, in graph: VGraph) -> [MessageWithSeverity] {
        let bounds = EdgeTypeBounds(of: edgeType, in: graph)
        guard !bounds.statesNothing else { return [] }

        var ofThisType: [Counted] = []
        for edge in graph.edges {
            guard let actual = try? graph.edgeType(for: edge.id), actual.id == edgeType.id else { continue }
            let ends = graph.boundEnds(of: edge, typed: edgeType)
            ofThisType.append(Counted(edge: edge, from: ends.from, to: ends.to))
        }

        var messages: [MessageWithSeverity] = []
        let name = edgeType.id.description

        messages.append(
            contentsOf: excessMessages(
                over: bounds.outDegreeMax, in: ofThisType, keyedBy: { $0.from.id },
                reason: { "leaving \(quoted(label(of: $0.from, in: graph)))" }, named: name))
        messages.append(
            contentsOf: excessMessages(
                over: bounds.inDegreeMax, in: ofThisType, keyedBy: { $0.to.id },
                reason: { "entering \(quoted(label(of: $0.to, in: graph)))" }, named: name))
        messages.append(
            contentsOf: excessMessages(
                over: bounds.samePairMax, in: ofThisType, keyedBy: { $0.pair },
                reason: {
                    "between \(quoted(label(of: $0.from, in: graph))) and \(quoted(label(of: $0.to, in: graph)))"
                }, named: name))

        messages.append(
            contentsOf: shortfallMessages(
                under: bounds.outDegreeMin, of: edgeType.from, counting: ofThisType, leaving: true,
                named: name, in: graph))
        messages.append(
            contentsOf: shortfallMessages(
                under: bounds.inDegreeMin, of: edgeType.to, counting: ofThisType, leaving: false,
                named: name, in: graph))
        messages.append(
            contentsOf: pairShortfallMessages(under: bounds.samePairMin, in: ofThisType, named: name, in: graph))

        return messages
    }

    private static func excessMessages(
        over max: Int, in edges: [Counted], keyedBy key: (Counted) -> String,
        reason: (Counted) -> String, named name: String
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
        under min: Int, of nodeType: NodeType, counting edges: [Counted], leaving: Bool,
        named name: String, in graph: VGraph
    ) -> [MessageWithSeverity] {
        guard Bound.isStated(min), min > 0 else { return [] }
        var messages: [MessageWithSeverity] = []
        for element in graph.boundElements(of: nodeType) {
            var count = 0
            for counted in edges where (leaving ? counted.from : counted.to) == element {
                count += 1
            }
            guard count < min else { continue }
            messages.append(
                MessageWithSeverity(
                    message:
                        "\(quoted(label(of: element, in: graph))) needs at least \(min) \"\(name)\" "
                        + "\(leaving ? "outgoing" : "incoming") edge\(min == 1 ? "" : "s") — has \(count)",
                    severity: .warning,
                    target: .node(element.id)))
        }
        return messages
    }

    /// A pair with no edge of this type at all is `outDegreeMin` / `inDegreeMin`'s
    /// business, not this one's.
    private static func pairShortfallMessages(
        under min: Int, in edges: [Counted], named name: String, in graph: VGraph
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
                        "\(quoted(label(of: counted.from, in: graph))) → \(quoted(label(of: counted.to, in: graph))) "
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
        func read(_ definition: TypedAttributeDefinition<Int>) -> Int {
            (try? graph.get(nodeType: nodeType, attribute: definition)) ?? Bound.unbounded
        }
        let outDegreeMin = read(Attributes.Node.totalOutDegreeMin)
        let outDegreeMax = read(Attributes.Node.totalOutDegreeMax)
        let inDegreeMin = read(Attributes.Node.totalInDegreeMin)
        let inDegreeMax = read(Attributes.Node.totalInDegreeMax)
        guard
            Bound.isStated(outDegreeMin) || Bound.isStated(outDegreeMax)
                || Bound.isStated(inDegreeMin) || Bound.isStated(inDegreeMax)
        else { return [] }

        var messages: [MessageWithSeverity] = []
        for node in graph.nodes {
            guard let actual = try? graph.nodeType(for: node), actual == nodeType else { continue }
            messages.append(
                contentsOf: totalMessages(
                    node: node, edges: topology.outgoingEdges(of: node), min: outDegreeMin, max: outDegreeMax, leaving: true, in: graph))
            messages.append(
                contentsOf: totalMessages(
                    node: node, edges: topology.incomingEdges(of: node), min: inDegreeMin, max: inDegreeMax, leaving: false, in: graph))
        }
        return messages
    }

    private static func totalMessages(
        node: Node, edges: [Edge], min: Int, max: Int, leaving: Bool, in graph: VGraph
    ) -> [MessageWithSeverity] {
        let direction = leaving ? "outgoing" : "incoming"
        var messages: [MessageWithSeverity] = []

        if Bound.isStated(max), edges.count > max {
            // Same rule as an edge-type maximum, so the two read alike in the
            // diagnostics box.
            var index = 0
            for edge in edges {
                index += 1
                guard index > max else { continue }
                messages.append(
                    MessageWithSeverity(
                        message:
                            "\(quoted(label(of: node, in: graph))) has too many \(direction) edges "
                            + "— at most \(max) allowed",
                        severity: .error,
                        target: .edge(from: edge.from.description, to: edge.to.description)))
            }
        }

        if Bound.isStated(min), min > 0, edges.count < min {
            messages.append(
                MessageWithSeverity(
                    message:
                        "\(quoted(label(of: node, in: graph))) needs at least \(min) \(direction) "
                        + "edge\(min == 1 ? "" : "s") — has \(edges.count)",
                    severity: .warning,
                    target: .node(node.description)))
        }
        return messages
    }

    // MARK: - Naming

    private static func quoted(_ text: String) -> String { "\"\(text)\"" }

    private static func label(of element: BoundElement, in graph: VGraph) -> String {
        switch element {
        case .node(let node): return label(of: node, in: graph)
        case .detailedNode(let group): return label(of: group, in: graph)
        }
    }
}
