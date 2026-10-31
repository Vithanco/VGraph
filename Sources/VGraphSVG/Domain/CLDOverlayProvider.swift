////
////  CLDOverlayProvider.swift
////  VGraphSVG
////
////  Overlay for the Causal Loop Diagram notation. Renders the reinforcing/
////  balancing loop indicators (R/B arcs with arrowheads) that mark each
////  detected cycle's rotation direction.
////
////  Note on analysis location: the architectural plan calls for CycleAnalysis
////  to move into the layout pipeline (stamped as a graph attribute). That
////  would require `AttributeType` conformance on `[TLoop]` (~100 lines of
////  serialization ceremony). Since CycleAnalysis is microseconds for typical
////  CLD graphs, this provider computes inline instead, calling
////  `CycleAnalysis.analyze` and `TLoop.fromCycles` each render. A future
////  refactor can move analysis upstream once a second consumer justifies the
////  ceremony.
////

import VGraph

public struct CLDOverlayProvider: NotationOverlayProvider {

    public init() {}

    public var notationName: String { Notations.CausalLoopDiagram.id.id }

    private static let indicatorSize: Double = 40.0

    // MARK: - Render slot (above nodes, beneath label)

    public func renderBetweenNodesAndLabel(ctx: RenderContext) throws(VError) -> VSVGNode {
        let indicators = computeIndicators(graph: ctx.graph)
        guard !indicators.isEmpty else { return .empty }

        let size = Self.indicatorSize
        let r = size * 0.43
        let sw = size * 0.055
        let ah = sw * 4.2
        let aw = sw * 3.2
        let fontSize = size * 0.44
        let textOffsetY = size * 0.16

        let color = SemanticColor.loopIndicator.resolve(darkMode: ctx.darkMode).hexString

        let cos30 = 0.8660254037844387
        let sin30 = 0.5

        var children: [VSVGNode] = []
        for indicator in indicators {
            let cx = indicator.center.x
            let cy = indicator.center.y
            let clockwise = indicator.clockwise

            let sx = clockwise ? cx + r * cos30 : cx - r * cos30
            let sy = cy + r * sin30
            let ex = cx
            let ey = cy - r
            let sweepFlag = clockwise ? 1 : 0

            // Tangent at top: CW → (1,0) so rotate −90°; CCW → (−1,0) so rotate +90°.
            let arrowRotDeg = clockwise ? -90.0 : 90.0
            let arrowTx = clockwise ? ex + ah : ex - ah
            let arrowTy = ey

            // Transparent hit disc so the whole circle (not just the thin arc) is
            // hoverable — the arc itself is `fill="none"` and would ignore the centre.
            let hitDisc: VSVGNode = .element(
                .circle,
                [
                    VSVGAttribute("cx", "\(cx)"), VSVGAttribute("cy", "\(cy)"), VSVGAttribute("r", "\(r)"),
                    VSVGAttribute("fill", "transparent"), VSVGAttribute("pointer-events", "all"),
                ])
            let arc: VSVGNode = .element(
                .path,
                [
                    VSVGAttribute("d", "M \(sx),\(sy) A \(r),\(r) 0 1,\(sweepFlag) \(ex),\(ey)"),
                    VSVGAttribute("fill", "none"), VSVGAttribute("stroke", color),
                    VSVGAttribute("stroke-width", "\(sw)"), VSVGAttribute("stroke-linecap", "round"),
                ])
            let arrow: VSVGNode = .element(
                .g,
                [VSVGAttribute("transform", "translate(\(arrowTx),\(arrowTy)) rotate(\(arrowRotDeg))")],
                [
                    .element(
                        .path,
                        [
                            VSVGAttribute("d", "M 0,0 L \(-aw / 2),\(-ah) L \(aw / 2),\(-ah) Z"),
                            VSVGAttribute("fill", color),
                        ])
                ])
            // Its own font-family, not `VFont.svgName`: the indicator letter asks
            // for bare "DM Sans, sans-serif" where node labels quote the family.
            let letter: VSVGNode = .element(
                .text,
                [
                    VSVGAttribute("x", "\(cx)"), VSVGAttribute("y", "\(cy + textOffsetY)"),
                    VSVGAttribute("text-anchor", "middle"),
                    VSVGAttribute("font-family", "DM Sans, sans-serif"),
                    VSVGAttribute("font-size", "\(fontSize)"), VSVGAttribute("font-weight", "800"),
                    VSVGAttribute("fill", color),
                ],
                [.text(indicator.letter)])

            children.append(
                .element(
                    .g,
                    [VSVGAttribute("id", indicator.id), VSVGAttribute("class", "loop-indicator")],
                    (indicator.note.map { [VSVGNode.element(.title, [], [.text($0)])] } ?? [])
                        + [hitDisc, arc, arrow, letter]))
        }
        return .fragment(children)
    }

