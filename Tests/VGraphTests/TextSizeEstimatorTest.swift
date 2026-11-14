import Testing

@testable import VGraph

@Suite
struct TextSizeEstimatorTest {

    @Test
    func estimateWidthBasicCalculation() {
        let font = VFont(family: .helvetica, size: 12)
        let width = TextSizeEstimator.estimateWidth(text: "Hello", font: font)

        // 5 characters × 12pt × Helvetica ratio 0.55
        #expect(abs(width - 33.0) < 1e-9)
    }

    @Test
    func estimateMultiLineSize() {
        let font = VFont(family: .helvetica, size: 12)
        let size = TextSizeEstimator.estimateSize(lines: ["Hi", "World", "Test"], font: font)

        // Width follows the longest line, which is not the first
        #expect(abs(size.width - 33.0) < 1e-9)
        #expect(abs(size.height - 43.2) < 1e-9)
    }

    @Test
    func estimateEmptyLinesReturnsZero() {
        let font = VFont(family: .helvetica, size: 12)
        let size = TextSizeEstimator.estimateSize(lines: [], font: font)

        #expect(size.width == 0)
        #expect(size.height == 0)
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
}
