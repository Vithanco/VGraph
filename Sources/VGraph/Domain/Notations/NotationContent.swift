/// What a notation says: its types and the values on them. It knows no graph
/// and no layer; `VGraph.placing(_:in:)` decides where it goes (ADR-0030).
public struct NotationContent: Sendable {
    /// Attributes the notation brings beyond VGraph's own.
    public var definitions: AttributeDefContainer
    public var nodeTypes: [NodeType]
    public var edgeTypes: [EdgeType]
    public var groupTypes: [GroupType]
    public var detailings: [Detailing]
    /// In order: a later value for the same type and attribute wins.
    public var values: [TypeValues]

    public init(
        definitions: AttributeDefContainer = [:], nodeTypes: [NodeType] = [], edgeTypes: [EdgeType] = [],
        groupTypes: [GroupType] = [], detailings: [Detailing] = [], values: [TypeValues] = []
    ) {
        self.definitions = definitions
        self.nodeTypes = nodeTypes
        self.edgeTypes = edgeTypes
        self.groupTypes = groupTypes
        self.detailings = detailings
        self.values = values
    }

    /// The last value given for `id` on `key`, if any.
    public func value(of id: Attribute.Id, for key: ItemKey) -> String? {
        values.last { $0.key == key && $0.attributes.contains { $0.id == id } }?
            .attributes.last { $0.id == id }?.stringValue
    }
}

/// Values on one type, or on the diagram. Nothing else: elements are the model's.
public struct TypeValues: Sendable {
    public let key: ItemKey
    public let attributes: [Attribute]

    private init(_ key: ItemKey, _ attributes: [Attribute]) {
        self.key = key
        self.attributes = attributes
    }

    public static func nodeType(_ type: NodeType, _ attributes: [Attribute]) -> TypeValues {
        TypeValues(ItemKey(.nodeType, type.description), attributes)
    }

    public static func edgeType(_ type: EdgeType.Id, _ attributes: [Attribute]) -> TypeValues {
        TypeValues(ItemKey(.edgeType, type.description), attributes)
    }

    public static func edgeType(_ type: EdgeType, _ attributes: [Attribute]) -> TypeValues {
        edgeType(type.id, attributes)
    }

    public static func groupType(_ type: GroupType, _ attributes: [Attribute]) -> TypeValues {
        TypeValues(ItemKey(.groupType, type.description), attributes)
    }

    public static func diagram(_ attributes: [Attribute]) -> TypeValues {
        TypeValues(.root, attributes)
    }
}

extension TypeValues {
    /// A node type drawn by a preset layout, in DM Sans.
    public static func preset(
        _ type: NodeType, _ layout: NodeStyleLayout, fontsize: Double = 13, badgeTypeName: String? = nil
    ) -> TypeValues {
        .nodeType(
            type,
            [
                Attributes.Node.nodeStyle(.presetLayout),
                Attributes.Node.style(layout),
                Attributes.Node.fontsize(fontsize),
                Attributes.Node.fontname(.dmSans),
            ]
                + (badgeTypeName.map { [Attributes.Node.minWidth(NodeStyleConstants.iconBadgeMinWidth(typeLabel: $0))] } ?? [])
        )
    }

    /// The accent strip with a node type badge most notations draw their types as,
    /// never narrower than its type name.
    public static func badge(
        _ type: NodeType, _ typeName: String, icon: String, fill: SemanticColor, border: SemanticColor,
        text: SemanticColor
    ) -> TypeValues {
        .nodeType(
            type,
            [
                Attributes.Node.nodeStyle(.presetLayout),
                Attributes.Node.style(
                    .iconAccentStrip(backgroundColor: fill, borderColor: border, textColor: text, icon: icon, typeName: typeName)),
                Attributes.Node.fontsize(13),
                Attributes.Node.fontname(.dmSans),
                Attributes.Node.minWidth(NodeStyleConstants.iconBadgeMinWidth(typeLabel: typeName)),
            ])
    }

    /// The accent strip alone, for the only node type of a notation: no badge, since
    /// there is no other type for it to be told apart from.
    public static func strip(
        _ type: NodeType, fill: SemanticColor, border: SemanticColor, text: SemanticColor
    ) -> TypeValues {
        .nodeType(
            type,
            [
                Attributes.Node.nodeStyle(.presetLayout),
                Attributes.Node.style(.accentStrip(backgroundColor: fill, borderColor: border, textColor: text)),
                Attributes.Node.fontsize(13),
                Attributes.Node.fontname(.dmSans),
            ])
    }

    /// Drawn as a black icon alone.
    public static func icon(_ type: NodeType, _ iconName: String) -> TypeValues {
        .nodeType(type, iconAlone(iconName))
    }

    /// An AND or OR junctor, drawn as its icon alone.
    public static func junctor(_ type: NodeType, _ iconName: String) -> TypeValues {
        .nodeType(type, [Attributes.Node.isJunctor(true)] + iconAlone(iconName))
    }

    private static func iconAlone(_ iconName: String) -> [Attribute] {
        [
            Attributes.Node.nodeStyle(.iconOnly),
            Attributes.Node.iconInfo(
                IconInfo(
                    iconPosition: .center, iconName: iconName,
                    iconColor: SemanticColor.junctor.resolve(darkMode: false), iconSize: 28)),
        ]
    }
}
