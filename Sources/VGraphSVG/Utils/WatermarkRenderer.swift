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

    /// Tries bottom-left first, then bottom-right, top-left, top-right.
    /// If all corners overlap, picks the one with the smallest total overlap area.
    static func renderWatermark(
        viewBoxX: Double, viewBoxY: Double, viewBoxWidth: Double, viewBoxHeight: Double,
        avoidRects: [VRect]
    ) -> VSVGNode {
        // Cover 15% of the smaller dimension, but cap at 100px in either direction
        let targetSize = min(min(viewBoxWidth, viewBoxHeight) * 0.15, 100.0)

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

        var bestX = 0.0
        var bestY = 0.0
        var bestOverlap = Double.infinity

        for corner in corners {
            let (x, y) = position(
                for: corner, margin: margin,
                scaledWidth: scaledWidth, scaledHeight: scaledHeight,
                viewBoxX: viewBoxX, viewBoxY: viewBoxY,
                viewBoxWidth: viewBoxWidth, viewBoxHeight: viewBoxHeight
            )
            let watermarkRect = VRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
            let overlap = totalOverlapArea(watermarkRect, avoidRects: avoidRects)

            if overlap == 0 {
                // No overlap at all — use this corner immediately
                return renderUse(x: x, y: y, width: scaledWidth, height: scaledHeight)
            }
            if overlap < bestOverlap {
                bestOverlap = overlap
                bestX = x
                bestY = y
            }
        }

        // All corners overlap — use the one with the least overlap
        return renderUse(x: bestX, y: bestY, width: scaledWidth, height: scaledHeight)
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
    private static func renderUse(x: Double, y: Double, width: Double, height: Double) -> VSVGNode {
        .element(
            .use,
            [
                VSVGAttribute("href", "#" + symbolId),
                VSVGAttribute("x", "\(x)"), VSVGAttribute("y", "\(y)"),
                VSVGAttribute("width", "\(width)"), VSVGAttribute("height", "\(height)"),
            ])
    }
}
