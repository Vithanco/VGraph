/// Which loops of a Causal Loop Diagram get a [[Loop marker]] (ADR-0028).
public enum LoopMarkers: EnumAttributeType {
    /// Every loop, shortest first, up to the search's cap.
    case all
    /// A set of loops that together cover every feedback link.
    case independent
    case none

    public var value: String {
        switch self {
        case .all: return "all"
        case .independent: return "independent"
        case .none: return "none"
        }
    }

    public var readableName: String {
        switch self {
        case .all: return "All loops"
        case .independent: return "Independent loops"
        case .none: return "No loop markers"
        }
    }

    /// Stored and written as the VGL value: `loopmarkers: independent`.
    public var alias: String { value }

    public static let typeName: String = "LoopMarkers"

    /// The loops of `search` to mark.
    func selecting(from search: TypedGraph.Graph.LoopSearch) -> [TypedGraph.Graph.Loop] {
        switch self {
        case .all: return search.loops
        case .independent: return search.independentLoops
        case .none: return []
        }
    }
}

extension Attributes.Group {
    public static let loopMarkers = TypedAttributeDefinition<LoopMarkers>(
        id: "graph.loopMarkers",
        name: "loopMarkers",
        description: "Which loops of a Causal Loop Diagram get a marker: all, independent or none",
        defaultValue: .all,
        target: .graph
    )

    public static let derivedEdges = TypedAttributeDefinition<Bool>(
        id: "graph.derivedEdges",
        name: "derivedEdges",
        description: "Whether a view draws a dotted edge for a chain it hides",
        defaultValue: true,
        target: .graph
    )
}

extension VGraph {
    /// Only a notation that records its loops before folding marks any — today,
    /// the Causal Loop Diagram.
    public var marksLoops: Bool {
        NotationRegistry.entry(for: notationName)?.step?.id == .recordLoops
    }

    public var loopMarkers: LoopMarkers {
        (try? get(attribute: Attributes.Group.loopMarkers)) ?? .all
    }

    public var drawsDerivedEdges: Bool {
        (try? get(attribute: Attributes.Group.derivedEdges)) ?? true
    }
}
