import VGraph

public enum VSVGEdge {

    static func renderShape(_ shape: Shape, color: VColor) -> VSVGNode {
        switch shape {
        case .circle(let center, let radius):
            return VSVGBuilder.circle(
                cx: center.x, cy: center.y, r: radius,
                style: VShapeStyle(fill: color, stroke: color, strokeWidth: 1))

        case .ellipse(let center, let radiusX, let radiusY):
            return VSVGBuilder.ellipse(
                cx: center.x, cy: center.y, rx: radiusX, ry: radiusY,
                style: VShapeStyle(fill: color, stroke: color, strokeWidth: 1))

        case .polygon(let points):
            let polygonPoints = points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
            return VSVGBuilder.polygon(points: polygonPoints, style: VShapeStyle(fill: color, stroke: color, strokeWidth: 1))

        case .spline(let controlPoints):
            guard controlPoints.count >= 4 else {
                let polygonPoints = controlPoints.map { "\($0.x),\($0.y)" }.joined(separator: " ")
                return VSVGBuilder.polygon(
                    points: polygonPoints, style: VShapeStyle(fill: color, stroke: color, strokeWidth: 1))
            }

            let start = controlPoints[0]
            var pathData = "M \(start.x) \(start.y)"
            var i = 1
            while i + 2 < controlPoints.count {
                let cp1 = controlPoints[i]
                let cp2 = controlPoints[i + 1]
                let end = controlPoints[i + 2]
                pathData += " C \(cp1.x) \(cp1.y), \(cp2.x) \(cp2.y), \(end.x) \(end.y)"
                i += 3
            }
            pathData += " Z"

            return VSVGBuilder.path(d: pathData, style: VShapeStyle(fill: color, stroke: color, strokeWidth: 1))
        }
    }

    static func renderEdgeLabel(_ label: LabelData?, darkMode: Bool) -> VSVGNode {
        guard let label else { return .empty }
        let font = VFont(family: .dmSans, size: 11)
        return VSVGBuilder.text(
            x: label.position.x, y: label.position.y, content: label.text, font: font,
            color: SemanticColor.ink2.resolve(darkMode: darkMode), anchor: "middle", fontStyle: "italic")
    }

    static func renderEdgeEndLabel(_ label: LabelData?, darkMode: Bool) -> VSVGNode {
        guard let label else { return .empty }
        let font = VFont(family: .dmSans, size: 15)
        return VSVGBuilder.text(
            x: label.position.x, y: label.position.y, content: label.text, font: font,
            color: SemanticColor.edgeBold.resolve(darkMode: darkMode), anchor: "middle",
            fontWeight: 700)
    }

    /// Radius of an [[Edge end]] handle. One circle serves as both the ring and
    /// the hit target — it is mouse-and-pen only (a finger has no hover to
    /// summon it with), so it needs no touch-sized target.
    static let endHandleRadius = 7.0

    /// The grab handle for one end, or `.empty` where the end must not be
    /// dragged. Anchored on the spline's own endpoint, which Graphviz emits
    /// tail-to-head regardless of `dir` — so `first` is the `from` end and
    /// `last` the `to` end, whatever mark the notation draws there (ADR-0021).
    ///
    /// **No handle on a folded group's box.** Folding redirects the edge onto
    /// the box and keeps its id, so the end drawn there stands in for a node
    /// inside; dragging it off works, but `edgeEndpointIsGroup` means it can
    /// never be dropped back. An end you cannot drop back on is an end you
    /// cannot drag off.
    static func renderEndHandle(
        graph: VGraph, edge: Edge, end: VEdgeEnd, at point: VPoint, color: VColor, darkMode: Bool
    ) -> VSVGNode {
        let node = end == .from ? edge.from : edge.to
        guard !graph.isFoldedStandIn(node) else { return .empty }

        return .element(
            .circle,
            [
                VSVGAttribute("class", SVGElementId.edgeEndClass),
                VSVGAttribute(SVGElementId.edgeEndEdgeAttribute, edge.id.id),
                VSVGAttribute(SVGElementId.edgeEndSideAttribute, SVGElementId.edgeEndSide(end)),
                VSVGAttribute("cx", VSVGBuilder.number(point.x)),
                VSVGAttribute("cy", VSVGBuilder.number(point.y)),
                VSVGAttribute("r", VSVGBuilder.number(endHandleRadius)),
                VSVGAttribute("fill", SemanticColor.edgeEndFill.resolve(darkMode: darkMode).hexString),
                VSVGAttribute("stroke", color.hexString),
                VSVGAttribute("stroke-width", "2"),
            ])
    }

