import VGraph

public enum VSVGGraph {

    // MARK: - Nodes

    static func renderNodes(graph: VGraph, darkMode: Bool, keepSet: Set<Node>? = nil) throws(VError) -> VSVGNode {
        let traverser = GraphStructureTraverser<VSVGNode>(
            onEnterGroup: { (_: Group, _: VGraph, _: Int) throws(VError) -> VSVGNode in .empty },
            onExitGroup: { (_: Group, _: VGraph, _: Int) throws(VError) -> VSVGNode in .empty },
            onNode: { (node: Node, graph: VGraph, _: Int) throws(VError) -> VSVGNode in
                if let keep = keepSet, !keep.contains(node) { return .empty }
                guard let pos = try? graph.get(node: node, attribute: Attributes.Node.layoutedPos) else {
                    return .empty
                }
                let wrappedText = (try? graph.get(node: node, attribute: Attributes.Node.wrappedText)) ?? []
                let nodeTextSize = try? graph.get(node: node, attribute: Attributes.Node.nodeTextSize)
                let style: NodeStyleLayout =
                    (try? graph.get(node: node, attribute: Attributes.Node.style)) ?? NodeStyleLayout.bareText
                let font: VFont = graph.getFont(forNode: node)
                let nodeSize: VSize = (try? graph.get(node: node, attribute: Attributes.Node.layoutedSize)) ?? .zero
                let nodeBounds = VRect(
                    origin: VPoint(x: pos.x - nodeSize.width / 2, y: pos.y - nodeSize.height / 2), size: nodeSize)
                let content = try VSVGNodeLayout.render(
                    style: style, wrappedText: wrappedText, bounds: nodeBounds, font: font,
                    nodeTextSize: nodeTextSize, darkMode: darkMode)
                let nodeClass =
                    SVGElementId.isFoldedGroup(node, in: graph)
                    ? "\(SVGElementId.nodeClass) \(SVGElementId.foldedGroupClass)" : SVGElementId.nodeClass
                // After the node so it sits above its background.
                let badge = VSVGURLBadge.render(
                    url: graph.url(of: .node(node)), centerX: nodeBounds.maxX - 2, centerY: nodeBounds.minY + 2,
                    darkMode: darkMode)
                return VSVGBuilder.group(
                    id: SVGElementId.displayNode(node, in: graph), cssClass: nodeClass, children: [content, badge])
            },
            onEdge: { (_: Edge, _: VGraph) throws(VError) -> VSVGNode in .empty },
            combine: { .fragment($0) },
            order: .groupsFirst
        )
        return try traverser.traverse(graph)
    }

    // MARK: - Graph label

    static func renderGraphLabel(graph: VGraph, darkMode: Bool) -> VSVGNode {
        let rootGrp = Group(rawValue: rootGroup)
        guard let labelPos = try? graph.get(group: rootGrp, attribute: Attributes.Group.labelLayoutedPos),
            labelPos != VPoint.zero,
            let labelText = try? graph.get(group: rootGrp, attribute: Attributes.Group.label),
            !labelText.isEmpty
        else {
            return .empty
        }

        let font = graph.getFont(forGroup: rootGrp)
        let color: VColor
        if let fontColor = try? graph.get(group: rootGrp, attribute: Attributes.Group.fontcolor) {
            color = SVGThemeColor.group(fontColor, semantic: SemanticColor.groupText, darkMode: darkMode)
        } else {
            color = SemanticColor.groupText.resolve(darkMode: darkMode)
        }

        return VSVGBuilder.text(
            x: labelPos.x, y: labelPos.y, content: labelText, font: font, color: color, anchor: "middle")
    }

    // MARK: - Top-level composition

