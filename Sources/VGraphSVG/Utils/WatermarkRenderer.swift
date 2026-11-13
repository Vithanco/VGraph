import VGraph

/// Asset: the original V-mark + "VITHANCO.COM" text. Kept deliberately over
/// the v2 integrated logo, which is too wide for the corner watermark slot
/// and bakes the wordmark into path geometry (loses font + accessibility).
///
/// Fill comes from `SemanticColor.watermark` (`#c8c4bc` light / `#4a4842`
/// dark), resolved at emit time based on the renderer's `darkMode` flag.
struct WatermarkRenderer {

    private static let viewBoxWidth: Double = 162.12
    private static let viewBoxHeight: Double = 162.0

    /// The four corners to try, in priority order
    private enum Corner {
        case bottomLeft, bottomRight, topLeft, topRight
    }

    static let symbolId = "vithanco-watermark"

    private static let markPaths = [
        "M 121.68 34.67 L 94.40 81.89 L 81.07 104.96 L 101.28 139.95 L 114.61 116.88 L 162.12 34.67 Z",
        "M 81.07 58.81 L 95.01 34.67 L 121.68 34.67 L 141.72 0 L 115.05 0 L 47.07 0 L 20.40 0 L 40.44 34.67 L 67.11 34.67 Z",
        "M 40.44 34.67 L 0 34.67 L 47.51 116.88 L 60.84 139.96 L 81.07 104.96 L 67.73 81.89 Z",
    ]

    /// `darkMode` selects which side of the `SemanticColor.watermark` token to bake in.
    static func renderDefinition(darkMode: Bool = false) -> VSVGNode {
        let fill = SemanticColor.watermark.resolve(darkMode: darkMode).hexString
        var children: [VSVGNode] = markPaths.map { pathData in
            .element(.path, [VSVGAttribute("d", pathData), VSVGAttribute("fill", fill)])
        }
        children.append(
            .element(
                .text,
                [
                    VSVGAttribute("x", "9.13"), VSVGAttribute("y", "158.59"),
                    VSVGAttribute("font-family", "Arial"), VSVGAttribute("font-size", "18.67"),
                    VSVGAttribute("fill", fill),
                ],
                [.text("VITHANCO.COM")]))

        return .element(
            .symbol,
            [
                VSVGAttribute("id", symbolId),
                VSVGAttribute("viewBox", "0 0 \(viewBoxWidth) \(viewBoxHeight)"),
            ],
            children)
    }

    /// The first free corner of the diagram, tried bottom-left, bottom-right,
    /// top-left, top-right. With none free it goes below the diagram rather than
    /// over a node, so the caller must grow the canvas to include the result.
    static func placement(in diagram: VRect, avoiding avoidRects: [VRect]) -> VRect {
        // Cover 15% of the smaller dimension, but cap at 100px in either direction
        let targetSize = min(min(diagram.width, diagram.height) * 0.15, 100.0)

        let aspectRatio = self.viewBoxWidth / self.viewBoxHeight
        let scaledWidth: Double
        let scaledHeight: Double
        if aspectRatio > 1 {
            scaledWidth = targetSize
            scaledHeight = targetSize / aspectRatio
        } else {
            scaledHeight = targetSize
            scaledWidth = targetSize * aspectRatio
        }

        let margin = targetSize * 0.1
        let corners: [Corner] = [.bottomLeft, .bottomRight, .topLeft, .topRight]
        let candidates = corners.map { corner in
            let (x, y) = position(
                for: corner, margin: margin,
                scaledWidth: scaledWidth, scaledHeight: scaledHeight,
                viewBoxX: diagram.minX, viewBoxY: diagram.minY,
                viewBoxWidth: diagram.width, viewBoxHeight: diagram.height
            )
            return VRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        }
        if let free = candidates.first(where: { totalOverlapArea($0, avoidRects: avoidRects) == 0 }) {
            return free
        }
        return VRect(x: diagram.minX + margin, y: diagram.maxY + margin, width: scaledWidth, height: scaledHeight)
    }

    private static func position(
        for corner: Corner, margin: Double,
        scaledWidth: Double, scaledHeight: Double,
        viewBoxX: Double, viewBoxY: Double,
        viewBoxWidth: Double, viewBoxHeight: Double
    ) -> (Double, Double) {
        switch corner {
        case .bottomLeft:
            return (
                viewBoxX + margin,
                viewBoxY + viewBoxHeight - scaledHeight - margin
            )
        case .bottomRight:
            return (
                viewBoxX + viewBoxWidth - scaledWidth - margin,
                viewBoxY + viewBoxHeight - scaledHeight - margin
            )
        case .topLeft:
            return (
                viewBoxX + margin,
                viewBoxY + margin
            )
        case .topRight:
            return (
                viewBoxX + viewBoxWidth - scaledWidth - margin,
                viewBoxY + margin
            )
        }
    }

    private static func totalOverlapArea(_ rect: VRect, avoidRects: [VRect]) -> Double {
        var total = 0.0
        for avoidRect in avoidRects {
            let overlapWidth = min(rect.maxX, avoidRect.maxX) - max(rect.minX, avoidRect.minX)
            let overlapHeight = min(rect.maxY, avoidRect.maxY) - max(rect.minY, avoidRect.minY)
            if overlapWidth > 0 && overlapHeight > 0 {
                total += overlapWidth * overlapHeight
            }
        }
        return total
    }

    /// Raw interpolation, not `SVGBuilder.format`: the trailing `.0` is pinned.
    static func render(at rect: VRect) -> VSVGNode {
        .element(
            .use,
            [
                VSVGAttribute("href", "#" + symbolId),
                VSVGAttribute("x", "\(rect.x)"), VSVGAttribute("y", "\(rect.y)"),
                VSVGAttribute("width", "\(rect.width)"), VSVGAttribute("height", "\(rect.height)"),
            ])
    }
}
