// Colours are `SemanticColor` tokens, resolved only when the SVG is written,
// because only then is `darkMode` known.

extension NodeStyleLayout {

    public static func withCategory(category: String, categoryColor: SemanticColor) -> NodeStyleLayout {
        return framedBox(
            fill: .white, border: .black,
            content: .vertical(
                [
                    categoryBar(category, color: categoryColor),
                    .padded(
                        NodeStyleConstants.belowCategoryInsets,

                        .nodeText(color: .labelText)
                    ),

                ],
                spacing: 0
            ))
    }

    public static func simpleRoundedBox(color: SemanticColor) -> NodeStyleLayout {
        return .background(
            .solid(shape: .box, color: color),
            .padded(
                NodeStyleConstants.roundedBoxInsets,
                .frame(
                    cornerRadius: NodeStyleConstants.cornerRadius,
                    borderWidth: NodeStyleConstants.borderWidth,
                    borderColor: borderShade(of: color)
                )
            )
        )
    }

    public static var bareText: NodeStyleLayout {
        return .background(
            .solid(shape: .box, color: .white),
            .nodeText(color: .black)
        )
    }

    public static func simpleRoundedText(color: SemanticColor) -> NodeStyleLayout {
        return framedBox(
            fill: color, border: borderShade(of: color),
            content: .padded(
                NodeStyleConstants.roundedBoxInsets,
                .nodeText(color: .black)
            ))
    }

    public static func iconWithText(backgroundColor: SemanticColor, icon: IconInfo)
        -> NodeStyleLayout
    {
        return framedBox(
            fill: backgroundColor, border: borderShade(of: backgroundColor),
            content: .padded(
                VEdgeInsets(regular: 3),
                .horizontal(
                    [
                        .icon(icon),
                        .nodeText(color: backgroundColor.bwContrastColor),
                    ],
                    spacing: NodeStyleConstants.separation
                )
            ))
    }

    public static func withCategoryAndIcon(category: String, categoryColor: SemanticColor, icon: IconInfo)
        -> NodeStyleLayout
    {
        return framedBox(
            fill: .white, border: .black,
            content: .vertical(
                [
                    categoryBar(category, color: categoryColor),
                    .padded(
                        NodeStyleConstants.belowCategoryInsets,
                        .horizontal(
                            [
                                .icon(icon),
                                .nodeText(color: .labelText),
                            ],
                            spacing: NodeStyleConstants.separation
                        )
                    ),
                ],
                spacing: 0
            ))
    }

    public static func iconOnly(icon: IconInfo) -> NodeStyleLayout {
        return .icon(icon)
    }

    /// Circle node style with border and padding.
    /// Text is centered inside the circle. The layout pipeline (NodeDimensionsStep)
    /// automatically squares up circle-shaped nodes and scales by √2 so the
    /// text rectangle fits inside the circle's inscribed square.
    public static func circle(color: SemanticColor) -> NodeStyleLayout {
        return .background(
            .appearance(shape: .circle, color: color),
            .padded(
                NodeStyleConstants.frameStrokePadding,
                .overlay(
                    base: .circleBorder(
                        borderWidth: NodeStyleConstants.borderWidth,
                        borderColor: borderShade(of: color)
                    ),
                    overlay: .padded(
                        NodeStyleConstants.roundedBoxInsets,
                        .nodeText(color: .black)
                    )
                )
            )
        )
    }

    public static var hidden: NodeStyleLayout {
        return .empty
    }

    /// For nodes whose type is itself the whole content, such as an arithmetic operator.
    /// The content is fixed at notation-definition time rather than read from the node, so
    /// `hasUserText` stays false and the node cannot be renamed by double-click.
    public static func iconCircle(
        fill: SemanticColor, border: SemanticColor, content: CircleContent, contentColor: SemanticColor,
        fontSize: Double = 22
    ) -> NodeStyleLayout {
        return .background(
            .appearance(shape: .circle, color: fill),
            .padded(
                NodeStyleConstants.frameStrokePadding,
                .overlay(
                    base: .circleBorder(borderWidth: NodeStyleConstants.borderWidth, borderColor: border),
                    overlay: .circleContent(
                        content, font: VFont(family: .dmSans, size: fontSize), color: contentColor)
                )
            )
        )
    }

