////
////  TimelineOverlayProvider.swift
////  VGraphSVG
////
////  Overlay for the Timeline notation. Replaces the boxed-node visual that
////  TimePoints used to have with an axis-and-guide treatment:
////
////    - A horizontal axis baseline connects all TimePoint X positions.
////    - A small filled dot sits at each TimePoint.
////    - The year label appears centered beneath the dot.
////    - A dashed vertical guide descends from each TimePoint to the diagram
////      bottom, visually anchoring events that share its alignGroup.
////
////  The provider also drops TimePoint nodes and sequence edges from the
////  standard render pipeline, since they're now drawn by this overlay.
////
////  Spec: Diagram Style Guide §02 / §05 / §11 — Timeline column-guide treatment.
////

import VGraph

public struct TimelineOverlayProvider: NotationOverlayProvider {

    public init() {}

    public var notationName: String { Notations.Timeline.id.id }

    // MARK: - Tokens
    //
    // Overlay-renderer internals. Not promoted to the global SemanticColor
    // catalog because they're consumed only here. Opacity is written as a
    // literal attribute rather than going through `VShapeStyle`, which derives
    // it from a colour's alpha — and SemanticColor doesn't model alpha today.

    private static let axisColor = SemanticColor(
        id: "timeline.axis", lightHex: "#5a564e", darkHex: "#a8a49a")
    private static let guideColor = SemanticColor(
        id: "timeline.guide", lightHex: "#5a564e", darkHex: "#a8a49a")
    private static let yearLabelColor = SemanticColor(
        id: "timeline.year", lightHex: "#18160f", darkHex: "#ecebe5")

    // Per-mode opacities. Spec §03.
    private static let axisAlpha: (light: Double, dark: Double) = (0.50, 0.50)
    private static let guideAlpha: (light: Double, dark: Double) = (0.35, 0.30)

    // MARK: - Filters

    public func filterNodes(_ nodes: Set<Node>, graph: VGraph) -> Set<Node> {
        let tpType = Notations.Timeline.NodeTypes.timePoint
        return nodes.filter { node in
            // Keep nodes whose type is NOT TimePoint. Nodes with unknown type
            // (try? fails) default to "keep" — safer than silent dropping.
            (try? graph.nodeType(for: node)) != tpType
        }
    }

    public func filterEdges(_ edges: Set<Edge>, graph: VGraph) -> Set<Edge> {
        let sequenceType = Notations.Timeline.EdgeTypes.sequence
        return edges.filter { edge in
            guard let et = try? graph.edgeType(for: edge) else { return true }
            return et.id != sequenceType.id
        }
    }

    // MARK: - Bounds

    // All overlay drawing stays inside the natural graph bbox (axis at
    // timepoint Y, guides terminate at bbBottom-16). No contribution needed.

    // MARK: - Render slots

    /// Slot 1: dashed vertical guides descending from each TimePoint to the
    /// diagram bottom. Drawn beneath groups so they read as a structural
    /// backdrop, slightly muted where group fills cover them.
    public func renderBetweenDefsAndGroups(ctx: RenderContext) throws(VError) -> VSVGNode {
        guard let layout = timelineLayout(graph: ctx.graph) else { return .empty }
        let color = Self.guideColor.resolve(darkMode: ctx.darkMode)
        let alpha = ctx.darkMode ? Self.guideAlpha.dark : Self.guideAlpha.light

        // Spec §05.
        let guides: [VSVGNode] = layout.timepoints.map { tp in
            .element(
                .line,
                [
                    VSVGAttribute("x1", format(tp.cx)), VSVGAttribute("y1", format(layout.axisY + 10)),
                    VSVGAttribute("x2", format(tp.cx)), VSVGAttribute("y2", format(layout.bbBottom - 16)),
                    VSVGAttribute("stroke", color.hexString), VSVGAttribute("stroke-width", "1"),
                    VSVGAttribute("stroke-opacity", format(alpha)),
                    VSVGAttribute("stroke-dasharray", "2,4"),
                ])
        }
        return .fragment(guides)
    }

