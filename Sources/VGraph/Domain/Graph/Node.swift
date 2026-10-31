public struct _Node: VProtocol, Sendable {}
public typealias Node = Identifier<_Node>

public struct _NodeType: VProtocol, Sendable {}
public typealias NodeType = Identifier<_NodeType>

/// The description is prose lifted from the notation's own authoritative
/// documentation, not written here.
public struct NodeTypeDefinition: Sendable {
    public let nodeType: NodeType
    public let description: String
    /// The types this type's nodes are detailed by (ADR-0032).
    public let detailedBy: [NodeType]

    public init(_ nodeType: NodeType, description: String, detailedBy: [NodeType] = []) {
        self.nodeType = nodeType
        self.description = description
        self.detailedBy = detailedBy
    }
}

extension NodeType {
    public static let unknownPrefix = "__UNKNOWN_NODE_TYPE__"
    public static let unknown = NodeType(string: unknownPrefix)
}

extension Identifier where Value == _Node {
    public init(_ group: Group) {
        self.init(string: group.id.description)
    }
}

extension Attributes {

    public struct Node {

        /// What a node the editor creates is labelled until the author types.
        /// Not the label's default: an absent label means the node's id to the
        /// parser, and a default is dropped as redundant (ADR-0030).
        public static let placeholderLabel = "Change Me"

        public static let label = TypedAttributeDefinition<String>(
            id: "node.label",
            name: "Label",
            description: "The visible Text of the Node",
            defaultValue: "",
            target: .node
        )

        public static let style = TypedAttributeDefinition<NodeStyleLayout>(
            id: "node.style",
            name: "Style",
            description: "The computed style layout of a node, assembled from nodeStyle + iconInfo + backgroundColor + category",
            defaultValue: NodeStyleLayout.empty,
            target: .node
        )

        public static let nodeStyle = TypedAttributeDefinition<NodeStyle>(
            id: "node.nodeStyle",
            name: "nodeStyle",
            description: "The predefined style template for this node type",
            defaultValue: .bareText,
            target: .node
        )

        public static let iconInfo = TypedAttributeDefinition<IconInfo>(
            id: "node.iconInfo",
            name: "iconInfo",
            description: "Icon configuration for the node",
            defaultValue: IconInfo(iconPosition: .none, iconName: "", iconColor: .black, iconSize: 0),
            target: .node
        )

        public static let backgroundColor = TypedAttributeDefinition<VColor>(
            id: "node.backgroundColor",
            name: "backgroundColor",
            description: "Background color used by the node style",
            defaultValue: .white,
            target: .node
        )

        /// Overridable because derived contrast only ever yields black or white,
        /// and C4's own cards are set in `#111111`.
        public static let fontColor = TypedAttributeDefinition<VColor>(
            id: "node.fontColor",
            name: "fontColor",
            description: "Text color used by the node style; derived from the background when unset",
            defaultValue: .clear,
            target: .node
        )

        public static let category = TypedAttributeDefinition<String>(
            id: "node.category",
            name: "category",
            description: "Category header text for category-style nodes",
            defaultValue: "",
            target: .node
        )

        public static let margin = TypedAttributeDefinition<String>(
            id: "node.margin",
            name: "Margin",
            description: "Specifies space left around the node's label",
            defaultValue: "0.11,0.055",
            target: .node
        )

        public static let tooltip = TypedAttributeDefinition<String>(
            id: "node.tooltip",
            name: "Tooltip",
            description: "The tooltip of a node",
            defaultValue: "",
            target: .node
        )

        public static let url = TypedAttributeDefinition<String>(
            id: "node.url",
            name: "URL",
            description: "A link this node points at, opened by the openURL command",
            defaultValue: "",
            target: .node
        )

        public static let isJunctor = TypedAttributeDefinition<Bool>(
            id: "vithanco.node.isJunctor",
            name: "Is Junctor",
            description:
                "True when this node type is a logical AND/OR junctor, not a real node; consumers may treat it as a transparent pass-through",
            defaultValue: false,
            target: .node
        )

