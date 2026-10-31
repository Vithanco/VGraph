/// This allows us to tell Graphviz the correct node size including icons, padding, etc.
extension NodeStyleLayout {

    public func calculateSizeWithText(_ nodeTextSize: VSize) -> VSize {
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
            let innerSize = innerLayout.calculateSizeWithText(nodeTextSize)
            return VSize(
                width: innerSize.width + insets.left + insets.right,
                height: innerSize.height + insets.top + insets.bottom
            )

        case .background(_, let innerLayout):
            return innerLayout.calculateSizeWithText(nodeTextSize)

        case .sized(let multiplier, let innerLayout):
            let innerSize = innerLayout.calculateSizeWithText(nodeTextSize)
            return VSize(
                width: innerSize.width * multiplier,
                height: innerSize.height * multiplier
            )

        case .vertical(let layouts, let spacing):
            var totalWidth: Double = 0
            var totalHeight: Double = 0

            for layout in layouts {
                let size = layout.calculateSizeWithText(nodeTextSize)
                totalWidth = max(totalWidth, size.width)
                totalHeight += size.height
            }

            totalHeight += spacing * Double(max(0, layouts.count - 1))
            return VSize(width: totalWidth, height: totalHeight)

        case .horizontal(let layouts, let spacing):
            var totalWidth: Double = 0
            var totalHeight: Double = 0

            for layout in layouts {
                let size = layout.calculateSizeWithText(nodeTextSize)
                totalWidth += size.width
                totalHeight = max(totalHeight, size.height)
            }

            totalWidth += spacing * Double(max(0, layouts.count - 1))
            return VSize(width: totalWidth, height: totalHeight)

        case .overlay(let base, let overlay):
            let baseSize = base.calculateSizeWithText(nodeTextSize)
            let overlaySize = overlay.calculateSizeWithText(nodeTextSize)
            return VSize(
                width: max(baseSize.width, overlaySize.width),
                height: max(baseSize.height, overlaySize.height)
            )

        case .accentBar:
            // Decorative overlay — contributes no layout size
            return .zero

        case .typeLabel(let text, let font, _):
            // Renderer draws the text uppercased, font-weight 600, with letter-spacing 0.07em.
            // The simple char-count × avg-width estimate underestimates that by ~25% — without
            // the correction, sibling layout slots (e.g. a pill badge to the right) end up
            // underneath the last few letters. Mirrors NodeStyleConstants.iconBadgeMinWidth.
            let upper = text.uppercased()
            let baseWidth = TextSizeEstimator.estimateWidth(text: upper, font: font)
            let uppercaseFactor = 1.2
            let letterSpacing = Double(upper.count) * font.size * 0.07
            return VSize(
                width: baseWidth * uppercaseFactor + letterSpacing,
                height: NodeStyleConstants.typeLabelRowHeight)

        case .typeBadge(_, let label, _):
            let font = NodeStyleConstants.typeLabelFont
            let labelWidth = TextSizeEstimator.estimateWidth(text: label.uppercased(), font: font)
            let badgeDiameter = 18.0
            return VSize(
                width: badgeDiameter + 6 + labelWidth,
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
}
