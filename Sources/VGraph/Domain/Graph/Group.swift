public struct Group: VProtocol, UseIdentifier {
    public let id: Identifier<Group>

    public init(rawValue: String) {
        id = Identifier(rawValue: rawValue)
    }
}

public let rootGroup = "vithanco.vgraph.rootGroup.only.for.internal.use"

public enum FoldingState: EnumAttributeType {
    case normal
    case folded
    case hidden
    public var description: String {
        switch self {
        case .normal: return "normal"
        case .folded: return "folded"
        case .hidden: return "hidden"
        }
    }

    public var contentVisible: Bool {
        return self == .normal
    }

    public var readableName: String {
        switch self {
        case .normal: return "normal"
        case .folded: return "folded"
        case .hidden: return "hidden"
        }
    }

    public var toolTip: String {
        switch self {
        case .normal: return "Visible and Unfolded"
        case .folded: return "Visible and Folded"
        case .hidden: return "Hidden within another folded cluster"
        }
    }

    public var value: String { readableName }

    public static let typeName: String = "FoldingState"
}

public enum LayoutDirection: EnumAttributeType {
    case topToBottom
    case leftToRight
    case bottomToTop
    case rightToLeft

    public static var typeName: String {
        return "LayoutDirection"
    }

    public var readableName: String {
        switch self {
        case .topToBottom: return "Top to Bottom"
        case .leftToRight: return "Left to Right"
        case .bottomToTop: return "Bottom to Top"
        case .rightToLeft: return "Right to Left"
        }
    }

    public var value: String {
        switch self {
        case .topToBottom: return "topToBottom"
        case .leftToRight: return "leftToRight"
        case .bottomToTop: return "bottomToTop"
        case .rightToLeft: return "rightToLeft"
        }
    }

    public var toolTip: String {
        switch self {
        case .topToBottom: return "Layout nodes from top to bottom"
        case .leftToRight: return "Layout nodes from left to right"
        case .bottomToTop: return "Layout nodes from bottom to top"
        case .rightToLeft: return "Layout nodes from right to left"
        }
    }

}

public enum RatioType: EnumAttributeType {
    case numeric(Double)
    case fill
    case compress
    case expand
    case auto

    public static var typeName: String {
        return "Ratio"
    }

    public static var allCases: [RatioType] {
        return [.fill, .compress, .expand, .auto, .numeric(0.0)]  // `numeric` isn't a fixed value case
    }

    public static var readableNames: [String] {
        return allCases.map { $0.readableName }
    }

    public var readableName: String {
        switch self {
        case .numeric(let value):
            return "Numeric (\(value))"
        case .fill:
            return "Fill"
        case .compress:
            return "Compress"
        case .expand:
            return "Expand"
        case .auto:
            return "Auto"
        }
    }

    public static func fromString(_ string: String) throws(VError) -> RatioType {
        switch string.lowercased() {
        case "fill":
            return .fill
        case "compress":
            return .compress
        case "expand":
            return .expand
        case "auto":
            return .auto
        default:
            guard let doubleValue = try? Double.fromString(string) else {
                throw VError.stringToEnumFailure(attributeValue: string, attributeType: Self.typeName)
            }
            return .numeric(doubleValue)
        }
    }

    public var asString: String {
        switch self {
        case .numeric(let value):
            return "\(value)"
        case .fill:
            return "fill"
        case .compress:
            return "compress"
        case .expand:
            return "expand"
        case .auto:
            return "auto"
        }
    }

    public var value: String {
        switch self {
        case .numeric: return "numeric"
        case .fill: return "fill"
        case .compress: return "compress"
        case .expand: return "expand"
        case .auto: return "auto"
        }
    }
}

public enum GraphStyleType: EnumAttributeType {
    case none
    case filled
    case striped
    case rounded

    public var value: String {
        switch self {
        case .none: return "none"
        case .filled: return "filled"
        case .striped: return "striped"
        case .rounded: return "rounded"
        }
    }

    public var readableName: String { value }