        public static let position = TypedAttributeDefinition<String>(
            id: "node.position",
            name: "Position of the node",
            description: "The position of a node",
            defaultValue: "",
            target: .node
        )

        public static let minWidth = TypedAttributeDefinition<Double>(
            id: "node.minWidth",
            name: "Minimum Width",
            description: "Minimum node width in points; the layout engine will not shrink below this value",
            defaultValue: 0.0,
            target: .node
        )

        public static let width = TypedAttributeDefinition<Double>(
            id: "node.width",
            name: "Width of the node",
            description: "The width of a node, in pixels",
            defaultValue: 0.75,
            target: .node
        )

        public static let height = TypedAttributeDefinition<Double>(
            id: "node.height",
            name: "Height of the node",
            description: "The height of a node, in pixels",
            defaultValue: 0.5,
            target: .node
        )

        public static let fixedsize = TypedAttributeDefinition<Bool>(
            id: "node.fixedsize",
            name: "Fixed Size",
            description: "When true, the node size is fixed to the specified width and height",
            defaultValue: false,
            target: .node
        )

        public static let fontname = TypedAttributeDefinition<FontFamily>(
            id: "node.fontname",
            name: "Fontname",
            description: "The Fontname of a node",
            defaultValue: .default,
            target: .node
        )

        public static let fontsize = TypedAttributeDefinition<Double>(
            id: "node.fontsize",
            name: "Fontsize",
            description: "The size of a node text",
            defaultValue: 11.0,
            target: .node
        )

        public static let orderNumber: TypedAttributeDefinition<Int> = .init(
            id: "vithanco.node.orderNumber",
            name: "Node Order Number",
            description: "The order number of a node",
            defaultValue: 0,
            target: .node
        )

        public static let layoutedPos = TypedAttributeDefinition<VPoint>(
            id: "node.layoutedPos",
            name: "Layouted Position",
            description: "The position computed by the layout engine",
            defaultValue: VPoint(x: 0, y: 0),
            target: .node
        )

        public static let layoutedSize = TypedAttributeDefinition<VSize>(
            id: "node.layoutedSize",
            name: "Layouted Size",
            description: "The size computed by the layout engine",
            defaultValue: VSize(width: 0, height: 0),
            target: .node
        )

        public static let wrappedText = TypedAttributeDefinition<[String]>(
            id: "node.wrappedText",
            name: "Wrapped Text",
            description: "The node label text split into lines for display",
            defaultValue: [],
            target: .node
        )

        public static let nodeTextSize = TypedAttributeDefinition<VSize>(
            id: "node.nodeTextSize",
            name: "Node Text Size",
            description: "The size of the text within the node",
            defaultValue: VSize.zero,
            target: .node
        )

        public static let shape = TypedAttributeDefinition<NodeShape>(
            id: "node.shape",
            name: "Shape",
            description: "The shape of the node",
            defaultValue: .box,
            target: .node
        )

        public static let alignGroup = TypedAttributeDefinition<String>(
            id: "node.alignGroup",
            name: "alignGroup",
            description: "Alignment group. Nodes with the same alignGroup value are placed at the same rank in layout.",
            defaultValue: "",
            target: .node
        )

        public static let foldedNodeCount = TypedAttributeDefinition<Int>(
            id: "node.foldedNodeCount",
            name: "foldedNodeCount",
            description: "Number of nodes inside the group this node represents (set when a group is folded).",
            defaultValue: 0,
            target: .node
        )

        /// Whether a node stands for a folded group is a fact only the fold step
        /// knows: a folded detailed node's type says what it is, not that.
        public static let standsForGroup = TypedAttributeDefinition<Bool>(
            id: "node.standsForGroup",
            name: "standsForGroup",
            description: "Set on the node a folded group is drawn as.",
            defaultValue: false,
            target: .node
        )