    // MARK: - Hover contribution

    public func hoverStyleRules(graph: VGraph) -> String {
        var rules = ""
        for loop in graph.loopsToMark where loop.loopStyle != .none {
            guard loop.loopDirection(in: graph) != .error else { continue }
            let indicatorId = Self.loopId(loop)
            rules += SVGBuilder.neighborGlowRule(
                scope: "svg:has(#\(SVGBuilder.cssEscapeIdent(indicatorId)):hover) ",
                edgeIds: loop.edges.map { $0.id.id },
                nodeElementIds: loop.nodes.map { SVGElementId.displayNode($0, in: graph) },
                rawIds: [indicatorId])
        }
        return rules
    }

    /// Content-derived so the drawn indicator's `id` and its generated `:has(#…)`
    /// rule agree without depending on iteration order.
    private static func loopId(_ loop: TLoop) -> String {
        "loop-" + loop.edges.map { $0.id.id }.sorted().joined(separator: "-")
    }

    // MARK: - Bounds contribution

    /// Each indicator gets a 40×40 box around its centroid folded into the
    /// viewbox so near-edge cycles aren't clipped (matches the pre-migration
    /// SVGRenderer behavior).
    public func boundsContributions(graph: VGraph) -> [VRect] {
        let indicators = computeIndicators(graph: graph)
        let size = Self.indicatorSize
        return indicators.map { indicator in
            VRect(
                x: indicator.center.x - size / 2,
                y: indicator.center.y - size / 2,
                width: size,
                height: size
            )
        }
    }

    // MARK: - Private indicator model + computation

    private struct LoopIndicator {
        let clockwise: Bool
        let letter: String
        let center: VPoint
        let id: String
        /// A tooltip, for a marker whose letter needs explaining.
        let note: String?
    }

    /// Compute loop indicators for the graph's cycles. Returns empty for
    /// graphs with no cycles (or no styled cycles). Verbatim port of the
    /// pre-migration `computeLoopIndicators` from SVGRenderer.
    private func computeIndicators(graph: VGraph) -> [LoopIndicator] {
        let loops = graph.loopsToMark
        var indicators: [LoopIndicator] = []

        for loop in loops {
            let direction = loop.loopDirection(in: graph)
            guard direction != .error else { continue }
            guard loop.loopStyle != .none else { continue }

            var sumX = 0.0
            var sumY = 0.0
            var count = 0
            for node in loop.nodes {
                guard let pos: VPoint = try? graph.get(node: node, attribute: Attributes.Node.layoutedPos)
                else { continue }
                sumX += pos.x
                sumY += pos.y
                count += 1
            }
            guard count > 0 else { continue }

            let centroid = VPoint(x: sumX / Double(count), y: sumY / Double(count))

            let clockwise: Bool
            switch direction {
            case .clockwise: clockwise = true
            case .counterClockwise: clockwise = false
            case .error: continue
            }

            let letter: String
            switch loop.loopStyle {
            case .balancing: letter = "B"
            case .reinforcing: letter = "R"
            case .ambiguous: letter = "?"
            case .none: continue
            }

            indicators.append(
                LoopIndicator(
                    clockwise: clockwise, letter: letter, center: centroid, id: Self.loopId(loop),
                    note: loop.ambiguousLinks.isEmpty
                        ? nil
                        : "Polarity unknown: \(loop.ambiguousLinks.joined(separator: ", ")) is drawn with both polarities"
                ))
        }
        return indicators
    }
}
