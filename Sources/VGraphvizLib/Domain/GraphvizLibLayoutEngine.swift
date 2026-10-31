// Adapter that computes Graphviz layout in-process using the swiftGraphviz C library.

import GraphvizBridge
import SwiftGraphviz
import VGraph

#if !os(WASI)
    import Foundation  // DispatchQueue — not available (or needed) in embedded wasm
#endif

#if !os(WASI)
    /// Serial queue protecting the non-thread-safe Graphviz C library. Process-global
    /// (a file-level `let`, not a static member — generic types can't have stored
    /// statics) so all engine instances share one queue: the C library uses shared
    /// static state (parser, gvContext). Embedded wasm is single-threaded, so it is
    /// not compiled there.
    private let graphvizLibQueue = DispatchQueue(label: "com.vgraph.graphviz-lib")
#endif

/// In-process Graphviz layout engine using the swiftGraphviz C library.
public struct GraphvizLibLayoutEngine<Logger: ForLogMessages>: ForLayoutAGraph {

    /// Logger used to surface anomalies in the input DOT (e.g. edges without an
    /// `id` attribute, which we cannot key layout data for).
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    // No-argument convenience (silent logging) — used by tests.
    // (Defined below as a constrained extension so `Logger` is inferred.)

    // MARK: - ForLayoutAGraph

    /// The DOT round-trip: export the graph to DOT, let Graphviz lay it out,
    /// apply the resulting geometry back onto the graph.
    ///
    /// This is the only place that knows layout here happens *via DOT*. The
    /// port (`ForLayoutAGraph`) is stated at the graph level, so callers never
    /// see the interchange format.
    public func layout(graph: VGraph) throws(VError) -> VGraph {
        let dotSource = try DotExporter().export(graph: graph)
        logger.debug("[GraphvizLibLayoutEngine] === DOT Output ===")
        logger.debug(dotSource)

        let engine: String = (try? graph.get(graphAttribute: Attributes.Group.layoutEngine)) ?? "dot"
        let layoutData = try computeLayout(dot: dotSource, engine: engine)

        return try applyLayoutData(layoutData, to: graph, logger: logger)
    }

    // MARK: - Layout computation