        /// Newline-joined `//` lines, written back as `//` lines — see ADR-0010.
        public static let comment = TypedAttributeDefinition<String>(
            id: "node.comment",
            name: "comment",
            description: "Comment lines standing above this node in the source",
            defaultValue: "",
            target: .node
        )

        public static let trailingComment = TypedAttributeDefinition<String>(
            id: "node.trailingComment",
            name: "trailingComment",
            description: "Comment following this node on the same line",
            defaultValue: "",
            target: .node
        )

        // MARK: - Degree bounds (ADR-0011)
        //
        // Aggregating across every edge type — the one thing an edge-type bound
        // cannot say ("at least one edge of any kind"). `out`/`in` rather than the
        // edge types' `source`/`target`: here the node is the subject.

        public static let totalOutDegreeMin = TypedAttributeDefinition<Int>(
            id: "node.totalOutDegreeMin",
            name: "totalOutDegreeMin",
            description: "Fewest edges of any type that may leave a node of this type",
            defaultValue: Bound.unbounded,
            target: .node
        )

        public static let totalOutDegreeMax = TypedAttributeDefinition<Int>(
            id: "node.totalOutDegreeMax",
            name: "totalOutDegreeMax",
            description: "Most edges of any type that may leave a node of this type",
            defaultValue: Bound.unbounded,
            target: .node
        )

        public static let totalInDegreeMin = TypedAttributeDefinition<Int>(
            id: "node.totalInDegreeMin",
            name: "totalInDegreeMin",
            description: "Fewest edges of any type that may enter a node of this type",
            defaultValue: Bound.unbounded,
            target: .node
        )

        public static let totalInDegreeMax = TypedAttributeDefinition<Int>(
            id: "node.totalInDegreeMax",
            name: "totalInDegreeMax",
            description: "Most edges of any type that may enter a node of this type",
            defaultValue: Bound.unbounded,
            target: .node
        )

        public static let definitions = AttributeDefContainer([
            Node.totalOutDegreeMin.asDefinition,
            Node.totalOutDegreeMax.asDefinition,
            Node.totalInDegreeMin.asDefinition,
            Node.totalInDegreeMax.asDefinition,
            Node.label.asDefinition,
            Node.style.asDefinition,
            Node.margin.asDefinition,
            Node.tooltip.asDefinition,
            Node.url.asDefinition,
            Node.position.asDefinition,
            Node.width.asDefinition,
            Node.height.asDefinition,
            Node.fixedsize.asDefinition,
            Node.fontname.asDefinition,
            Node.fontsize.asDefinition,
            Node.layoutedPos.asDefinition,
            Node.layoutedSize.asDefinition,
            Node.wrappedText.asDefinition,
            Node.nodeTextSize.asDefinition,
            Node.shape.asDefinition,
            Node.isJunctor.asDefinition,
            Node.minWidth.asDefinition,
            Node.alignGroup.asDefinition,
            Node.foldedNodeCount.asDefinition,
            Node.standsForGroup.asDefinition,
            Node.nodeStyle.asDefinition,
            Node.iconInfo.asDefinition,
            Node.backgroundColor.asDefinition,
            Node.category.asDefinition,
            Node.fontColor.asDefinition,
            Node.comment.asDefinition,
            Node.trailingComment.asDefinition,
        ])
    }
}

extension VGraph {
    public func getFont(forNode node: Node) -> VFont {

        var font: VFont = .default
        if let fontSize = try? get(node: node, attribute: Attributes.Node.fontsize),
            let fontFamily = try? get(node: node, attribute: Attributes.Node.fontname)
        {
            font = VFont(family: fontFamily, size: fontSize)
        }

        return font
    }

    public func setFont(_ font: VFont, forNode node: Node) throws(VError) -> Self {
        let result = try set(node: node, attribute: Attributes.Node.fontname.attribute(font.family))
        return try result.set(node: node, attribute: Attributes.Node.fontsize.attribute(font.size))
    }
}