    /// Accent strip + icon badge node (Diagram Style Guide §01–02):
    /// 4px left colored bar, node type badge (icon on a circle, then the uppercase type name),
    /// and content text. The shared treatment for every content node across all notations.
    public static func iconAccentStrip(
        backgroundColor: SemanticColor,
        borderColor: SemanticColor,
        textColor: SemanticColor,
        icon: String,
        typeName: String
    ) -> NodeStyleLayout {
        return framedBox(
            fill: backgroundColor, border: borderColor,
            content: .overlay(
                base: .accentBar(width: NodeStyleConstants.accentBarWidth, color: borderColor),
                overlay: .padded(
                    NodeStyleConstants.accentStripInsets,
                    .vertical(
                        [
                            .typeBadge(icon: icon, typeLabel: typeName, color: borderColor),
                            .nodeText(color: textColor),
                        ],
                        spacing: 4
                    )
                )
            ))
    }

    /// `iconAccentStrip` without the badge, for a notation with a single node type:
    /// the type name would repeat on every node and tell nothing apart (Style Guide §01).
    public static func accentStrip(
        backgroundColor: SemanticColor,
        borderColor: SemanticColor,
        textColor: SemanticColor
    ) -> NodeStyleLayout {
        framedBox(
            fill: backgroundColor, border: borderColor,
            content: .overlay(
                base: .accentBar(width: NodeStyleConstants.accentBarWidth, color: borderColor),
                overlay: .padded(NodeStyleConstants.roundedBoxInsets, .nodeText(color: textColor))
            ))
    }

    /// Ghost pill for concept map relation nodes (Option C from design guide):
    /// Subtle tinted capsule with italic text — visually recedes without disappearing.
    public static var ghostPill: NodeStyleLayout {
        return .background(
            .pill(color: .ghostPillFill),
            .padded(
                VEdgeInsets(top: 4, left: 10, bottom: 4, right: 10),
                .italicNodeText(color: .ghostPillText)
            )
        )
    }

    /// Content node — simple rounded rect with explicit fill, border, and text colors.
    /// No accent strip, no type label. Used for single-type notations such as
    /// Concept Map (Concept nodes) and Causal Loop Diagram (Stock nodes).
    public static func contentNode(
        fill: SemanticColor,
        border: SemanticColor,
        textColor: SemanticColor
    ) -> NodeStyleLayout {
        return framedBox(
            fill: fill, border: border,
            content: .padded(
                NodeStyleConstants.roundedBoxInsets,
                .nodeText(color: textColor)
            ))
    }

    /// C4 element card: a solid rounded box with a `«stereotype»` line above the element
    /// name. In-scope elements pass a saturated fill; external elements pass a grey fill.
    /// Also used as the folded face of a C4 group (fold-as-zoom).
    public static func c4Element(
        stereotype: String, fill: SemanticColor, textColor: SemanticColor, shape: NodeShape = .box
    )
        -> NodeStyleLayout
    {
        let labelFont = VFont(family: .dmSans, size: 11)
        let textStack = NodeStyleLayout.vertical(
            [
                .typeLabel(text: "«\(stereotype)»", font: labelFont, color: textColor),
                .nodeText(color: textColor),
            ],
            spacing: 4
        )

        switch shape {
        case .person:
            // Reserve a top band for the head so the text sits in the body; the person
            // silhouette is the shape itself, so no rounded-rect frame.
            return .background(
                .appearance(shape: .person, color: fill),
                .padded(
                    VEdgeInsets(top: NodeStyleConstants.c4PersonHeadBand + 4, left: 12, bottom: 8, right: 12),
                    textStack))

        case .cylinder:
            // Reserve top and bottom bands for the caps; the cylinder is the outline, so
            // no rounded-rect frame (it would draw a rectangle over an elliptical shape).
            let cap = NodeStyleConstants.c4CylinderCapHeight
            return .background(
                .appearance(shape: .cylinder, color: fill),
                .padded(
                    VEdgeInsets(top: cap + 6, left: 12, bottom: cap + 8, right: 12),
                    textStack))

        default:
            return framedBox(
                fill: fill, border: fill,
                content: .padded(
                    VEdgeInsets(top: 6, left: 12, bottom: 8, right: 12),
                    textStack
                ))
        }
    }

