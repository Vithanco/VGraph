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
    func splitTextIntoOneLineReturnsSameText() {
        let text = "What should we do"
        let lines = TextWrapping.splitText(text, numberOfLines: 1)

        #expect(lines == ["What should we do"])
    }

    @Test
    func splitTextIntoTwoLines() {
        let lines = TextWrapping.splitText("What should we do about this important issue", numberOfLines: 2)

        #expect(lines == ["What should we do about", "this important issue"])
    }

    @Test(
        "Three lines are as even as the words allow",
        arguments: [
            (
                "What should we do about this important issue",
                ["What should we", "do about this", "important issue"]
            ),
            (
                "The quick brown fox jumps over the lazy dog",
                ["The quick brown", "fox jumps over", "the lazy dog"]
            ),
        ])
    func splitTextIntoThreeLines(text: String, expected: [String]) {
        #expect(TextWrapping.splitText(text, numberOfLines: 3) == expected)
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

    /// Two lines are the fewest that fit, but three give the smaller block:
    /// 15 characters × 3 lines against 23 × 2.
    @Test
    func findOptimalLineBreaksMinimizesArea() {
        let result = TextWrapping.findOptimalLineBreaks(
            "What should we do about this important issue",
            characterWidthToHeightRatio: 0.6,
            lineHeightMultiplier: 1.2,
            maxWidth: 15.0
        )

        #expect(result.lines == ["What should we", "do about this", "important issue"])
    }

    @Test
    func findOptimalLineBreaksWithEmptyText() {
        let result = TextWrapping.findOptimalLineBreaks(
            "   ",
            characterWidthToHeightRatio: 0.6,
            lineHeightMultiplier: 1.2,
            maxWidth: 30.0
        )

        #expect(result.lineCount == 0)
        #expect(result.lines.isEmpty)
        #expect(result.width == 0)
        #expect(result.height == 0)
    }

    @Test
    func findOptimalLineBreaksSingleWord() {
        let text = "Hello"
        let result = TextWrapping.findOptimalLineBreaks(
            text,
            characterWidthToHeightRatio: 0.6,
            lineHeightMultiplier: 1.2,
            maxWidth: 30.0
        )

        #expect(result.lineCount == 1)
        #expect(result.lines == ["Hello"])
    }

    @Test
    func findOptimalLineBreaksWithMaxWidth() {
        let text = "It will improve performance lslkj alkj asl klsjhf ladf lkasjd faklsdj"
        let charWidth = 0.6
        let lineHeight = 1.2
        let maxWidth = 30.0  // 50 characters per line: the 69-character text must wrap

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
        #expect(TextWrapping.splitText(rejoined).count == TextWrapping.splitText(text).count)
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
}
