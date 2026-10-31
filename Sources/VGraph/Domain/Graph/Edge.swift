public struct BaseEdge<V: Sendable>: VProtocol {
    public typealias Id = Identifier<Self>
    public typealias BaseNode = Identifier<V>

    public let id: Id
    public let from: BaseNode
    public let to: BaseNode

    public init(id: Id, from: BaseNode, to: BaseNode) {
        self.id = id
        self.from = from
        self.to = to
    }

    public init(id: String, from: BaseNode, to: BaseNode) {
        self.id = Id(string: id)
        self.from = from
        self.to = to
    }

    public init(string: String, from: String, to: String) {
        self.init(
            id: Id(string: string),
            from: Identifier<V>(rawValue: from),
            to: Identifier<V>(rawValue: to)
        )
    }

    public init(base: BaseEdge<V>, from: BaseNode? = nil, to: BaseNode? = nil) {
        self.id = base.id
        self.from = from ?? base.from
        self.to = to ?? base.to
    }
}

public typealias Edge = BaseEdge<_Node>
public typealias EdgeType = BaseEdge<_NodeType>

/// The description is prose lifted from the notation's own authoritative
/// documentation, not written here.
public struct EdgeTypeDefinition: Sendable {
    public let edgeType: EdgeType
    public let description: String

    public init(_ edgeType: EdgeType, description: String) {
        self.edgeType = edgeType
        self.description = description
    }
}

extension EdgeType {
    public static let unknownPrefix = "__UNKNOWN_EDGE_TYPE__"

    /// One engine display type per pair of node types.
    public static let derivedPrefix = "derived__"

    public var isDerived: Bool { id.id.hasPrefix(Self.derivedPrefix) }

    /// Minted by a [[Notation break]], never declared by the notation.
    public var isUnknown: Bool { id.id.hasPrefix(Self.unknownPrefix) }

    /// One unknown type per pair of node types, because an `EdgeType` carries
    /// its endpoints and `ensureEdgeTypeFits` enforces them — unlike
    /// `NodeType.unknown` and `GroupType.unknown`, which can be singletons
    /// precisely because they carry no relational information.
    ///
    /// **The id must lex as a VGL identifier.** It used to read
    /// `__UNKNOWN_EDGE_TYPE__:Concept->Relation`, and the exporter writes the
    /// type by name wherever a declared type also joins the pair — so the editor
    /// produced documents the parser then refused, which cost the whole diagram
    /// on reopening. The lexer reads alphanumerics plus `_`, `.` and `-` after
    /// the first character; `:` and `->` were never in that set (ADR-0024).
    public static func unknown(from: NodeType, to: NodeType) -> EdgeType {
        return EdgeType(
            id: "\(unknownPrefix)\(from.id)_to_\(to.id)",
            from: from,
            to: to
        )
    }
}

extension Attributes {

    public struct Edge {

        public enum StyleType: String, EnumAttributeType {
            case empty
            case dashed
            case dotted
            case solid
            case invis
            case bold
            case tapered
            case radial

            public var alias: String {
                guard self == .empty else {
                    return readableName
                }
                return ""
            }

            // Explicit per-case strings — no enum-case reflection under Embedded Swift.
            public var value: String {
                switch self {
                case .empty: return "empty"
                case .dashed: return "dashed"
                case .dotted: return "dotted"
                case .solid: return "solid"
                case .invis: return "invis"
                case .bold: return "bold"
                case .tapered: return "tapered"
                case .radial: return "radial"
                }
            }

            public var readableName: String { value }

            public static let typeName: String = "StyleType"
        }

        public static let label = TypedAttributeDefinition<String>(
            id: "edge.label",
            name: "Label on Edge",
            description: "A label, that will be displayed roughly at the middle of the edge",
            defaultValue: "",
            target: .edge
        )

        public static let url = TypedAttributeDefinition<String>(
            id: "edge.url",
            name: "URL",
            description: "A link this edge points at, opened by the openURL command",
            defaultValue: "",
            target: .edge
        )

        public static let color = TypedAttributeDefinition<VColor>(
            id: "edge.color",
            name: "Color",
            description: "The color of the edge",
            defaultValue: VColor.black,
            target: .edge
        )

        public static let arrowHead = TypedAttributeDefinition<String>(
            id: "edge.arrowhead",
            name: "Arrowhead",
            description: "The shape of the arrowhead at the end of the edge",
            defaultValue: "normal",
            target: .edge
        )

        public static let arrowTail = TypedAttributeDefinition<String>(
            id: "edge.arrowtail",
            name: "Arrowtail",
            description: "The shape of the arrowtail at the start of the edge",
            defaultValue: "normal",
            target: .edge
        )

        public static let headLabel = TypedAttributeDefinition<String>(
            id: "edge.headlabel",
            name: "Headlabel",
            description: "The label displayed at the head of the edge",
            defaultValue: "",
            target: .edge
        )

        /// What a chooser calls this relationship, when the notation leaves more
        /// than one and the gesture has to ask. The id is the fallback, which is
        /// why a notation only sets this where the id reads badly to someone
        /// meeting the notation for the first time.
        public static let menuTitle = TypedAttributeDefinition<String>(
            id: "edge.menutitle",
            name: "Menu title",
            description: "The label offered for this relationship in a chooser",
            defaultValue: "",
            target: .edge
        )

        public static let tailLabel = TypedAttributeDefinition<String>(
            id: "edge.taillabel",
            name: "Taillabel",
            description: "The label displayed at the tail of the edge",
            defaultValue: "",
            target: .edge
        )

        public static let fontname = TypedAttributeDefinition<String>(
            id: "edge.fontname",
            name: "Fontname",
            description: "The fontname used for the edge labels",
            defaultValue: "Helvetica",
            target: .edge
        )