    public static let typeName: String = "GraphStyleType"
}

extension Attributes {
    public struct Group {

        public enum StyleType: EnumAttributeType {
            case empty
            case filled
            case striped
            case rounded
            case radial

            public var alias: String {
                guard self == .empty else {
                    return readableName
                }
                return ""
            }

            public var value: String {
                switch self {
                case .empty: return "empty"
                case .filled: return "filled"
                case .striped: return "striped"
                case .rounded: return "rounded"
                case .radial: return "radial"
                }
            }

            public var readableName: String { value }

            public static let typeName: String = "StyleType"
        }

        public enum Labeljust: EnumAttributeType {
            case r
            case l
            case c

            public var alias: String {
                guard self == .c else {
                    return readableName
                }
                return ""
            }

            // Explicit per-case strings — no enum-case reflection under Embedded Swift.
            public var value: String {
                switch self {
                case .r: return "r"
                case .l: return "l"
                case .c: return "c"
                }
            }

            public var readableName: String { value }

            public static let typeName: String = "Labeljust"
        }

        public static let isFolded = TypedAttributeDefinition<Bool>(
            id: "group.isFolded",
            name: "isFolded",
            description: "Is this subgraph Folded?",
            defaultValue: false,
            target: .graph
        )

        public static let label = TypedAttributeDefinition<String>(
            id: "group.label",
            name: "labeltext",
            description: "Name/Label of the Group of Nodes (only visible if \"Render Group Together\" is true",
            defaultValue: "",
            target: .graph
        )

        public static let url = TypedAttributeDefinition<String>(
            id: "group.url",
            name: "URL",
            description: "A link this group points at, opened by the openURL command",
            defaultValue: "",
            target: .graph
        )

        public static let Id = TypedAttributeDefinition<String>(
            id: "group.id",
            name: "Id",
            description: "Id of the Group",
            defaultValue: "",
            target: .graph
        )

        public static let fontname = TypedAttributeDefinition<FontFamily>(
            id: "group.fontname",
            name: "fontname",
            description: "Font family for the Group's label",
            // A graph title is a Group label, so this default decides what the
            // title is set in — and `.helvetica` made every diagram mix two
            // typefaces, the title in one and every node label in the other.
            defaultValue: .default,
            target: .graph
        )

        public static let fontsize = TypedAttributeDefinition<Double>(
            id: "group.fontSize",
            name: "fontSize",
            description: "Font size of the Group's label",
            defaultValue: 14.0,
            target: .graph
        )

        public static let labelocation = TypedAttributeDefinition<String>(
            id: "group.labelLocation",
            name: "labelLocation",
            description: "Location of the Group's label",
            defaultValue: "c",
            target: .graph
        )

        public static let splines = TypedAttributeDefinition<String>(
            id: "group.splines",
            name: "splines",
            description: "Line type within this Group",
            defaultValue: "splines",
            target: .graph
        )

        public static let ratio = TypedAttributeDefinition<RatioType>(
            id: "group.ratio",
            name: "ratio",
            description: """
                    Sets the aspect ratio (drawing height/drawing width) for the drawing.
                    This can take either numeric values or specific string values to control layout scaling:
                    - **Numeric**: Interpreted as the desired aspect ratio. The height or width of the drawing is scaled to achieve this ratio before applying size constraints.
                    - **"fill"**: If the size attribute is set, nodes are scaled to fill the size, preserving the aspect ratio.
                    - **"compress"**: Dot attempts to compact the layout to fit within the size, focusing less on symmetry and balance.
                    - **"expand"**: Expands the drawing until it fits at least one dimension of the size, before applying edge generation.
                    - **"auto"**: Used with the page attribute in dot mode if the graph spans multiple pages, finding an optimal size.

                    Node sizes may be ignored in some calculations, so the resulting drawing may approximate the desired dimensions.
                """,
            defaultValue: RatioType.numeric(1.0),
            target: .graph
        )

