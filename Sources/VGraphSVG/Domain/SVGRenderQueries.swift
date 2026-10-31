// What both SVG backends read out of a laid-out graph. ADR-0015 accepts two
// *rendering* backends; nothing here emits markup, so one copy serves both and
// the string path and the IR path cannot drift on what they think the graph says.

import VGraph

enum SVGRenderQueries {

    /// An accumulator, not a `VRect`: overlay contributions are folded in by
    /// widening min/max, so an untouched box has to start at ±infinity for the
    /// first contribution to win.
    struct Bounds {
        var minX: Double = Double.infinity
        var minY: Double = Double.infinity
        var maxX: Double = -Double.infinity
        var maxY: Double = -Double.infinity
    }

    /// Reads the root graph's bounding box, populated by the layout step from
    /// Graphviz's top-level `bb` (which already encloses every drawn element:
    /// nodes, edge splines, arrowheads, labels, clusters). Loop indicators,
    /// which the renderer adds itself, are folded in by the caller.
    static func calculateBounds(graph: VGraph) -> Bounds {
        var bounds = Bounds()
        let rootGrp = Group(rawValue: rootGroup)
        if let rootBounds = try? graph.get(group: rootGrp, attribute: Attributes.Group.layoutedBounds),
            rootBounds != VRect.zero
        {
            bounds.minX = rootBounds.minX
            bounds.minY = rootBounds.minY
            bounds.maxX = rootBounds.maxX
            bounds.maxY = rootBounds.maxY
        }
        return bounds
    }

    /// Resolved here because this is the last place holding the graph, and only
    /// the graph knows whether a name means the notation's artwork or a built-in.
    static func collectIcons(from graph: VGraph) -> [String: IconArtwork] {
        var icons: [String: IconArtwork] = [:]
        var styles: [NodeStyleLayout] = []
        for nodeType in graph.usedNodeTypes {
            if let style = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.style) {
                styles.append(style)
            }
        }
        // A node's own style (an Equals node painted by its evaluation) can name icons
        // its type's style does not.
        for node in graph.nodes {
            if let style = try? graph.get(node: node, attribute: Attributes.Node.style) {
                styles.append(style)
            }
        }
        for style in styles {
            for name in style.extractIcons() {
                icons[name] = graph.artwork(forIcon: name) ?? .missing
            }
        }
        return icons
    }

    static func collectNodeRects(graph: VGraph) -> [VRect] {
        var rects: [VRect] = []
        for node in graph.nodes {
            if let pos = try? graph.get(node: node, attribute: Attributes.Node.layoutedPos) {
                let size: VSize = (try? graph.get(node: node, attribute: Attributes.Node.layoutedSize)) ?? .zero
                rects.append(
                    VRect(
                        x: pos.x - size.width / 2, y: pos.y - size.height / 2,
                        width: size.width, height: size.height))
            }
        }
        return rects
    }

    /// Every label drawn for a group, the diagram's own included, so watermark
    /// placement can keep clear of them.
    static func collectGroupLabelRects(graph: VGraph) -> [VRect] {
        let groupLabels = graph.groups.compactMap { VSVGGroup.labelRect(of: $0, in: graph) }
        guard let graphLabel = graphLabelRect(graph: graph) else { return groupLabels }
        return [graphLabel] + groupLabels
    }

    // The diagram's label is drawn at Graphviz's label position (renderGraphLabel);
    // `graph.groups` leaves the root out, so it is collected on its own.
    private static func graphLabelRect(graph: VGraph) -> VRect? {
        let root = Group(rawValue: rootGroup)
        guard let labelPos = try? graph.get(group: root, attribute: Attributes.Group.labelLayoutedPos),
            labelPos != VPoint.zero,
            let labelSize = try? graph.get(group: root, attribute: Attributes.Group.labelLayoutedSize),
            labelSize != VSize.zero
        else { return nil }
        return VRect(
            x: labelPos.x - labelSize.width / 2, y: labelPos.y - labelSize.height / 2,
            width: labelSize.width, height: labelSize.height)
    }

    /// `nil` when the overlay filtered nothing out, which lets the caller take
    /// the plain path and skip a set lookup per element — the common case, since
    /// most notations filter nothing.
    static func keepSet<Element: Hashable>(
        _ all: Set<Element>, filteredTo kept: Set<Element>
    ) -> Set<Element>? {
        kept.count == all.count ? nil : kept
    }

    static func badgeAnchor(for edge: Edge, layout: EdgeLayoutData?, in graph: VGraph) -> VPoint? {
        if let points = layout?.splinePoints, !points.isEmpty {
            return points[points.count / 2]
        }
        guard let fromPos = try? graph.get(node: edge.from, attribute: Attributes.Node.layoutedPos),
            let toPos = try? graph.get(node: edge.to, attribute: Attributes.Node.layoutedPos)
        else { return nil }
        return VPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
    }

    /// Graphviz B-splines carry 3n+1 control points: point 0 is the start, then
    /// groups of 3 per cubic Bezier segment.
    static func splinePath<Logger: ForLogMessages>(_ points: [VPoint], logger: Logger) -> String {
        guard points.count >= 4 else { return "" }
        guard (points.count - 1) % 3 == 0 else {
            logger.warn("[EdgeRenderer] Invalid B-spline point count: \(points.count), expected 3n+1")
            return ""
        }

        var svgPath = "M \(points[0].x) \(points[0].y)"
        var i = 1
        while i + 2 < points.count {
            let cp1 = points[i]
            let cp2 = points[i + 1]
            let end = points[i + 2]
            svgPath += " C \(cp1.x) \(cp1.y), \(cp2.x) \(cp2.y), \(end.x) \(end.y)"
            i += 3
        }
        return svgPath
    }
}

extension NodeStyleLayout {
    /// Always `.zero` today, and deliberately kept: real text size comes from
    /// `NodeTextDimensionStep` via `Attributes.Node.nodeTextSize`, and the font
    /// is not in the layout, so `.nodeText` has nothing to measure with. The walk
    /// stays as the seam a future in-layout measurement would fill in.
    func fallbackTextSize() -> VSize {
        switch self {
        case .nodeText:
            return .zero
        case .padded(_, let innerLayout), .background(_, let innerLayout), .sized(_, let innerLayout):
            return innerLayout.fallbackTextSize()
        case .vertical(let layouts, _), .horizontal(let layouts, _):
            for innerLayout in layouts {
                let size = innerLayout.fallbackTextSize()
                if size != .zero { return size }
            }
            return .zero
        case .overlay(let base, _):
            return base.fallbackTextSize()
        default:
            return .zero
        }
    }
}
