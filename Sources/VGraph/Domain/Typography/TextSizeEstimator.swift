/// Uses font metrics from VFont's FontFamily
public struct TextSizeEstimator {

    /// Line height multiplier for multi-line text (includes line spacing)
    private static let multiLineHeightMultiplier = 1.2

    /// Line height multiplier for single-line text (tight fit)
    private static let singleLineHeightMultiplier = 1.0

    public static func estimateWidth(text: String, font: VFont) -> Double {
        let avgCharWidth = font.size * font.charWidthRatio
        return Double(text.count) * avgCharWidth
    }

    public static func estimateSize(lines: [String], font: VFont) -> VSize {
        guard !lines.isEmpty else { return VSize.zero }

        let maxWidth = lines.map { estimateWidth(text: $0, font: font) }.max() ?? 0

        // Use tighter spacing for single-line text, normal spacing for multi-line
        let lineHeightMultiplier = lines.count == 1 ? singleLineHeightMultiplier : multiLineHeightMultiplier
        let totalHeight = Double(lines.count) * font.size * lineHeightMultiplier

        return VSize(width: maxWidth, height: totalHeight)
    }
}
