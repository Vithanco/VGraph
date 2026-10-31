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

    public static func estimateSize(text: String, font: VFont) -> VSize {
        let width = estimateWidth(text: text, font: font)
        let height = font.size * singleLineHeightMultiplier
        return VSize(width: width, height: height)
    }

    public static func estimateSize(lines: [String], font: VFont) -> VSize {
        guard !lines.isEmpty else { return VSize.zero }

        let maxWidth = lines.map { estimateWidth(text: $0, font: font) }.max() ?? 0

        // Use tighter spacing for single-line text, normal spacing for multi-line
        let lineHeightMultiplier = lines.count == 1 ? singleLineHeightMultiplier : multiLineHeightMultiplier
        let totalHeight = Double(lines.count) * font.size * lineHeightMultiplier

        return VSize(width: maxWidth, height: totalHeight)
    }

    public static func estimateSize(text: String, font: VFont, maxWidth: Double) -> VSize {
        let avgCharWidth = font.size * font.charWidthRatio
        let charsPerLine = Int(maxWidth / avgCharWidth)

        guard charsPerLine > 0 else {
            return VSize(width: maxWidth, height: font.size * singleLineHeightMultiplier)
        }

        let estimatedLines = max(1, (text.count / charsPerLine) + 1)

        let lines = TextWrapping.splitText(text, numberOfLines: estimatedLines)
        return estimateSize(lines: lines, font: font)
    }

    public static func estimateOptimalSize(
        text: String,
        font: VFont
    ) -> (size: VSize, lineCount: Int, lines: [String]) {
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: font.size * font.charWidthRatio,
            lineHeightMultiplier: font.size * multiLineHeightMultiplier
        )

        return (
            size: VSize(width: result.width, height: result.height),
            lineCount: result.lineCount,
            lines: result.lines
        )
    }

    public static func lineHeight(for font: VFont) -> Double {
        return font.size * multiLineHeightMultiplier
    }
}