    /// Annotation meta-node (design guide §11):
    /// Cream fill, amber dashed border, italic text. Signals meta-information, not content.
    public static var annotationNode: NodeStyleLayout {
        metaNode(icon: "annotation", typeLabel: "Annotation", fill: .annotationFill, border: .annotationBorder, text: .annotationText)
    }

    /// Warning meta-node (design guide §11):
    /// Blush fill, red dashed border, italic text. Same shape as annotationNode; color signals urgency.
    public static var warningNode: NodeStyleLayout {
        metaNode(icon: "warning", typeLabel: "Warning", fill: .warningFill, border: .warningBorder, text: .warningText)
    }

    /// Folded-group proxy node (design guide §08):
    /// Dashed front border, 2 solid shadow layers behind (+5/+10 px), uppercase group name
    /// (11px / 600 / letter-spaced), and a gray pill badge with the contained-node count.
    /// Title and count are baked in at fold time.
    public static func foldedGroupNode(label: String, count: Int, fill: SemanticColor, border: SemanticColor, textColor: SemanticColor)
        -> NodeStyleLayout
    {
        let titleFont = VFont(family: .dmSans, size: 11)

        let title = NodeStyleLayout.typeLabel(text: label, font: titleFont, color: textColor)
        let badge = NodeStyleLayout.pillBadge(
            text: "\(count)", fill: .foldedBadgeFill, textColor: .white)
        let content = NodeStyleLayout.horizontal([title, badge], spacing: 12)
        return .background(
            .appearance(shape: .box, color: fill),
            .overlay(
                base: .stackedShadow(
                    cornerRadius: NodeStyleConstants.cornerRadius,
                    borderWidth: 1.5,
                    fill: fill, border: border, dash: "6,4"
                ),
                overlay: .padded(VEdgeInsets(top: 10, left: 12, bottom: 10, right: 10), content)
            )
        )
    }
}

// MARK: - Shared shapes

extension NodeStyleLayout {
    /// The rounded box most styles are drawn in: a fill, a solid border inset so
    /// its stroke is not clipped, and the content on top.
    private static func framedBox(fill: SemanticColor, border: SemanticColor, content: NodeStyleLayout) -> NodeStyleLayout {
        .background(
            .appearance(shape: .box, color: fill),
            .padded(
                NodeStyleConstants.frameStrokePadding,
                .overlay(
                    base: .frame(
                        cornerRadius: NodeStyleConstants.cornerRadius,
                        borderWidth: NodeStyleConstants.borderWidth,
                        borderColor: border),
                    overlay: content)))
    }

    /// Annotation and Warning: meta-information rather than content, so a dashed
    /// border and italic text, with the badge saying which.
    private static func metaNode(
        icon: String, typeLabel: String, fill: SemanticColor, border: SemanticColor, text: SemanticColor
    ) -> NodeStyleLayout {
        .background(
            .appearance(shape: .box, color: fill),
            .padded(
                NodeStyleConstants.frameStrokePadding,
                .overlay(
                    base: .dashedFrame(
                        cornerRadius: NodeStyleConstants.cornerRadius, borderWidth: 1.0, borderColor: border,
                        dashPattern: "5,3"),
                    overlay: .padded(
                        NodeStyleConstants.accentStripInsets,
                        .vertical([.typeBadge(icon: icon, typeLabel: typeLabel, color: border), .italicNodeText(color: text)], spacing: 4)
                    ))))
    }

    /// A category style's header: the category name on its colour.
    private static func categoryBar(_ category: String, color: SemanticColor) -> NodeStyleLayout {
        .categoryHeader(
            text: category, font: NodeStyleConstants.categoryFont, backgroundColor: color,
            textColor: color.bwContrastColor)
    }

    /// The border a style draws around its own fill colour.
    private static func borderShade(of fill: SemanticColor) -> SemanticColor {
        fill.darken(to: 0.3)
    }
}
