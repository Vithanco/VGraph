import VGraph

public enum VSVGNodeLayout {

    public static func render(
        style: NodeStyleLayout, wrappedText: [String], bounds: VRect, font: VFont,
        nodeTextSize: VSize? = nil, darkMode: Bool
    ) throws(VError) -> VSVGNode {
        let relativeBounds = VRect(origin: .zero, size: bounds.size)
        let content = try renderLayout(
            style, wrappedText: wrappedText, bounds: relativeBounds, font: font, nodeTextSize: nodeTextSize,
            darkMode: darkMode)
        return VSVGBuilder.group(transform: VSVGBuilder.translate(x: bounds.origin.x, y: bounds.origin.y), children: [content])
    }

    private static func resolved(_ color: SemanticColor, darkMode: Bool) -> VColor {
        color.resolve(darkMode: darkMode)
    }

    private static func renderLayout(
        _ layout: NodeStyleLayout, wrappedText: [String], bounds: VRect, font: VFont, nodeTextSize: VSize?,
        darkMode: Bool
    ) throws(VError) -> VSVGNode {
        switch layout {

        case .categoryHeader(let headerText, let categoryFont, let bgColorSem, let textColorSem):
            let bgColor = resolved(bgColorSem, darkMode: darkMode)
            let textColor = resolved(textColorSem, darkMode: darkMode)
            let headerHeight = NodeStyleConstants.categoryHeight
            let radius = NodeStyleConstants.cornerRadius
            let borderWidth = NodeStyleConstants.borderWidth

            let inset = borderWidth / 2
            let innerRadius = max(0, radius - inset)

            let x0 = bounds.origin.x
            let y0 = bounds.origin.y
            let path =
                "M \(x0 + inset + innerRadius) \(y0 + inset) "
                + "L \(x0 + bounds.size.width - inset - innerRadius) \(y0 + inset) "
                + "Q \(x0 + bounds.size.width - inset) \(y0 + inset) \(x0 + bounds.size.width - inset) \(y0 + inset + innerRadius) "
                + "L \(x0 + bounds.size.width - inset) \(y0 + headerHeight) "
                + "L \(x0 + inset) \(y0 + headerHeight) "
                + "L \(x0 + inset) \(y0 + inset + innerRadius) "
                + "Q \(x0 + inset) \(y0 + inset) \(x0 + inset + innerRadius) \(y0 + inset) Z"

            let bgPath = VSVGBuilder.path(d: path, style: VShapeStyle(fill: bgColor))
            let textY = bounds.origin.y + headerHeight / 2 + categoryFont.size * 0.35
            let text = VSVGBuilder.text(
                x: bounds.origin.x + bounds.size.width / 2, y: textY, content: headerText, font: categoryFont,
                color: textColor)
            return .fragment([bgPath, text])

        case .frame(let cornerRadius, let borderWidth, let borderColorSem):
            return VSVGBuilder.rect(
                x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height,
                rx: cornerRadius,
                style: VShapeStyle(stroke: resolved(borderColorSem, darkMode: darkMode), strokeWidth: borderWidth)
            )

        case .dashedFrame(let cornerRadius, let borderWidth, let borderColorSem, let dashPattern):
            return VSVGBuilder.rect(
                x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height,
                rx: cornerRadius,
                style: VShapeStyle(
                    stroke: resolved(borderColorSem, darkMode: darkMode), strokeWidth: borderWidth,
                    strokeDashArray: dashPattern
                ))

        case .italicNodeText(let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let lineHeightMultiplier = wrappedText.count == 1 ? 1.0 : 1.2
            let lineHeight = font.size * lineHeightMultiplier
            let textHeight = nodeTextSize?.height ?? (lineHeight * Double(wrappedText.count))
            let verticalOffset = (bounds.size.height - textHeight) / 2
            let lines: [VSVGNode] = wrappedText.enumerated().map { index, line in
                let y =
                    bounds.origin.y + verticalOffset + lineHeight / 2 + lineHeight * Double(index) + font.size * 0.35
                return VSVGBuilder.text(
                    x: bounds.origin.x + bounds.size.width / 2, y: y, content: line, font: font, color: color,
                    anchor: "middle", fontStyle: "italic")
            }
            return .fragment(lines)

        case .subtitleText(let text, let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let subFont = VFont(family: font.family, size: 12)
            let y = bounds.origin.y + bounds.size.height / 2 + subFont.size * 0.35
            return VSVGBuilder.text(
                x: bounds.origin.x + 4, y: y, content: text, font: subFont, color: color, anchor: "start",
                fontStyle: "italic")

        case .pillBadge(let text, let fillSem, let textColorSem):
            let fill = resolved(fillSem, darkMode: darkMode)
            let textColor = resolved(textColorSem, darkMode: darkMode)
            let pillW = 22.0
            let pillH = 16.0
            let rx = pillH / 2
            let x = bounds.maxX - pillW - 4
            let y = bounds.origin.y + (bounds.size.height - pillH) / 2
            let rect = VSVGBuilder.rect(x: x, y: y, width: pillW, height: pillH, rx: rx, style: VShapeStyle(fill: fill))
            let badgeFont = VFont(family: font.family, size: 9)
            let label = VSVGBuilder.text(
                x: x + pillW / 2, y: y + pillH / 2 + badgeFont.size * 0.35, content: text, font: badgeFont,
                color: textColor, anchor: "middle", fontWeight: 700)
            return .fragment([rect, label])

        case .stackedShadow(let cornerRadius, let borderWidth, let fillSem, let borderSem, let dash):
            let fill = resolved(fillSem, darkMode: darkMode)
            let border = resolved(borderSem, darkMode: darkMode)
            let shadowOffsets: [(dx: Double, dy: Double, opacity: Double)] = [(10, 10, 0.50), (5, 5, 0.65)]
            var shadows: [VSVGNode] = []
            for shadow in shadowOffsets {
                let shadowFill = VColor(
                    red: fill.redComponent, green: fill.greenComponent, blue: fill.blueComponent,
                    alpha: shadow.opacity)
                let shadowBorder = VColor(
                    red: border.redComponent, green: border.greenComponent, blue: border.blueComponent,
                    alpha: shadow.opacity)
                shadows.append(
                    VSVGBuilder.rect(
                        x: bounds.origin.x + shadow.dx, y: bounds.origin.y + shadow.dy, width: bounds.size.width,
                        height: bounds.size.height, rx: cornerRadius,
                        style: VShapeStyle(fill: shadowFill, stroke: shadowBorder, strokeWidth: borderWidth)))
            }
            let front = VSVGBuilder.rect(
                x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height,
                rx: cornerRadius,
                style: VShapeStyle(
                    fill: fill, stroke: border, strokeWidth: borderWidth,
                    strokeDashArray: dash.isEmpty ? nil : dash
                ))
            return .fragment(shadows + [front])

        case .circleBorder(let borderWidth, let borderColorSem):
            let cx = bounds.origin.x + bounds.size.width / 2
            let cy = bounds.origin.y + bounds.size.height / 2
            return VSVGBuilder.ellipse(
                cx: cx, cy: cy, rx: bounds.size.width / 2, ry: bounds.size.height / 2,
                style: VShapeStyle(
                    fill: VColor.clear, stroke: resolved(borderColorSem, darkMode: darkMode),
                    strokeWidth: borderWidth
                ))

        case .icon(let iconInfo):
            return renderIcon(iconInfo, bounds: bounds, darkMode: darkMode)

        case .nodeText(let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let lineHeightMultiplier = wrappedText.count == 1 ? 1.0 : 1.2
            let lineHeight = font.size * lineHeightMultiplier
            let textHeight = nodeTextSize?.height ?? (lineHeight * Double(wrappedText.count))
            let verticalOffset = (bounds.size.height - textHeight) / 2
            let lines: [VSVGNode] = wrappedText.enumerated().map { index, line in
                let y =
                    bounds.origin.y + verticalOffset + lineHeight / 2 + lineHeight * Double(index) + font.size * 0.35
                return VSVGBuilder.text(
                    x: bounds.origin.x + bounds.size.width / 2, y: y, content: line, font: font, color: color,
                    anchor: "middle")
            }
            return .fragment(lines)

        case .empty:
            return .empty

        case .padded(let insets, let innerLayout):
            let paddedBounds = VRect(
                origin: VPoint(x: bounds.origin.x + insets.left, y: bounds.origin.y + insets.top),
                size: VSize(
                    width: bounds.size.width - insets.left - insets.right,
                    height: bounds.size.height - insets.top - insets.bottom)
            )
            return try renderLayout(
                innerLayout, wrappedText: wrappedText, bounds: paddedBounds, font: font, nodeTextSize: nodeTextSize,
                darkMode: darkMode)

        case .background(let bg, let innerLayout):
            let bgNode = renderBackground(bg, bounds: bounds, darkMode: darkMode)
            let contentNode = try renderLayout(
                innerLayout, wrappedText: wrappedText, bounds: bounds, font: font, nodeTextSize: nodeTextSize,
                darkMode: darkMode)
            return .fragment([bgNode, contentNode])

        case .sized(let multiplier, let innerLayout):
            let scaledBounds = VRect(
                origin: bounds.origin,
                size: VSize(width: bounds.size.width * multiplier, height: bounds.size.height * multiplier))
            return try renderLayout(
                innerLayout, wrappedText: wrappedText, bounds: scaledBounds, font: font, nodeTextSize: nodeTextSize,
                darkMode: darkMode)

        case .vertical(let layouts, let spacing):
            return try renderVertical(
                layouts, wrappedText: wrappedText, bounds: bounds, spacing: spacing, font: font,
                nodeTextSize: nodeTextSize, darkMode: darkMode)

        case .horizontal(let layouts, let spacing):
            return try renderHorizontal(
                layouts, wrappedText: wrappedText, bounds: bounds, spacing: spacing, font: font,
                nodeTextSize: nodeTextSize, darkMode: darkMode)

        case .overlay(let base, let overlay):
            let baseNode = try renderLayout(
                base, wrappedText: wrappedText, bounds: bounds, font: font, nodeTextSize: nodeTextSize,
                darkMode: darkMode)
            let overlayNode = try renderLayout(
                overlay, wrappedText: wrappedText, bounds: bounds, font: font, nodeTextSize: nodeTextSize,
                darkMode: darkMode)
            return .fragment([baseNode, overlayNode])

        case .accentBar(let width, let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let r = NodeStyleConstants.cornerRadius
            let x = bounds.origin.x
            let y = bounds.origin.y
            let h = bounds.size.height
            let path =
                "M \(x+r) \(y) L \(x+width) \(y) L \(x+width) \(y+h) L \(x+r) \(y+h) "
                + "Q \(x) \(y+h) \(x) \(y+h-r) L \(x) \(y+r) Q \(x) \(y) \(x+r) \(y) Z"
            return VSVGBuilder.path(d: path, style: VShapeStyle(fill: color))

        case .typeLabel(let text, let labelFont, let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let x = bounds.origin.x
            let y = bounds.origin.y + bounds.size.height * 0.72
            return VSVGBuilder.text(
                x: x, y: y, content: text.uppercased(), font: labelFont, color: color, anchor: "start",
                fontWeight: 600, opacity: 0.85, letterSpacing: "0.07em")

        case .typeBadge(let icon, let typeLabel, let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let circleR = 9.0
            let cx = bounds.origin.x + circleR
            let cy = bounds.origin.y + bounds.size.height / 2
            let circle = VSVGBuilder.circle(cx: cx, cy: cy, r: circleR, style: VShapeStyle(fill: color))
            let iconNode = IconRenderer.renderWithReference(
                name: icon, color: resolved(.badgeIcon, darkMode: darkMode), size: 14, centerX: cx, centerY: cy)
            let labelFont = NodeStyleConstants.typeLabelFont
            let labelX = bounds.origin.x + circleR * 2 + 5
            let labelY = bounds.origin.y + bounds.size.height / 2 + labelFont.size * 0.38
            let labelText = VSVGBuilder.text(
                x: labelX, y: labelY, content: typeLabel.uppercased(), font: labelFont, color: color,
                anchor: "start", fontWeight: 600, letterSpacing: "0.06em")
            return .fragment([circle, iconNode, labelText])

        case .circleContent(let content, let font, let colorSem):
            let color = resolved(colorSem, darkMode: darkMode)
            let x = bounds.origin.x + bounds.size.width / 2
            switch content {
            case .icon(let name):
                return IconRenderer.renderWithReference(
                    name: name, color: color, size: font.size, centerX: x,
                    centerY: bounds.origin.y + bounds.size.height / 2)
            case .text(let text):
                let y = bounds.origin.y + bounds.size.height / 2 + font.size * 0.35
                return VSVGBuilder.text(
                    x: x, y: y, content: text, font: font, color: color, anchor: "middle", fontWeight: 700)
            }
        }
    }

    // MARK: - Background

    private static func renderBackground(_ background: NodeBackground, bounds: VRect, darkMode: Bool) -> VSVGNode {
        switch background {
        case .appearance(let shape, let colorSem):
            return renderBackgroundShape(
                shape: shape, bounds: bounds, color: resolved(colorSem, darkMode: darkMode),
                cornerRadius: NodeStyleConstants.cornerRadius)

        case .solid(let shape, let colorSem):
            return renderBackgroundShape(
                shape: shape, bounds: bounds, color: resolved(colorSem, darkMode: darkMode), cornerRadius: 0)

        case .clear:
            return .empty

        case .pill(let colorSem):
            let rx = bounds.size.height / 2
            return VSVGBuilder.rect(
                x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height,
                rx: rx, style: VShapeStyle(fill: resolved(colorSem, darkMode: darkMode)))
        }
    }

    private static func renderBackgroundShape(
        shape: NodeShape, bounds: VRect, color: VColor, cornerRadius: Double
    ) -> VSVGNode {
        switch shape {
        case .box:
            return VSVGBuilder.rect(
                x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height,
                rx: cornerRadius, style: VShapeStyle(fill: color))
        case .circle:
            let cx = bounds.origin.x + bounds.size.width / 2
            let cy = bounds.origin.y + bounds.size.height / 2
            return VSVGBuilder.ellipse(
                cx: cx, cy: cy, rx: bounds.size.width / 2, ry: bounds.size.height / 2,
                style: VShapeStyle(fill: color))
        case .point:
            let cx = bounds.origin.x + bounds.size.width / 2
            let cy = bounds.origin.y + bounds.size.height / 2
            let r = min(bounds.size.width, bounds.size.height) / 4
            return VSVGBuilder.circle(cx: cx, cy: cy, r: r, style: VShapeStyle(fill: color))
        case .cylinder:
            let rx = bounds.size.width / 2
            let capHeight = min(NodeStyleConstants.c4CylinderCapHeight, bounds.size.height / 2)
            let cx = bounds.origin.x + rx
            let topCy = bounds.origin.y + capHeight
            let bottomCy = bounds.origin.y + bounds.size.height - capHeight
            let body = VSVGBuilder.rect(
                x: bounds.origin.x, y: topCy, width: bounds.size.width, height: bounds.size.height - 2 * capHeight,
                style: VShapeStyle(fill: color))
            let bottomCap = VSVGBuilder.ellipse(cx: cx, cy: bottomCy, rx: rx, ry: capHeight, style: VShapeStyle(fill: color))
            let topCap = VSVGBuilder.ellipse(cx: cx, cy: topCy, rx: rx, ry: capHeight, style: VShapeStyle(fill: color))
            return .fragment([bottomCap, body, topCap])
        case .person:
            let headRadius = min(NodeStyleConstants.c4PersonHeadRadius, bounds.size.width / 2)
            let cx = bounds.origin.x + bounds.size.width / 2
            let headCy = bounds.origin.y + headRadius
            let bodyY = bounds.origin.y + NodeStyleConstants.c4PersonHeadBand
            let body = VSVGBuilder.rect(
                x: bounds.origin.x, y: bodyY, width: bounds.size.width, height: bounds.size.height - (bodyY - bounds.origin.y),
                rx: cornerRadius, style: VShapeStyle(fill: color))
            let head = VSVGBuilder.circle(cx: cx, cy: headCy, r: headRadius, style: VShapeStyle(fill: color))
            return .fragment([body, head])
        }
    }

    // MARK: - Layout containers

    private static func renderVertical(
        _ layouts: [NodeStyleLayout], wrappedText: [String], bounds: VRect, spacing: Double, font: VFont,
        nodeTextSize: VSize?, darkMode: Bool
    ) throws(VError) -> VSVGNode {
        guard !layouts.isEmpty else { return .empty }
        let textSize =
            nodeTextSize ?? NodeStyleLayout.vertical(layouts, spacing: spacing).fallbackTextSize()
        let heights = layouts.map { $0.calculateSizeWithText(textSize).height }

        var children: [VSVGNode] = []
        var currentY = bounds.origin.y
        for (index, layout) in layouts.enumerated() {
            let itemBounds = VRect(
                origin: VPoint(x: bounds.origin.x, y: currentY),
                size: VSize(width: bounds.size.width, height: heights[index]))
            children.append(
                try renderLayout(
                    layout, wrappedText: wrappedText, bounds: itemBounds, font: font, nodeTextSize: nodeTextSize,
                    darkMode: darkMode))
            currentY += heights[index] + spacing
        }
        return .fragment(children)
    }

    private static func renderHorizontal(
        _ layouts: [NodeStyleLayout], wrappedText: [String], bounds: VRect, spacing: Double, font: VFont,
        nodeTextSize: VSize?, darkMode: Bool
    ) throws(VError) -> VSVGNode {
        guard !layouts.isEmpty else { return .empty }
        let textSize =
            nodeTextSize ?? NodeStyleLayout.horizontal(layouts, spacing: spacing).fallbackTextSize()
        let widths = layouts.map { $0.calculateSizeWithText(textSize).width }

        var children: [VSVGNode] = []
        var currentX = bounds.origin.x
        for (index, layout) in layouts.enumerated() {
            let itemBounds = VRect(
                origin: VPoint(x: currentX, y: bounds.origin.y),
                size: VSize(width: widths[index], height: bounds.size.height))
            children.append(
                try renderLayout(
                    layout, wrappedText: wrappedText, bounds: itemBounds, font: font, nodeTextSize: nodeTextSize,
                    darkMode: darkMode))
            currentX += widths[index] + spacing
        }
        return .fragment(children)
    }

    // MARK: - Icon

    private static func renderIcon(_ iconInfo: IconInfo, bounds: VRect, darkMode: Bool) -> VSVGNode {
        let size = iconInfo.iconSize
        let centerX = bounds.origin.x + bounds.size.width / 2
        let centerY = bounds.origin.y + bounds.size.height / 2
        return IconRenderer.renderWithReference(
            name: iconInfo.iconName, color: SVGThemeColor.icon(iconInfo.iconColor, darkMode: darkMode), size: size,
            centerX: centerX, centerY: centerY)
    }
}
