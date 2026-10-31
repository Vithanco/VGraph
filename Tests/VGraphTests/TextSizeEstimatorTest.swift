import Testing

@testable import VGraph

@Suite
struct TextSizeEstimatorTest {

    @Test
    func estimateWidthBasicCalculation() {
        let font = VFont(family: .helvetica, size: 12)
        let text = "Hello"
        let width = TextSizeEstimator.estimateWidth(text: text, font: font)

        // Helvetica char width ratio is 0.55
        let expected = Double(text.count) * font.size * font.charWidthRatio
        #expect(width == expected)
    }

    @Test
    func estimateSingleLineSize() {
        let font = VFont(family: .helvetica, size: 12)
        let text = "Hello World"
        let size = TextSizeEstimator.estimateSize(text: text, font: font)

        let expectedWidth = Double(text.count) * font.size * font.charWidthRatio
        let expectedHeight = font.size * 1.0  // single-line uses tight spacing

        #expect(size.width == expectedWidth)
        #expect(size.height == expectedHeight)
    }

    @Test
    func estimateMultiLineSize() {
        let font = VFont(family: .helvetica, size: 12)
        let lines = ["Hello", "World", "Test"]
        let size = TextSizeEstimator.estimateSize(lines: lines, font: font)

        // Width should be based on longest line
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        let expectedWidth = Double(maxLineLength) * font.size * font.charWidthRatio
        let expectedHeight = Double(lines.count) * font.size * 1.2

        #expect(size.width == expectedWidth)
        #expect(size.height == expectedHeight)
    }

    @Test
    func estimateEmptyLinesReturnsZero() {
        let font = VFont(family: .helvetica, size: 12)
        let size = TextSizeEstimator.estimateSize(lines: [], font: font)

        #expect(size.width == 0)
        #expect(size.height == 0)
    }

    @Test
    func lineHeightCalculation() {
        let font = VFont(family: .helvetica, size: 12)
        let height = TextSizeEstimator.lineHeight(for: font)

        #expect(height == 12 * 1.2)
    }

    @Test
    func estimateOptimalSizeReturnsValidResult() {
        let font = VFont(family: .helvetica, size: 12)
        let text = "What should we do about this important issue?"

        let result = TextSizeEstimator.estimateOptimalSize(text: text, font: font)

        // Should return non-zero dimensions
        #expect(result.size.width > 0)
        #expect(result.size.height > 0)
        #expect(result.lineCount > 0)
        #expect(!result.lines.isEmpty)

        // Line count should match lines array
        #expect(result.lineCount == result.lines.count)

        // All lines should be non-empty
        for line in result.lines {
            #expect(!line.isEmpty)
        }
    }

    @Test
    func differentFontSizesProduceDifferentSizes() {
        let smallFont = VFont(family: .helvetica, size: 10)
        let largeFont = VFont(family: .helvetica, size: 20)
        let text = "Test text"

        let smallSize = TextSizeEstimator.estimateSize(text: text, font: smallFont)
        let largeSize = TextSizeEstimator.estimateSize(text: text, font: largeFont)

        #expect(largeSize.width > smallSize.width)
        #expect(largeSize.height > smallSize.height)
    }

    @Test
    func monospaceVsProportionalFonts() {
        let courier = VFont(family: .courier, size: 12)
        let helvetica = VFont(family: .helvetica, size: 12)
        let text = "iii"

        let courierWidth = TextSizeEstimator.estimateWidth(text: text, font: courier)
        let helveticaWidth = TextSizeEstimator.estimateWidth(text: text, font: helvetica)

        // Courier (monospace) should be wider due to higher char width ratio
        #expect(courierWidth > helveticaWidth)
    }

    @Test
    func singleLineVsMultiLineHeight() {
        let font = VFont(family: .helvetica, size: 12)

        // Single line should use tight spacing (1.0x)
        let singleLine = ["Hello"]
        let singleSize = TextSizeEstimator.estimateSize(lines: singleLine, font: font)
        #expect(singleSize.height == font.size * 1.0, "Single line should use 1.0x multiplier")

        // Multi-line should use normal spacing (1.2x)
        let multiLine = ["Hello", "World"]
        let multiSize = TextSizeEstimator.estimateSize(lines: multiLine, font: font)
        #expect(multiSize.height == Double(multiLine.count) * font.size * 1.2, "Multi-line should use 1.2x multiplier")

        // Single line should be shorter than multi-line per line
        #expect(singleSize.height < multiSize.height / 2.0, "Single line should be more compact")
    }

    @Test
    func estimateSizeWithMaxWidthWrapsText() {
        let font = VFont(family: .helvetica, size: 12)
        let text = "This is a longer piece of text that should wrap"
        let maxWidth = 100.0

        let size = TextSizeEstimator.estimateSize(text: text, font: font, maxWidth: maxWidth)

        // Height should be greater than single line due to wrapping
        let singleLineHeight = font.size * 1.2
        #expect(size.height >= singleLineHeight)

        // Width should not significantly exceed maxWidth
        // (allowing some tolerance for word boundaries)
        #expect(size.width <= maxWidth * 1.5)
    }

    @Test
    func estimateSizeWithZeroMaxWidth() {
        let font = VFont(family: .helvetica, size: 12)
        let text = "Test"
        let size = TextSizeEstimator.estimateSize(text: text, font: font, maxWidth: 0)

        // Should still return valid dimensions
        #expect(size.width == 0)
        #expect(size.height > 0)
    }
}