    public static func render<Logger: ForLogMessages>(
        graph: VGraph, darkMode: Bool, logger: Logger, keepSet: Set<Edge>? = nil,
        interactive: Bool = false
    ) -> VSVGNode {
        var edges: [VSVGNode] = []

        for edge in graph.edges {
            if let keep = keepSet, !keep.contains(edge) { continue }

            let edgeLayout = try? graph.get(edge: edge.id, attribute: Attributes.Edge.layoutData)
            var children: [VSVGNode] = []

            if let layout = edgeLayout, !layout.splinePoints.isEmpty {
                let svgPath = SVGRenderQueries.splinePath(layout.splinePoints, logger: logger)
                let edgeFallback = SemanticColor.edge.resolve(darkMode: darkMode)
                let strokeColor: VColor
                if let arrowHeadColor = layout.arrowHead?.color {
                    strokeColor = SVGThemeColor.edge(arrowHeadColor, darkMode: darkMode)
                } else if let colorStr = layout.color {
                    strokeColor = SVGThemeColor.edge(colorStr, darkMode: darkMode)
                } else {
                    strokeColor = edgeFallback
                }

                let strokeWidth = layout.penwidth ?? 1.0

                var strokeDashArray: String? = nil
                if let style = layout.style {
                    switch style.lowercased() {
                    case "dashed": strokeDashArray = "5,5"
                    case "dotted": strokeDashArray = "2,2"
                    default: strokeDashArray = nil
                    }
                }

                children.append(
                    VSVGBuilder.path(
                        d: svgPath,
                        style: VShapeStyle(stroke: strokeColor, strokeWidth: strokeWidth, strokeDashArray: strokeDashArray)))

                let dir = (try? graph.get(edge: edge.id, attribute: Attributes.Edge.dir))?.lowercased() ?? "forward"
                let drawHead = (dir == "forward" || dir == "both")
                let drawTail = (dir == "back" || dir == "both")

                if drawHead, let arrowHead = layout.arrowHead {
                    children.append(
                        renderShape(arrowHead.shape, color: SVGThemeColor.edge(arrowHead.color, darkMode: darkMode)))
                }
                if drawTail, let arrowTail = layout.arrowTail {
                    children.append(
                        renderShape(arrowTail.shape, color: SVGThemeColor.edge(arrowTail.color, darkMode: darkMode)))
                }

                children.append(renderEdgeLabel(layout.label, darkMode: darkMode))
                children.append(renderEdgeEndLabel(layout.headLabel, darkMode: darkMode))
                children.append(renderEdgeEndLabel(layout.tailLabel, darkMode: darkMode))

                // Last, so a handle sits above the line and the mark it overlaps.
                if interactive, let first = layout.splinePoints.first,
                    let last = layout.splinePoints.last
                {
                    children.append(
                        renderEndHandle(
                            graph: graph, edge: edge, end: .from, at: first, color: strokeColor,
                            darkMode: darkMode))
                    children.append(
                        renderEndHandle(
                            graph: graph, edge: edge, end: .to, at: last, color: strokeColor,
                            darkMode: darkMode))
                }
            } else {
                logger.warn("[EdgeRenderer] Edge \(edge.id): Using fallback straight line")
                if let fromPos = try? graph.get(node: edge.from, attribute: Attributes.Node.layoutedPos),
                    let toPos = try? graph.get(node: edge.to, attribute: Attributes.Node.layoutedPos)
                {
                    children.append(
                        VSVGBuilder.path(
                            d: "M \(fromPos.x) \(fromPos.y) L \(toPos.x) \(toPos.y)",
                            style: VShapeStyle(stroke: SemanticColor.edge.resolve(darkMode: darkMode), strokeWidth: 1)))
                }
            }

            // Guarded, not just appended: an edge with neither a layout nor a badge
            // has to stay absent, and an array holding one `.empty` is not empty.
            if let anchor = SVGRenderQueries.badgeAnchor(for: edge, layout: edgeLayout, in: graph) {
                let badge = VSVGURLBadge.render(
                    url: graph.url(of: .edge(edge.id)), centerX: anchor.x, centerY: anchor.y, darkMode: darkMode)
                if !badge.isEmpty { children.append(badge) }
            }

            if !children.isEmpty {
                edges.append(
                    graph.bundledEdgeIds(of: edge.id).isEmpty
                        ? VSVGBuilder.group(
                            id: SVGElementId.edge(edge.id.id), cssClass: SVGElementId.edgeClass, children: children)
                        : renderBundle(edge, in: graph, children: children))
            }
        }

        logger.log("[EdgeRenderer] Rendered \(graph.edges.count) edges")
        return .fragment(edges)
    }

    /// Its members on hover, and what it unfolds on right-click, because a bundle
    /// has no label, type or ends of its own to act on (ADR-0027).
    private static func renderBundle(_ edge: Edge, in graph: VGraph, children: [VSVGNode]) -> VSVGNode {
        let members: String = (try? graph.get(edge: edge.id, attribute: Attributes.Edge.bundleMembers)) ?? ""
        let unfolds = [edge.from, edge.to].filter { SVGElementId.isFoldedGroup($0, in: graph) }.map { $0.id }
        return .element(
            .g,
            [
                VSVGAttribute("id", SVGElementId.edge(edge.id.id)),
                VSVGAttribute("class", "\(SVGElementId.edgeClass) \(SVGElementId.edgeBundleClass)"),
                VSVGAttribute(SVGElementId.unfoldsAttribute, unfolds.joined(separator: " ")),
            ],
            [.element(.title, [], [.text(members)])] + children)
    }
}