        public static let penwidth = TypedAttributeDefinition<Double>(
            id: "edge.penwidth",
            name: "Penwidth",
            description: "The width of the pen used for drawing the edge",
            defaultValue: 1.0,
            target: .edge
        )

        public static let style = TypedAttributeDefinition<StyleType>(
            id: "edge.style",
            name: "Style",
            description: "The style of the edge",
            defaultValue: StyleType.solid,
            target: .edge
        )

        public static let dir = TypedAttributeDefinition<String>(
            id: "edge.dir",
            name: "Dir",
            description: "The direction of the edge",
            defaultValue: "forward",
            target: .edge
        )

        public static let weight = TypedAttributeDefinition<Double>(
            id: "edge.weight",
            name: "Weight",
            description: "The weight of the edge",
            defaultValue: 1.0,
            target: .edge
        )

        public static let constraint = TypedAttributeDefinition<Bool>(
            id: "edge.constraint",
            name: "Constraint",
            description: "The constraint of the edge",
            defaultValue: true,
            target: .edge
        )

        public static let layoutedPath = TypedAttributeDefinition<String>(
            id: "edge.layoutedPath",
            name: "Layouted Path",
            description: "The path computed by the layout engine (SVG path data or control points)",
            defaultValue: "",
            target: .edge
        )

        public static let layoutData = TypedAttributeDefinition<EdgeLayoutData>(
            id: "edge.layoutData",
            name: "Layout Data",
            description: "Complete layout data from layout engine (spline points, arrow heads, etc.)",
            defaultValue: EdgeLayoutData(splinePoints: []),
            target: .edge
        )

        public static let len = TypedAttributeDefinition<String>(
            id: "edge.len",
            name: "Preferred Edge Length",
            description: "Preferred length of edge in layout (for neato/fdp engines)",
            defaultValue: "",
            target: .edge
        )

        public static let labelangle = TypedAttributeDefinition<String>(
            id: "edge.labelangle",
            name: "Label Angle",
            description: "Angle in degrees for edge label placement",
            defaultValue: "",
            target: .edge
        )

        public static let labeldistance = TypedAttributeDefinition<String>(
            id: "edge.labeldistance",
            name: "Label Distance",
            description: "Distance scaling factor for edge label placement",
            defaultValue: "",
            target: .edge
        )

        // MARK: - Bounds (ADR-0011)
        //
        // Read from the *edge type*. Nothing stops one being written on an edge —
        // attribute lookup on an edge falls back to its type, so the storage is
        // shared — but `brokenBounds` reads the type, so an edge-level value
        // is inert. `Bound.unbounded` is the default; see there for why.

        public static let outDegreeMin = TypedAttributeDefinition<Int>(
            id: "edge.outDegreeMin",
            name: "outDegreeMin",
            description: "Fewest edges of this type that may leave one node of its source type",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let outDegreeMax = TypedAttributeDefinition<Int>(
            id: "edge.outDegreeMax",
            name: "outDegreeMax",
            description: "Most edges of this type that may leave one node of its source type",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let inDegreeMin = TypedAttributeDefinition<Int>(
            id: "edge.inDegreeMin",
            name: "inDegreeMin",
            description: "Fewest edges of this type that may enter one node of its target type",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let inDegreeMax = TypedAttributeDefinition<Int>(
            id: "edge.inDegreeMax",
            name: "inDegreeMax",
            description: "Most edges of this type that may enter one node of its target type",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let samePairMin = TypedAttributeDefinition<Int>(
            id: "edge.samePairMin",
            name: "samePairMin",
            description: "Fewest edges of this type between the same ordered pair of nodes",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let samePairMax = TypedAttributeDefinition<Int>(
            id: "edge.samePairMax",
            name: "samePairMax",
            description: "Most edges of this type between the same ordered pair of nodes",
            defaultValue: Bound.unbounded,
            target: .edge
        )

        public static let comment = TypedAttributeDefinition<String>(
            id: "edge.comment",
            name: "comment",
            description: "Comment lines standing above this edge in the source",
            defaultValue: "",
            target: .edge
        )

        public static let trailingComment = TypedAttributeDefinition<String>(
            id: "edge.trailingComment",
            name: "trailingComment",
            description: "Comment following this edge on the same line",
            defaultValue: "",
            target: .edge
        )

        public static let definitions = AttributeDefContainer([
            Edge.comment.asDefinition,
            Edge.trailingComment.asDefinition,
            Edge.outDegreeMin.asDefinition,
            Edge.outDegreeMax.asDefinition,
            Edge.inDegreeMin.asDefinition,
            Edge.inDegreeMax.asDefinition,
            Edge.samePairMin.asDefinition,
            Edge.samePairMax.asDefinition,
            Edge.label.asDefinition,
            Edge.url.asDefinition,
            Edge.menuTitle.asDefinition,
            Edge.foldedDescription.asDefinition,
            Edge.bundledEdges.asDefinition,
            Edge.bundleMembers.asDefinition,
            Edge.arrowHead.asDefinition,
            Edge.arrowTail.asDefinition,
            Edge.headLabel.asDefinition,
            Edge.tailLabel.asDefinition,
            Edge.fontname.asDefinition,
            Edge.penwidth.asDefinition,
            Edge.style.asDefinition,
            Edge.dir.asDefinition,
            Edge.weight.asDefinition,
            Edge.constraint.asDefinition,
            Edge.color.asDefinition,
            Edge.layoutedPath.asDefinition,
            Edge.layoutData.asDefinition,
            Edge.len.asDefinition,
            Edge.labelangle.asDefinition,
            Edge.labeldistance.asDefinition,
        ])
    }
}
