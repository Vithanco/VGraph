import Foundation
import Testing

@testable import VGraph

@Suite
struct TextWrappingTest {

    @Test
    func splitTextIntoWords() {
        let text = "What should we do about this"
        let words = TextWrapping.splitText(text)

        #expect(words == ["What", "should", "we", "do", "about", "this"])
    }

    @Test
    func splitTextWithMultipleSpaces() {
        let text = "Hello    world   test"
        let words = TextWrapping.splitText(text)

        #expect(words == ["Hello", "world", "test"])
    }

    @Test
    func splitTextWithNewlines() {
        let text = "Hello\nworld\ntest"
        let words = TextWrapping.splitText(text)

        #expect(words == ["Hello", "world", "test"])
    }

    @Test
    func splitEmptyTextReturnsEmpty() {
        let text = ""
        let words = TextWrapping.splitText(text)

        #expect(words.isEmpty)
    }

    @Test
    func countWordsSimple() {
        let text = "What should we do"
        let count = TextWrapping.countWords(text)

        #expect(count == 4)
    }

    @Test
    func countWordsEmpty() {
        let text = ""
        let count = TextWrapping.countWords(text)

        #expect(count == 0)
    }

    @Test
    func splitTextIntoOneLineReturnsSameText() {
        let text = "What should we do"
        let lines = TextWrapping.splitText(text, numberOfLines: 1)

        #expect(lines == ["What should we do"])
    }

    @Test
    func splitTextIntoTwoLines() {
        let text = "What should we do about this important issue"
        let lines = TextWrapping.splitText(text, numberOfLines: 2)

        #expect(lines.count == 2)

        // Each line should be non-empty
        for line in lines {
            #expect(!line.isEmpty)
        }

        let rejoined = lines.joined(separator: " ")
        #expect(TextWrapping.countWords(rejoined) == TextWrapping.countWords(text))
    }

    @Test
    func splitTextIntoThreeLines() {
        let text = "What should we do about this important issue"
        let lines = TextWrapping.splitText(text, numberOfLines: 3)

        #expect(lines.count == 3)

        // Lines should be relatively balanced (least raggedness)
        let lengths = lines.map { $0.count }
        let maxLen = lengths.max() ?? 0
        let minLen = lengths.min() ?? 0

        // The difference between longest and shortest shouldn't be too extreme
        // This is a characteristic of the least raggedness algorithm
        #expect(maxLen - minLen < text.count)
    }

    @Test
    func splitTextWithMoreLinesThanWords() {
        let text = "Hello world"
        let lines = TextWrapping.splitText(text, numberOfLines: 5)

        // Should return one word per line (max 2 lines)
        #expect(lines.count == 2)
        #expect(lines == ["Hello", "world"])
    }

    @Test
    func splitEmptyTextReturnsEmptyArray() {
        let text = "   "
        let lines = TextWrapping.splitText(text, numberOfLines: 2)

        #expect(lines.isEmpty)
    }

    @Test
    func findOptimalLineBreaksSimpleText() {
        let text = "What should we do about this important issue"
        let result = TextWrapping.findOptimalLineBreaks(text)

        #expect(result.lineCount > 0)
        #expect(!result.lines.isEmpty)
        #expect(result.width > 0)
        #expect(result.height > 0)

        // Line count should match lines array
        #expect(result.lineCount == result.lines.count)

        // All original words should be present
        let rejoined = result.lines.joined(separator: " ")
        #expect(TextWrapping.countWords(rejoined) == TextWrapping.countWords(text))
    }

    @Test
    func findOptimalLineBreaksMinimizesArea() {
        let text = "What should we do about this important issue"
        let optimal = TextWrapping.findOptimalLineBreaks(text)

        let oneLine = TextWrapping.splitText(text, numberOfLines: 1)
        let oneLineWidth = Double((oneLine.first?.count ?? 0)) * 0.6
        let oneLineHeight = 1.0 * 1.2
        let oneLineArea = oneLineWidth * oneLineHeight

        let wordCount = TextWrapping.countWords(text)
        let manyLines = TextWrapping.splitText(text, numberOfLines: wordCount)
        let manyLinesWidth = Double((manyLines.map { $0.count }.max() ?? 0)) * 0.6
        let manyLinesHeight = Double(manyLines.count) * 1.2
        let manyLinesArea = manyLinesWidth * manyLinesHeight

        let optimalArea = optimal.width * optimal.height

        // Optimal should be better than at least one of the extremes
        #expect(optimalArea <= oneLineArea || optimalArea <= manyLinesArea)
    }

    @Test
    func findOptimalLineBreaksWithEmptyText() {
        let text = ""
        let result = TextWrapping.findOptimalLineBreaks(text)

        #expect(result.lineCount == 0)
        #expect(result.lines.isEmpty)
        #expect(result.width == 0)
        #expect(result.height == 0)
    }

    @Test
    func findOptimalLineBreaksWithCustomRatios() {
        let text = "What should we do"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 0.5,
            lineHeightMultiplier: 1.5
        )

        #expect(result.lineCount > 0)
        #expect(!result.lines.isEmpty)