        public static let fontcolor = TypedAttributeDefinition<VColor>(
            id: "group.fontColor",
            name: "fontColor",
            description: "Font color of the Groups label",
            defaultValue: VColor(hexString: "#505048") ?? VColor.black,
            target: .graph
        )

        public static let border = TypedAttributeDefinition<Double>(
            id: "group.border",
            name: "border",
            description: "Border thickness of the Group (if \"Render Group Together\" is enabled)",
            defaultValue: 0.0,
            target: .graph
        )

        public static let layoutDirection = TypedAttributeDefinition<LayoutDirection>(
            id: "group.layoutDirection",
            name: "Layout Direction",
            description: "Direction of graph layout (top-to-bottom, left-to-right, etc.)",
            defaultValue: LayoutDirection.topToBottom,
            target: .graph
        )

        public static let layoutEngine = TypedAttributeDefinition<String>(
            id: "graph.layoutEngine",
            name: "Layout Engine",
            description: "Layout engine to use (dot, neato, fdp, circo, twopi, etc.)",
            defaultValue: "dot",
            target: .graph
        )

        public static let style = TypedAttributeDefinition<StyleType>(
            id: "group.style",
            name: "style",
            description: "Style of the Group",
            defaultValue: StyleType.empty,
            target: .graph
        )

        public static let groupStyle = TypedAttributeDefinition<GroupStyle>(
            id: "group.groupStyle",
            name: "groupStyle",
            description: "The style of a group: its folded (collapsed box) and unfolded (boundary) appearance.",
            defaultValue: GroupStyle.default,
            target: .graph
        )

        /// The boundary an unfolded group draws, declared on its node type
        /// (ADR-0032) or, for a plain group, on its group type, where it beats the
        /// `groupStyle` face.
        public static let boundaryChrome = TypedAttributeDefinition<BoundaryChrome>(
            id: "group.boundaryChrome",
            name: "boundaryChrome",
            description: "The boundary an unfolded detailed node draws around its details.",
            defaultValue: BoundaryChrome.default,
            target: .graph
        )

        /// A node type enumerates itself, being structural; a group type is only a
        /// styling tag, so its registry is data like the rest of it (ADR-0020).
        public static let labeljust = TypedAttributeDefinition<Labeljust>(
            id: "group.labeljust",
            name: "labeljust",
            description: "Justification of the Groupøs label",
            defaultValue: Labeljust.c,
            target: .graph
        )

        public static let maxNodeWidth = TypedAttributeDefinition<Double>(
            id: "graph.maxNodeWidth",
            name: "Maximum Node Width",
            description: "Maximum width in pixels for node text wrapping. Text will wrap to fit within this width.",
            defaultValue: 150.0,
            target: .graph
        )

        public static let completedSteps = TypedAttributeDefinition<[String]>(
            id: "graph.completedSteps",
            name: "Completed Steps",
            description: "Ids of the transform steps that have run on this graph. Runtime-only pipeline bookkeeping.",
            defaultValue: [],
            target: .graph
        )

        /// The model's loops, recorded before any display transform so they can be
        /// drawn on the display graph (ADR-0027). Runtime-only, like `completedSteps`.
        public static let recordedLoops = TypedAttributeDefinition<String>(
            id: "graph.recordedLoops",
            name: "Recorded Loops",
            description: "The OriginGraph's loops as edge ids with their polarity. Runtime-only pipeline bookkeeping.",
            defaultValue: "",
            target: .graph
        )

        public static let diagramLogic = TypedAttributeDefinition<DiagramLogic>(
            id: "graph.diagramLogic",
            name: "Diagram Logic",
            description: "The logical reasoning type of the diagram (e.g., sufficient cause, necessary condition)",
            defaultValue: DiagramLogic.noLogic,
            target: .graph
        )

        public static let labelLayoutedPos = TypedAttributeDefinition<VPoint>(
            id: "group.labelLayoutedPos",
            name: "Label Layouted Position",
            description: "The position of the group label as computed by the layout engine",
            defaultValue: VPoint.zero,
            target: .graph
        )