    /// Takes no `sourceVGL`: the envelope is spliced into the string by
    /// `VSVGRenderer.render`, which says why.
    public static func render<Logger: ForLogMessages>(
        graph: VGraph, darkMode: Bool = false, logger: Logger,
        overlayProviders: [String: NotationOverlayEntry] = NotationOverlayRegistry.default,
        interactive: Bool = false
    ) throws(VError) -> VSVGNode {
        let showWatermark = try graph.get(attribute: Attributes.Group.watermark)
        let icons = SVGRenderQueries.collectIcons(from: graph)
        let overlay = NotationOverlayRegistry.resolve(graph: graph, in: overlayProviders)

        var bounds = SVGRenderQueries.calculateBounds(graph: graph)
        for rect in overlay?.boundsContributions(graph) ?? [] {
            bounds.minX = min(bounds.minX, rect.minX)
            bounds.minY = min(bounds.minY, rect.minY)
            bounds.maxX = max(bounds.maxX, rect.maxX)
            bounds.maxY = max(bounds.maxY, rect.maxY)
        }

        let ctx = RenderContext(
            graph: graph, darkMode: darkMode, overlay: overlay, interactive: interactive)
        var content: [VSVGNode] = []

        content.append(VSVGDefs.render(icons: icons, includeWatermark: showWatermark, darkMode: darkMode))

        // The handle rules ship *inside* the SVG, not in the editor's stylesheet:
        // an exported file carrying handles but not the rule that hides them
        // would show them permanently (ADR-0021).
        let rules =
            SVGHoverStyles.rules(graph: graph) + (overlay?.hoverStyleRules(graph) ?? "")
            + (interactive ? SVGHoverStyles.edgeEndRules : "")
        content.append(rules.isEmpty ? .empty : VSVGBuilder.style(css: rules))

        content.append(try overlay?.renderBetweenDefsAndGroups(ctx) ?? .empty)
        content.append(try VSVGGroup.render(graph: graph, darkMode: darkMode))
        content.append(try overlay?.renderBetweenGroupsAndEdges(ctx) ?? .empty)

        content.append(renderEdgesPass(ctx: ctx, darkMode: darkMode, logger: logger))
        content.append(try overlay?.renderBetweenEdgesAndNodes(ctx) ?? .empty)
        content.append(try renderNodesPass(ctx: ctx, darkMode: darkMode))
        content.append(try overlay?.renderBetweenNodesAndLabel(ctx) ?? .empty)

        content.append(renderGraphLabel(graph: graph, darkMode: darkMode))

        if showWatermark {
            let avoidanceRects =
                SVGRenderQueries.collectNodeRects(graph: graph) + SVGRenderQueries.collectGroupLabelRects(graph: graph)
            content.append(
                WatermarkRenderer.renderWatermark(
                    viewBoxX: bounds.minX, viewBoxY: bounds.minY,
                    viewBoxWidth: bounds.maxX - bounds.minX, viewBoxHeight: bounds.maxY - bounds.minY,
                    avoidRects: avoidanceRects))
        }

        let padding = 50.0
        let viewBoxX = bounds.minX - padding
        let viewBoxY = bounds.minY - padding
        let viewBoxWidth = (bounds.maxX - bounds.minX) + 2 * padding
        let viewBoxHeight = (bounds.maxY - bounds.minY) + 2 * padding

        // Raw interpolation, not SVGBuilder.format — see
        // svgDimensionsKeepRawDoubleFormattingUnlikeInnerCoordinates.
        var attributes = [
            VSVGAttribute("width", "\(viewBoxWidth)"),
            VSVGAttribute("height", "\(viewBoxHeight)"),
            VSVGAttribute("viewBox", "\(viewBoxX) \(viewBoxY) \(viewBoxWidth) \(viewBoxHeight)"),
            VSVGAttribute("xmlns", "http://www.w3.org/2000/svg"),
        ]
        if darkMode {
            attributes.append(VSVGAttribute("data-theme", "dark"))
        }

        return .element(.svg, attributes, content)
    }

    private static func renderEdgesPass<Logger: ForLogMessages>(
        ctx: RenderContext, darkMode: Bool, logger: Logger
    ) -> VSVGNode {
        guard let overlay = ctx.overlay else {
            return VSVGEdge.render(
                graph: ctx.graph, darkMode: darkMode, logger: logger,
                interactive: ctx.interactive)
        }
        let allEdges = Set(ctx.graph.edges)
        let kept = SVGRenderQueries.keepSet(allEdges, filteredTo: overlay.filterEdges(allEdges, ctx.graph))
        return VSVGEdge.render(
            graph: ctx.graph, darkMode: darkMode, logger: logger, keepSet: kept,
            interactive: ctx.interactive)
    }

    private static func renderNodesPass(ctx: RenderContext, darkMode: Bool) throws(VError) -> VSVGNode {
        guard let overlay = ctx.overlay else {
            return try renderNodes(graph: ctx.graph, darkMode: darkMode)
        }
        let allNodes = Set(ctx.graph.nodes)
        let kept = SVGRenderQueries.keepSet(allNodes, filteredTo: overlay.filterNodes(allNodes, ctx.graph))
        return try renderNodes(graph: ctx.graph, darkMode: darkMode, keepSet: kept)
    }
}