    /// Lay out a DOT source directly. Public because the layout-extraction
    /// tests drive it with hand-written DOT; `layout(graph:)` is the path
    /// production code takes.
    public func computeLayout(dot: String, engine: String) throws(VError) -> GraphLayoutData {
        #if os(WASI)
            // Single-threaded wasm: call directly, no serialization needed.
            return try extractLayout(dot: dot, engine: engine)
        #else
            // Dispatch synchronously to serialize access to the C library.
            let result: Result<GraphLayoutData, VError> = graphvizLibQueue.sync {
                do {
                    let data = try extractLayout(dot: dot, engine: engine)
                    return .success(data)
                } catch let error as VError {
                    return .failure(error)
                } catch {
                    // Unreachable (extractLayout only throws VError) but required:
                    // typed-throws catch narrowing does not apply inside this closure.
                    return .failure(.externalError("Graphviz layout failed: \(error)"))
                }
            }
            switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            }
        #endif
    }

    // MARK: - Private

    private func extractLayout(dot: String, engine: String) throws(VError) -> GraphLayoutData {
        guard let graph = agmemread(dot) else {
            throw VError.externalError("Failed to parse DOT source")
        }
        defer { agclose(graph) }

        let layoutResult = gvLayout(gblGVContext, graph, engine)
        guard layoutResult == 0 else {
            throw VError.externalError("Graphviz layout failed with code \(layoutResult)")
        }
        defer { gvFreeLayout(gblGVContext, graph) }

        let bb = gd_bb(graph)
        let graphHeight = bb.UR.y

        let nodePositions = extractNodePositions(graph: graph, graphHeight: graphHeight)
        let edgeLayouts = extractEdgeLayouts(graph: graph, graphHeight: graphHeight)
        let groupLayouts = extractGroupLayouts(graph: graph, graphHeight: graphHeight)
        let (graphLabelPosition, graphLabelSize) = extractGraphLabel(
            graph: graph, graphHeight: graphHeight
        )

        // Top-level graph bounding box (encloses everything Graphviz drew,
        // including edge splines and arrowheads). Y-flipped to match the rest
        // of the layout data. After flipping, the box becomes (LL.x, 0, UR.x, UR.y - LL.y).
        let graphBoundingBox = VRect(
            origin: VPoint(x: bb.LL.x, y: 0),
            size: VSize(width: bb.UR.x - bb.LL.x, height: bb.UR.y - bb.LL.y)
        )
        let rootLayout = GroupLayoutData(
            boundingBox: graphBoundingBox,
            labelPosition: graphLabelPosition,
            labelSize: graphLabelSize
        )

        return GraphLayoutData(
            nodePositions: nodePositions,
            edgeLayouts: edgeLayouts,
            rootLayout: rootLayout,
            groupLayouts: groupLayouts
        )
    }

    // MARK: - Node Extraction

    private func extractNodePositions(
        graph: UnsafeMutablePointer<Agraph_t>,
        graphHeight: Double
    ) -> [String: VPoint] {
        var positions: [String: VPoint] = [:]

        var node = agfstnode(graph)
        while let n = node {
            let name = String(cString: agnameof(n))
            let pos = n.pos
            positions[name] = VPoint(x: pos.x, y: graphHeight - pos.y)
            node = agnxtnode(graph, n)
        }

        return positions
    }

    // MARK: - Edge Extraction

    private func extractEdgeLayouts(
        graph: UnsafeMutablePointer<Agraph_t>,
        graphHeight: Double
    ) -> [String: EdgeLayoutData] {
        var layouts: [String: EdgeLayoutData] = [:]

        // Every edge is keyed by its DOT `id` attribute. Callers must emit an
        // id on every edge (DotExporter does this unconditionally) — edges
        // without one are skipped, since there is no stable key to use. When
        // this happens we warn so that hand-written DOT input doesn't silently
        // lose layout data.
        var node = agfstnode(graph)
        while let n = node {
            var edge = agfstout(graph, n)
            while let e = edge {
                if let key = getEdgeAttribute(e, name: "id") {
                    if let layout = extractSingleEdgeLayout(edge: e, graphHeight: graphHeight) {
                        layouts[key] = layout
                    }
                } else {
                    let tail = String(cString: agnameof(n))
                    logger.warn(
                        "[GraphvizLibLayoutEngine] Edge from '\(tail)' has no `id` attribute; layout data discarded. The exporter emits an id on every edge — this edge likely came from hand-written DOT."
                    )
                }
                edge = agnxtout(graph, e)
            }
            node = agnxtnode(graph, n)
        }

        return layouts
    }

    private func extractSingleEdgeLayout(
        edge: UnsafeMutablePointer<Agedge_t>,
        graphHeight: Double
    ) -> EdgeLayoutData? {
        guard let path = try? edge.getPath() else {
            return nil
        }

        let splinePoints = path.map { VPoint(x: $0.x, y: graphHeight - $0.y) }
        guard !splinePoints.isEmpty else { return nil }

        let arrowHead = extractArrowHead(
            edge: edge,
            splinePoints: splinePoints,
            isHead: true,
            graphHeight: graphHeight
        )

        let arrowTail = extractArrowHead(
            edge: edge,
            splinePoints: splinePoints,
            isHead: false,
            graphHeight: graphHeight
        )

        let color = getEdgeAttribute(edge, name: "color")
        let style = getEdgeAttribute(edge, name: "style")
        let penwidthStr = getEdgeAttribute(edge, name: "penwidth")
        let penwidth = penwidthStr.flatMap { Double($0) }

        let label = extractEdgeLabel(edge: edge, graphHeight: graphHeight)
        let headLabel = extractEdgeHeadLabel(edge: edge, graphHeight: graphHeight)
        let tailLabel = extractEdgeTailLabel(edge: edge, graphHeight: graphHeight)

        return EdgeLayoutData(
            splinePoints: splinePoints,
            arrowHead: arrowHead,
            arrowTail: arrowTail,
            color: color,
            style: style,
            penwidth: penwidth,
            label: label,
            headLabel: headLabel,
            tailLabel: tailLabel
        )
    }

    // MARK: - Arrow Synthesis

    /// Default arrow length in points (matching Graphviz default).
    /// Computed, not stored: generic types can't have stored static properties.
    private static var arrowLength: Double { 10.0 }
    private static var arrowHalfWidth: Double { 3.5 }

    private func extractArrowHead(
        edge: UnsafeMutablePointer<Agedge_t>,
        splinePoints: [VPoint],
        isHead: Bool,
        graphHeight: Double
    ) -> ArrowHeadData? {
        let shapeAttrName = isHead ? "arrowhead" : "arrowtail"
        let shapeName = (getEdgeAttribute(edge, name: shapeAttrName) ?? "normal").lowercased()
        if shapeName == "none" { return nil }

        let tipGV: GVPoint?
        if isHead {
            tipGV = edge.arrowHead
        } else {
            tipGV = edge.arrowTail
        }

        guard let rawTip = tipGV else { return nil }
        let tip = VPoint(x: rawTip.x, y: graphHeight - rawTip.y)

        let tangent: (dx: Double, dy: Double)
        if isHead {
            // Arrow at head: tangent points from second-to-last control point toward tip
            guard splinePoints.count >= 2 else { return nil }
            let prev = splinePoints[splinePoints.count - 2]
            let dx = tip.x - prev.x
            let dy = tip.y - prev.y
            let len = (dx * dx + dy * dy).squareRoot()
            guard len > 0.001 else { return nil }
            tangent = (dx / len, dy / len)
        } else {
            // Arrow at tail: tangent points from second control point toward tip
            guard splinePoints.count >= 2 else { return nil }
            let next = splinePoints[1]
            let dx = tip.x - next.x
            let dy = tip.y - next.y
            let len = (dx * dx + dy * dy).squareRoot()
            guard len > 0.001 else { return nil }
            tangent = (dx / len, dy / len)
        }

        let arrowColor = getEdgeAttribute(edge, name: "color") ?? "#000000"

        if shapeName == "dot" || shapeName == "odot" {
            let radius = Self.arrowLength / 2
            let center = VPoint(
                x: tip.x - tangent.dx * radius,
                y: tip.y - tangent.dy * radius
            )
            return ArrowHeadData(
                shape: .circle(center: center, radius: radius),
                color: arrowColor
            )
        }

        let perpDx = -tangent.dy
        let perpDy = tangent.dx

        let baseX = tip.x - tangent.dx * Self.arrowLength
        let baseY = tip.y - tangent.dy * Self.arrowLength

        let base1 = VPoint(
            x: baseX + perpDx * Self.arrowHalfWidth,
            y: baseY + perpDy * Self.arrowHalfWidth
        )
        let base2 = VPoint(
            x: baseX - perpDx * Self.arrowHalfWidth,
            y: baseY - perpDy * Self.arrowHalfWidth
        )

        return ArrowHeadData(
            shape: .polygon(points: [tip, base1, base2]),
            color: arrowColor
        )
    }

    // MARK: - Label Extraction

    private func extractEdgeLabel(
        edge: UnsafeMutablePointer<Agedge_t>,
        graphHeight: Double
    ) -> LabelData? {
        guard let text = edge.labelText,
            let pos = edge.labelPos
        else { return nil }
        return LabelData(
            text: text,
            position: VPoint(x: pos.x, y: graphHeight - pos.y)
        )
    }

    private func extractEdgeHeadLabel(
        edge: UnsafeMutablePointer<Agedge_t>,
        graphHeight: Double
    ) -> LabelData? {
        guard let text = edge.headLabelText,
            let pos = edge.headLabelPos
        else { return nil }
        return LabelData(
            text: text,
            position: VPoint(x: pos.x, y: graphHeight - pos.y)
        )
    }

    private func extractEdgeTailLabel(
        edge: UnsafeMutablePointer<Agedge_t>,
        graphHeight: Double
    ) -> LabelData? {
        guard let text = edge.tailLabelText,
            let pos = edge.tailLabelPos
        else { return nil }
        return LabelData(
            text: text,
            position: VPoint(x: pos.x, y: graphHeight - pos.y)
        )
    }

    // MARK: - Group/Cluster Extraction

    private func extractGroupLayouts(
        graph: UnsafeMutablePointer<Agraph_t>,
        graphHeight: Double
    ) -> [String: GroupLayoutData] {
        var groupLayouts: [String: GroupLayoutData] = [:]
        extractSubgraphs(graph: graph, graphHeight: graphHeight, into: &groupLayouts)
        return groupLayouts
    }

    private func extractSubgraphs(
        graph: UnsafeMutablePointer<Agraph_t>,
        graphHeight: Double,
        into layouts: inout [String: GroupLayoutData]
    ) {
        var subgraph = agfstsubg(graph)
        while let sg = subgraph {
            let name = String(cString: agnameof(sg))

            if name.hasPrefix("cluster_") {
                let groupId = String(name.dropFirst("cluster_".count))

                let rect = sg.rect
                let flippedOrigin = VPoint(
                    x: rect.origin.x,
                    y: graphHeight - rect.origin.y - rect.size.height
                )
                let boundingBox = VRect(
                    origin: flippedOrigin,
                    size: VSize(width: rect.size.width, height: rect.size.height)
                )

                let labelPosition: VPoint?
                if let lp = sg.labelPos {
                    labelPosition = VPoint(x: lp.x, y: graphHeight - lp.y)
                } else {
                    labelPosition = nil
                }

                let labelSize: VSize?
                if let ls = sg.labelSize {
                    labelSize = VSize(width: ls.width, height: ls.height)
                } else {
                    labelSize = nil
                }

                layouts[groupId] = GroupLayoutData(
                    boundingBox: boundingBox,
                    labelPosition: labelPosition,
                    labelSize: labelSize
                )
            }

            extractSubgraphs(graph: sg, graphHeight: graphHeight, into: &layouts)

            subgraph = agnxtsubg(sg)
        }
    }

    // MARK: - Graph Label Extraction

    private func extractGraphLabel(
        graph: UnsafeMutablePointer<Agraph_t>,
        graphHeight: Double
    ) -> (VPoint?, VSize?) {
        guard gd_label(graph) != nil else {
            return (nil, nil)
        }

        let labelPosition: VPoint?
        if let lp = gd_lp(graph) {
            labelPosition = VPoint(x: lp.pointee.x, y: graphHeight - lp.pointee.y)
        } else {
            labelPosition = nil
        }

        let labelSize: VSize?
        if let ls = gd_lsize(graph) {
            let size = GVSize(gvPoint: ls.pointee)
            if let s = size.convertZeroToNil() {
                labelSize = VSize(width: s.width, height: s.height)
            } else {
                labelSize = nil
            }
        } else {
            labelSize = nil
        }

        return (labelPosition, labelSize)
    }

    // MARK: - Attribute Helpers

    private func getEdgeAttribute(
        _ edge: UnsafeMutablePointer<Agedge_t>,
        name: String
    ) -> String? {
        let cName = strdup(name)
        defer { free(cName) }
        guard let value = agget(edge, cName) else { return nil }
        let str = String(cString: value)
        return str.isEmpty ? nil : str
    }
}

extension GraphvizLibLayoutEngine where Logger == NoOpLogger {
    /// Convenience that logs nothing. `Logger` is inferred as `NoOpLogger`;
    /// the exporter still has to be supplied, since this module deliberately
    /// does not know which one exists. Used by tests.
    public init() {
        self.init(logger: NoOpLogger())
    }
}