    /// Slot 2: the axis baseline + anchor dots + year labels. Drawn above
    /// groups (so anchors read as the top-level coordinate system) and below
    /// edges.
    public func renderBetweenGroupsAndEdges(ctx: RenderContext) throws(VError) -> VSVGNode {
        guard let layout = timelineLayout(graph: ctx.graph) else { return .empty }
        let axisColor = Self.axisColor.resolve(darkMode: ctx.darkMode)
        let axisAlpha = ctx.darkMode ? Self.axisAlpha.dark : Self.axisAlpha.light
        let yearColor = Self.yearLabelColor.resolve(darkMode: ctx.darkMode)

        var children: [VSVGNode] = []

        // Baseline — only when more than one TimePoint exists. Per spec §06,
        // single-TimePoint timelines skip the baseline (degenerate).
        if layout.timepoints.count > 1 {
            let xs = layout.timepoints.map { $0.cx }
            let minX = xs.min()!
            let maxX = xs.max()!
            children.append(
                .element(
                    .line,
                    [
                        VSVGAttribute("x1", format(minX - 20)), VSVGAttribute("y1", format(layout.axisY)),
                        VSVGAttribute("x2", format(maxX + 20)), VSVGAttribute("y2", format(layout.axisY)),
                        VSVGAttribute("stroke", axisColor.hexString), VSVGAttribute("stroke-width", "1"),
                        VSVGAttribute("stroke-opacity", format(axisAlpha)),
                    ]))
        }

        let labelFont = VFont(family: .dmSans, size: 12)
        for tp in layout.timepoints {
            // Dot (r=3, fully opaque token color — alpha applied via stroke-opacity equivalent).
            children.append(
                .element(
                    .circle,
                    [
                        VSVGAttribute("cx", format(tp.cx)), VSVGAttribute("cy", format(layout.axisY)),
                        VSVGAttribute("r", "3"), VSVGAttribute("fill", axisColor.hexString),
                        VSVGAttribute("fill-opacity", format(axisAlpha)),
                    ]))
            // Year label — 14px below the dot per spec, anchor middle, DM Sans 12/500.
            children.append(
                VSVGBuilder.text(
                    x: tp.cx,
                    y: layout.axisY + 22,
                    content: tp.label,
                    font: labelFont,
                    color: yearColor,
                    anchor: "middle",
                    fontWeight: 500
                ))
        }
        return .fragment(children)
    }

    // MARK: - Shared timepoint lookup

    private struct TimepointLayout {
        let timepoints: [TimePoint]
        let axisY: Double
        let bbBottom: Double
    }

    private struct TimePoint {
        let cx: Double
        let label: String  // joined wrappedText
    }

    /// Read TimePoint nodes inline. Cheap (≪1ms for typical graphs); called
    /// twice per render (once per slot method). No precompute / no caching.
    private func timelineLayout(graph: VGraph) -> TimepointLayout? {
        let tpType = Notations.Timeline.NodeTypes.timePoint
        var rawPoints: [(cx: Double, cy: Double, label: String)] = []
        for node in graph.nodes {
            guard (try? graph.nodeType(for: node)) == tpType,
                let pos = try? graph.get(node: node, attribute: Attributes.Node.layoutedPos)
            else { continue }
            let wrapped =
                (try? graph.get(node: node, attribute: Attributes.Node.wrappedText)) ?? []
            let label = wrapped.joined(separator: " ")
            rawPoints.append((cx: pos.x, cy: pos.y, label: label))
        }
        guard !rawPoints.isEmpty else { return nil }

        // Sort by X so the baseline draws left-to-right.
        rawPoints.sort { $0.cx < $1.cx }

        // Spec §06: use median Y for the axis baseline (defensive against
        // unaligned timepoints). For correctly-aligned timelines, every cy
        // is identical and the median equals any element.
        let sortedYs = rawPoints.map { $0.cy }.sorted()
        let axisY = sortedYs[sortedYs.count / 2]

        let rootGrp = Group(rawValue: rootGroup)
        let bbBottom: Double =
            (try? graph.get(group: rootGrp, attribute: Attributes.Group.layoutedBounds))?.maxY
            ?? axisY

        let timepoints = rawPoints.map { TimePoint(cx: $0.cx, label: $0.label) }
        return TimepointLayout(timepoints: timepoints, axisY: axisY, bbBottom: bbBottom)
    }

    // MARK: - Local helpers

    private func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return "\(value)"
    }
}
