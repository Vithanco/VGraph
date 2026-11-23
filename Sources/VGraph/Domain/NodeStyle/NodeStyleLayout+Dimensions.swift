/// This allows us to tell Graphviz the correct node size including icons, padding, etc.
extension NodeStyleLayout {

    public func size(aroundText nodeTextSize: VSize) -> VSize {
        switch self {

        case .categoryHeader(let text, let font, _, _):
            // Category header: doesn't determine width, only contributes height
            // It will stretch to fill whatever width the layout provides
            return VSize(
                width: TextSizeEstimator.estimateWidth(text: text, font: font),
                height: NodeStyleConstants.categoryHeight)

        case .frame:
            return VSize.zero

        case .circleBorder:
            return VSize.zero

        case .icon(let iconInfo):
            return VSize(width: iconInfo.iconSize, height: iconInfo.iconSize)

        case .nodeText:
            return nodeTextSize

        case .empty:
            return VSize.zero

        case .padded(let insets, let innerLayout):
            let innerSize = innerLayout.size(aroundText: nodeTextSize)
            return VSize(
                width: innerSize.width + insets.left + insets.right,
                height: innerSize.height + insets.top + insets.bottom
            )

        case .background(_, let innerLayout):
            return innerLayout.size(aroundText: nodeTextSize)

        case .sized(let multiplier, let innerLayout):
            let innerSize = innerLayout.size(aroundText: nodeTextSize)
            return VSize(
                width: innerSize.width * multiplier,
                height: innerSize.height * multiplier
            )

        case .vertical(let layouts, let spacing):
            let sizes = layouts.map { $0.size(aroundText: nodeTextSize) }
            return VSize(
                width: sizes.map { $0.width }.max() ?? 0,
                height: sizes.reduce(0) { $0 + $1.height } + Self.gaps(spacing, between: layouts))

        case .horizontal(let layouts, let spacing):
            let sizes = layouts.map { $0.size(aroundText: nodeTextSize) }
            return VSize(
                width: sizes.reduce(0) { $0 + $1.width } + Self.gaps(spacing, between: layouts),
                height: sizes.map { $0.height }.max() ?? 0)

        case .overlay(let base, let overlay):
            let baseSize = base.size(aroundText: nodeTextSize)
            let overlaySize = overlay.size(aroundText: nodeTextSize)
            return VSize(
                width: max(baseSize.width, overlaySize.width),
                height: max(baseSize.height, overlaySize.height)
            )

        case .accentBar:
            // Decorative overlay — contributes no layout size
            return .zero

        case .typeLabel(let text, let font, _):
            // Underestimated, a sibling slot (a pill badge to the right) ends up
            // underneath the last few letters.
            return VSize(
                width: NodeStyleConstants.uppercaseLabelWidth(text, font: font, letterSpacing: 0.07),
                height: NodeStyleConstants.typeLabelRowHeight)

        case .typeBadge(_, let label, _):
            let labelWidth = NodeStyleConstants.uppercaseLabelWidth(
                label, font: NodeStyleConstants.typeLabelFont, letterSpacing: 0.06)
            return VSize(
                width: NodeStyleConstants.typeBadgeDiameter + NodeStyleConstants.typeBadgeGap + labelWidth,
                height: NodeStyleConstants.typeLabelRowHeight)

        case .dashedFrame:
            return VSize.zero

        case .italicNodeText:
            return nodeTextSize

        case .subtitleText:
            return VSize(width: 0, height: 16)

        case .pillBadge:
            return VSize(width: 22, height: 16)

        case .stackedShadow:
            return VSize.zero

        case .circleContent(let content, let font, _):
            // Sized from the content, not `nodeTextSize`: it is the style's, not the node's.
            switch content {
            case .icon:
                return VSize(width: font.size, height: font.size * 1.3)
            case .text(let text):
                let width = TextSizeEstimator.estimateWidth(text: text, font: font)
                return VSize(width: max(width, font.size), height: font.size * 1.3)
            }
        }
    }

    private static func gaps(_ spacing: Double, between layouts: [NodeStyleLayout]) -> Double {
        spacing * Double(max(0, layouts.count - 1))
    }
}