        public static let labelLayoutedSize = TypedAttributeDefinition<VSize>(
            id: "group.labelLayoutedSize",
            name: "Label Layouted Size",
            description: "The size of the group label as computed by the layout engine",
            defaultValue: VSize.zero,
            target: .graph
        )

        public static let layoutedBounds = TypedAttributeDefinition<VRect>(
            id: "group.layoutedBounds",
            name: "Layouted Bounds",
            description: "The bounding box of the group as computed by the layout engine",
            defaultValue: VRect.zero,
            target: .graph
        )

        public static let borderWidth = TypedAttributeDefinition<Double>(
            id: "group.borderWidth",
            name: "Border Width",
            description: "Width of the group border in pixels",
            defaultValue: 1.5,
            target: .graph
        )

        public static let borderColor = TypedAttributeDefinition<VColor>(
            id: "group.borderColor",
            name: "Border Color",
            description: "Color of the group border",
            defaultValue: VColor(hexString: SemanticColor.groupBorder.lightHex) ?? VColor.gray,
            target: .graph
        )

        public static let backgroundColor = TypedAttributeDefinition<VColor>(
            id: "group.backgroundColor",
            name: "Background Color",
            description: "Background color of the group (semi-transparent for stacking)",
            defaultValue: VColor(hexString: SemanticColor.groupFill.lightHex) ?? VColor.white,
            target: .graph
        )

        public static let borderDash = TypedAttributeDefinition<String>(
            id: "group.borderDash",
            name: "Border Dash",
            description: "SVG stroke-dasharray for the group border (empty = solid)",
            defaultValue: "6,3",
            target: .graph
        )

        public static let cornerRadius = TypedAttributeDefinition<Double>(
            id: "group.cornerRadius",
            name: "Corner Radius",
            description: "Corner radius for the rounded rectangle border",
            defaultValue: 8.0,
            target: .graph
        )

        public static let watermark = TypedAttributeDefinition<Bool>(
            id: "group.watermark",
            name: "Watermark",
            description: "Whether to show the Vithanco watermark on the exported image",
            defaultValue: true,
            target: .graph
        )

        public static let overlap = TypedAttributeDefinition<String>(
            id: "graph.overlap",
            name: "Overlap",
            description: "How to handle node overlap (for neato/fdp): scale, false, scalexy, etc.",
            defaultValue: "",
            target: .graph
        )

        public static let sep = TypedAttributeDefinition<String>(
            id: "graph.sep",
            name: "Node Separation",
            description: "Minimum separation between nodes (for neato/fdp). Use +value to add to default.",
            defaultValue: "",
            target: .graph
        )

        /// Holds the comments of a group *and* of the graph itself — both are
        /// `.graph`-target attributes, the graph's living on the root group.
        public static let comment = TypedAttributeDefinition<String>(
            id: "group.comment",
            name: "comment",
            description: "Comment lines standing above this group or graph in the source",
            defaultValue: "",
            target: .graph
        )

        public static let trailingComment = TypedAttributeDefinition<String>(
            id: "group.trailingComment",
            name: "trailingComment",
            description: "Comment following this group's or graph's opening line",
            defaultValue: "",
            target: .graph
        )

        public static let definitions = AttributeDefContainer([
            Group.comment.asDefinition,
            Group.trailingComment.asDefinition,
            Group.border.asDefinition,
            Group.style.asDefinition,
            Group.groupStyle.asDefinition,
            Group.boundaryChrome.asDefinition,
            Group.fontcolor.asDefinition,
            Group.fontname.asDefinition,
            Group.fontsize.asDefinition,
            Group.isFolded.asDefinition,
            Group.label.asDefinition,
            Group.Id.asDefinition,
            Group.completedSteps.asDefinition,
            Group.recordedLoops.asDefinition,
            Group.url.asDefinition,
            Group.labelocation.asDefinition,
            Group.ratio.asDefinition,
            Group.splines.asDefinition,
            Group.layoutDirection.asDefinition,
            Group.loopMarkers.asDefinition,
            Group.derivedEdges.asDefinition,
            Group.layoutEngine.asDefinition,
            Group.labeljust.asDefinition,
            Group.maxNodeWidth.asDefinition,
            Group.splines.asDefinition,
            Group.diagramLogic.asDefinition,
            Group.labelLayoutedPos.asDefinition,
            Group.labelLayoutedSize.asDefinition,
            Group.layoutedBounds.asDefinition,
            Group.borderWidth.asDefinition,
            Group.borderColor.asDefinition,
            Group.borderDash.asDefinition,
            Group.backgroundColor.asDefinition,
            Group.cornerRadius.asDefinition,
            Group.watermark.asDefinition,
            Group.overlap.asDefinition,
            Group.sep.asDefinition,
        ])
    }
}

