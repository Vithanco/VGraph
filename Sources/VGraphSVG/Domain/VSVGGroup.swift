// Recurses directly instead of reusing GraphStructureTraverser: that traverser
// concatenates a flat list, and nesting here has to be structural.

import VGraph

public enum VSVGGroup {

    public static func render(graph: VGraph, darkMode: Bool) throws(VError) -> VSVGNode {
        let (rootGroups, _) = try graph.getRootContent()
        return .fragment(try renderChildren(rootGroups, graph: graph, depth: 0, darkMode: darkMode))
    }

    private static func renderChildren(
        _ groups: [Group], graph: VGraph, depth: Int, darkMode: Bool
    ) throws(VError) -> [VSVGNode] {
        var result: [VSVGNode] = []
        for group in try GraphExportOrderPreservation.sortByItemOrder(groups, in: graph) {
            result.append(contentsOf: try renderGroup(group, graph: graph, depth: depth, darkMode: darkMode))
        }
        return result
    }

    private static func renderGroup(
        _ group: Group, graph: VGraph, depth: Int, darkMode: Bool
    ) throws(VError) -> [VSVGNode] {
        let (subGroups, _) = try graph.getDirectContent(group: group)

        guard let bounds = try? graph.get(group: group, attribute: Attributes.Group.layoutedBounds),
            bounds != VRect.zero
        else {
            return try renderChildren(subGroups, graph: graph, depth: depth, darkMode: darkMode)
        }

        let borderWidth =
            (try? graph.get(group: group, attribute: Attributes.Group.borderWidth))
            ?? Attributes.Group.borderWidth.defaultValue
        let borderColorRaw =
            (try? graph.get(group: group, attribute: Attributes.Group.borderColor))
            ?? Attributes.Group.borderColor.defaultValue
        let borderColor = SVGThemeColor.group(
            borderColorRaw, semantic: SemanticColor.groupBorder, darkMode: darkMode)
        let backgroundColorRaw =
            (try? graph.get(group: group, attribute: Attributes.Group.backgroundColor))
            ?? Attributes.Group.backgroundColor.defaultValue
        let backgroundColor = SVGThemeColor.group(
            backgroundColorRaw, semantic: SemanticColor.groupFill, darkMode: darkMode)
        let cornerRadius =
            (try? graph.get(group: group, attribute: Attributes.Group.cornerRadius))
            ?? Attributes.Group.cornerRadius.defaultValue
        let borderDash =
            (try? graph.get(group: group, attribute: Attributes.Group.borderDash))
            ?? Attributes.Group.borderDash.defaultValue

        var content: [VSVGNode] = [
            VSVGBuilder.rect(
                x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height, rx: cornerRadius,
                style: VShapeStyle(
                    fill: backgroundColor, stroke: borderColor, strokeWidth: borderWidth,
                    strokeDashArray: borderDash.isEmpty ? nil : borderDash))
        ]

        if let labelText = drawnLabel(of: group, in: graph) {
            let fontColor: VColor
            if let gFontColor = try? graph.get(group: group, attribute: Attributes.Group.fontcolor) {
                fontColor = SVGThemeColor.group(gFontColor, semantic: SemanticColor.groupText, darkMode: darkMode)
            } else {
                fontColor = SemanticColor.groupText.resolve(darkMode: darkMode)
            }

            content.append(
                VSVGBuilder.text(
                    x: bounds.minX + labelInset.x, y: bounds.minY + labelInset.y, content: labelText,
                    font: labelFont, color: fontColor, anchor: "start", fontWeight: 600,
                    letterSpacing: "\(labelLetterSpacingEm)em", cssClass: SVGElementId.groupLabelClass))
        }

        // Before the children, so a member drawn later can overlap it.
        content.append(
            VSVGURLBadge.render(
                url: graph.url(of: .group(group)), centerX: bounds.maxX - 2, centerY: bounds.maxY - 2,
                darkMode: darkMode))

        content.append(contentsOf: try renderChildren(subGroups, graph: graph, depth: depth + 1, darkMode: darkMode))

        return [
            VSVGBuilder.group(
                id: SVGElementId.group(group.id.id), cssClass: "\(SVGElementId.groupClass) depth-\(depth)",
                children: content)
        ]
    }

    // MARK: - Label geometry

    // The label is drawn here, not at Graphviz's label position, so anything
    // that must keep clear of it (the watermark) asks `labelRect`.
    private static let labelFont = VFont(family: .dmSans, size: 11)
    private static let labelInset = VPoint(x: 14, y: 20)
    private static let labelLetterSpacingEm = 0.07

    private static func drawnLabel(of group: Group, in graph: VGraph) -> String? {
        guard let text = graph.label(of: .group(group)), !text.isEmpty else { return nil }
        return text.uppercased()
    }

    /// `nil` when the group draws no label.
    static func labelRect(of group: Group, in graph: VGraph) -> VRect? {
        guard let text = drawnLabel(of: group, in: graph),
            let bounds = try? graph.get(group: group, attribute: Attributes.Group.layoutedBounds),
            bounds != VRect.zero
        else { return nil }
        let spacing = Double(text.count) * labelFont.size * labelLetterSpacingEm
        let baseline = bounds.minY + labelInset.y
        return VRect(
            x: bounds.minX + labelInset.x, y: baseline - labelFont.size,
            width: TextSizeEstimator.estimateWidth(text: text, font: labelFont) + spacing,
            height: labelFont.size * 1.3)
    }
}
