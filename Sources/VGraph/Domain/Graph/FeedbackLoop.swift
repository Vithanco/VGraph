public enum LoopDirection: EnumAttributeType {
    case clockwise
    case counterClockwise
    case error

    public var readableName: String {
        switch self {
        case .clockwise: return "Clockwise"
        case .counterClockwise: return "CounterClockwise"
        case .error: return "Error"
        }
    }

    // Explicit per-case strings — no enum-case reflection under Embedded Swift.
    public var value: String {
        switch self {
        case .clockwise: return "clockwise"
        case .counterClockwise: return "counterClockwise"
        case .error: return "error"
        }
    }

    public static let typeName: String = "LoopDirection"
}

public enum LoopStyle: EnumAttributeType {
    case none
    case balancing
    case reinforcing
    /// A step drawn with links of both polarities (ADR-0028). Never an edge's own.
    case ambiguous

    // Explicit per-case strings — no enum-case reflection under Embedded Swift.
    public var value: String {
        switch self {
        case .none: return "none"
        case .balancing: return "balancing"
        case .reinforcing: return "reinforcing"
        case .ambiguous: return "ambiguous"
        }
    }

    public var readableName: String { value }

    public static let typeName: String = "LoopStyle"
}

public struct FeedbackLoop: VProtocol {
    public let edges: [Edge]
    public let nodes: [Node]
    public let loopStyle: LoopStyle
    /// The steps whose links pull both ways, as "“From” → “To”": why the
    /// polarity is `.ambiguous`.
    public let ambiguousLinks: [String]

    init(edges: [Edge], nodes: [Node], loopStyle: LoopStyle, ambiguousLinks: [String] = []) {
        self.edges = edges
        self.nodes = nodes
        self.loopStyle = loopStyle
        self.ambiguousLinks = ambiguousLinks
    }

    /// From node loops (ADR-0028), which may realise a step with several links. One
    /// polarity among them is that step's; two make the loop's `.ambiguous`.
    public static func fromLoops(_ loops: [TypedGraph.Graph.Loop], in graph: VGraph) -> [FeedbackLoop] {
        loops.map { loop in
            var style = LoopStyle.reinforcing
            var ambiguous: [String] = []
            for (index, step) in loop.steps.enumerated() {
                let styles = step.map { $0.loopStyle(in: graph) }
                if styles.contains(where: { $0 != styles[0] }) {
                    let to = loop.nodes[(index + 1) % loop.nodes.count]
                    ambiguous.append("“\(graph.name(of: loop.nodes[index]))” → “\(graph.name(of: to))”")
                    style = Edge.loopStyle(soFar: style, next: .ambiguous)
                } else if let only = styles.first {
                    style = Edge.loopStyle(soFar: style, next: only)
                }
            }
            return FeedbackLoop(
                edges: loop.steps.compactMap { $0.first }, nodes: loop.nodes, loopStyle: style,
                ambiguousLinks: ambiguous)
        }
    }
}

extension Attributes {

    public struct Loop {

        static let style = AttributeDefinition(
            id: "systemsThinking.loopStyle",
            name: "Loop Style",
            description: "In Causal Loop Diagram, the connections are either balanced or reinforcing.",
            defaultValue: LoopStyle.none.asString,
            target: .edge,
            typeAsString: LoopStyle.typeName
        )

        public static let definitions = AttributeDefContainer([Loop.style])
    }
}

extension Edge {
    public func loopStyle(in graph: VGraph) -> LoopStyle {
        (try? graph.get(edge: id, attribute: Attributes.Loop.style)).flatMap { try? LoopStyle.fromString($0) }
            ?? .none
    }

    /// `.none` anywhere means the loop has no polarity to show; otherwise one
    /// ambiguous step leaves the whole loop's polarity unknown.
    static func loopStyle(soFar: LoopStyle, next: LoopStyle) -> LoopStyle {
        if soFar == .none || next == .none {
            return .none
        }
        if soFar == .ambiguous || next == .ambiguous {
            return .ambiguous
        }
        switch next {
        case .none, .ambiguous:
            return next
        case .reinforcing:
            return soFar
        case .balancing:
            if soFar == .balancing {
                return .reinforcing
            }
            return .balancing
        }
    }
}

// MARK: - Loop Direction (Shoelace Algorithm)

extension FeedbackLoop {
    /// Builds a polygon from edge spline start/end points rather than node centers.
    /// This is essential for 2-node cycles where node centers form a degenerate
    /// line segment (zero area), but edge endpoints are offset to the node borders,
    /// forming a quadrilateral with real area.
    ///
    /// Falls back to node center positions when edge layout data is unavailable.
    ///
    /// See: https://stackoverflow.com/questions/1165647/how-to-determine-if-a-list-of-polygon-points-are-in-clockwise-order/1180256#1180256
    public func loopDirection(in graph: VGraph) -> LoopDirection {
        guard edges.count >= 2, let polygon = polygon(in: graph), polygon.count >= 3 else { return .error }
        let doubledSignedArea = polygon.indices.reduce(0.0) { sum, index in
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            return sum + (next.x - current.x) * (next.y + current.y)
        }
        if doubledSignedArea > 0 { return .counterClockwise }
        if doubledSignedArea < 0 { return .clockwise }
        return .error
    }

    /// `nil` when the edges' ends give no polygon and a node has no position.
    private func polygon(in graph: VGraph) -> [VPoint]? {
        let edgeEnds = edges.flatMap { edge -> [VPoint] in
            guard let layoutData = try? graph.get(edge: edge.id, attribute: Attributes.Edge.layoutData),
                let start = layoutData.splinePoints.first,
                let end = layoutData.splinePoints.last
            else { return [] }
            return [start, end]
        }
        guard edgeEnds.count < 3 else { return edgeEnds }
        let centers = nodes.compactMap { try? graph.get(node: $0, attribute: Attributes.Node.layoutedPos) }
        return centers.count == nodes.count ? centers : nil
    }
}