extension Group {
    public func isFolded<GA: GetAttribute>(in graph: GA) -> Bool {
        if let value = try? graph.get(group: self, attribute: Attributes.Group.isFolded) {
            return value
        }
        return Attributes.Group.isFolded.defaultValue
    }

    public func getName(in graph: VGraph) -> String {
        graph.label(of: .group(self)) ?? ""
    }
}

extension VGraph {
    public func isVisible(node: Node) -> Bool {
        if let group = groupStructure.group(of: node) {
            let foldingState = foldingState(group: group)
            return foldingState == .normal
        }
        return true
    }

    public func getVisibleNode(for node: Node) -> Node? {
        if let group = group(of: node) {
            let foldingState = foldingState(group: group)
            if foldingState == .normal {
                return node
            }
            var visibleGroup = group
            while self.foldingState(group: visibleGroup) != FoldingState.folded {
                guard let parent = parentGroup(of: visibleGroup) else {
                    return Node(visibleGroup)
                }
                visibleGroup = parent
            }
            return Node(visibleGroup)
        }
        return node
    }

    public func foldingState(group: Group) -> FoldingState {
        if let parent = groupStructure.parentGroup(of: group) {
            let parentFoldingState = foldingState(group: parent)
            if parentFoldingState != .normal {
                return .hidden
            }
        }
        let myFoldingState = group.isFolded(in: self)
        if myFoldingState {
            return .folded
        }
        return .normal
    }

    public func group(of node: Node) -> Group? {
        return groupStructure.group(of: node)
    }

    /// The innermost group holding *both* ends. Derived, never stored: VGL can
    /// only place an edge by where its nodes are, so a membership of its own
    /// would not survive an export — and would go stale the moment an end moved.
    public func group(of edge: Edge.Id) -> Group? {
        guard let edge = get(edge: edge) else { return nil }
        let fromAncestry = Set(groupAncestry(of: edge.from))
        return groupAncestry(of: edge.to).first { fromAncestry.contains($0) }
    }

    /// Innermost first, up to and including the root group.
    private func groupAncestry(of node: Node) -> [Group] {
        var result: [Group] = []
        var current = groupStructure.group(of: node)
        while let group = current {
            result.append(group)
            current = groupStructure.parentGroup(of: group)
        }
        return result
    }

    public func parentGroup(of group: Group) -> Group? {
        return groupStructure.parentGroup(of: group)
    }

    public var groupsOrderedByOwnership: [Group] {
        return groups.sorted { lhs, rhs in
            if groupStructure.isParent(parent: lhs, child: rhs) {
                return true
            }
            if groupStructure.isParent(parent: rhs, child: lhs) {
                return false
            }
            return true
        }
    }

    public func getFont(forGroup group: Group) -> VFont {
        var fontSize: Double = 14.0
        // Second copy of the default, which is how it drifted from the
        // attribute's the first time. Read it from the definition instead.
        var fontFamily: FontFamily = Attributes.Group.fontname.defaultValue

        if let size = try? get(group: group, attribute: Attributes.Group.fontsize) {
            fontSize = size
        }

        if let family = try? get(group: group, attribute: Attributes.Group.fontname) {
            fontFamily = family
        }

        return VFont(family: fontFamily, size: fontSize)
    }
}