        // Dimensions should reflect custom ratios
        #expect(result.height > 0)
        #expect(result.width > 0)
    }

    @Test
    func findOptimalLineBreaksSingleWord() {
        let text = "Hello"
        let result = TextWrapping.findOptimalLineBreaks(text)

        #expect(result.lineCount == 1)
        #expect(result.lines == ["Hello"])
    }

    @Test
    func leastRaggednessProducesBalancedLines() {
        let text = "The quick brown fox jumps over the lazy dog"
        let lines = TextWrapping.splitText(text, numberOfLines: 3)

        #expect(lines.count == 3)

        // Calculate variance in line lengths
        let lengths = lines.map { $0.count }
        let avgLength = Double(lengths.reduce(0, +)) / Double(lengths.count)
        let variance = lengths.map { pow(Double($0) - avgLength, 2) }.reduce(0, +) / Double(lengths.count)

        // Variance should be relatively low for well-balanced lines
        // This is somewhat arbitrary but the algorithm should produce reasonable results
        #expect(variance < 100)
    }

    @Test
    func consistentResultsForSameInput() {
        let text = "What should we do about this important issue"

        let result1 = TextWrapping.findOptimalLineBreaks(text)
        let result2 = TextWrapping.findOptimalLineBreaks(text)

        #expect(result1.lineCount == result2.lineCount)
        #expect(result1.lines == result2.lines)
        #expect(result1.width == result2.width)
        #expect(result1.height == result2.height)
    }

    @Test
    func findOptimalLineBreaksWithMaxWidth() {
        let text = "It will improve performance lslkj alkj asl klsjhf ladf lkasjd faklsdj"
        let charWidth = 0.6
        let lineHeight = 1.2
        let maxWidth = 30.0  // Force wrapping: text is 69 chars, so max ~18 chars per line

        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: charWidth,
            lineHeightMultiplier: lineHeight,
            maxWidth: maxWidth
        )

        // All lines should respect the max width constraint
        for line in result.lines {
            let lineWidth = Double(line.count) * charWidth
            #expect(lineWidth <= maxWidth, "Line '\(line)' exceeds max width: \(lineWidth) > \(maxWidth)")
        }

        // Should have multiple lines (not just 1)
        #expect(result.lineCount > 1, "Text should wrap to multiple lines with width constraint")

        let rejoined = result.lines.joined(separator: " ")
        #expect(TextWrapping.countWords(rejoined) == TextWrapping.countWords(text))
    }

    // MARK: - Regression: silent label loss when a token overflows maxWidth

    @Test
    func slashSeparatedRunDoesNotEraseLabel() {
        let text = "Is separate ownership/deployment/security needed?"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 10.8,
            lineHeightMultiplier: 21.6,
            maxWidth: 300.0
        )

        #expect(!result.lines.isEmpty, "Label must not vanish when a long slash-joined token exists")
        let rejoined = result.lines.joined(separator: "")
        #expect(rejoined.contains("ownership"))
        #expect(rejoined.contains("deployment"))
        #expect(rejoined.contains("security"))
        #expect(rejoined.contains("needed?"))
    }

    @Test
    func hyphenSeparatedRunDoesNotEraseLabel() {
        let text = "use-strict-mode-and-warnings-as-errors"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 10.8,
            lineHeightMultiplier: 21.6,
            maxWidth: 100.0
        )

        #expect(!result.lines.isEmpty, "Hyphen-joined token must not erase the label")
        #expect(result.lines.count >= 2, "Should wrap across multiple lines")
    }

    @Test
    func slashWrappedTextRoundTripsWithoutInjectedSpaces() {
        // Concatenated (no separator) because each line is rendered on its own row;
        // joining with a space would inject characters not present in the original.
        let text = "ownership/deployment/security"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 10.0,
            lineHeightMultiplier: 20.0,
            maxWidth: 120.0
        )

        let stitched = result.lines.joined()
        #expect(stitched == text, "Got '\(stitched)', expected '\(text)'")
    }

    @Test
    func unbreakableSingleWordFallsBackInsteadOfDisappearing() {
        let text = "antidisestablishmentarianism"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 10.0,
            lineHeightMultiplier: 20.0,
            maxWidth: 50.0
        )

        #expect(!result.lines.isEmpty, "Safety net must keep the label visible")
        #expect(result.lines.first == text, "Single token cannot be subdivided")
    }

    @Test
    func plainTextWrappingUnchangedByTokenizerExtension() {
        let text = "What should we do about this important issue"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 0.6,
            lineHeightMultiplier: 1.2,
            maxWidth: nil
        )

        #expect(!result.lines.isEmpty)
        let rejoined = result.lines.joined(separator: " ")
        #expect(TextWrapping.countWords(rejoined) == TextWrapping.countWords(text))
    }

    @Test
    func findOptimalLineBreaksWithMaxWidthVsNoConstraint() {
        let text = "It will improve performance lslkj alkj asl klsjhf ladf lkasjd faklsdj"
        let charWidth = 0.6
        let lineHeight = 1.2
        let maxWidth = 30.0  // Same constraint as other test

        let unconstrained = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: charWidth,
            lineHeightMultiplier: lineHeight,
            maxWidth: nil
        )

        let constrained = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: charWidth,
            lineHeightMultiplier: lineHeight,
            maxWidth: maxWidth
        )

        // Constrained version should have more lines (since width is limited)
        #expect(
            constrained.lineCount >= unconstrained.lineCount,
            "Constrained should have at least as many lines as unconstrained")

        // Constrained version should not exceed max width
        #expect(
            constrained.width <= maxWidth,
            "Constrained width \(constrained.width) should not exceed max \(maxWidth)")
    }
}
