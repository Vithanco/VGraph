import Testing

@testable import VGraph

struct NodeStyleDimensionsTest {

    @Test func testIconWithTextSize() {
        let icon = IconInfo(
            iconPosition: .left,
            iconName: "star",
            iconColor: VColor.yellow,
            iconSize: 24
        )
        let style = NodeStyleLayout.iconWithText(
            backgroundColor: VColor.blue,
            icon: icon
        )
        let lines = ["This is a test node!"]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: lines, font: font)
        let size = style.calculateSizeWithText(textSize)

        #expect(size.width > 0, "Width should be positive")
        #expect(size.height > 0, "Height should be positive")
        #expect(size.width > 50, "Width should be reasonable")
        #expect(size.height > 24, "Height should be > icon ")
    }

    @Test func testCategoryHeaderSize() {
        let style = NodeStyleLayout.withCategory(category: "Domain", categoryColor: VColor.green)
        let lines = ["Domain concept"]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: lines, font: font)
        let size = style.calculateSizeWithText(textSize)

        #expect(size.width > 0, "Width should be positive")
        #expect(size.height > 0, "Height should be positive")
        #expect(size.height > NodeStyleConstants.categoryHeight, "Height should include category header")
    }

    @Test func testCategoryAndIconSize() {
        let icon = IconInfo(
            iconPosition: .left,
            iconName: "default",
            iconColor: VColor.blue,
            iconSize: 24
        )
        let style = NodeStyleLayout.withCategoryAndIcon(
            category: "Question",
            categoryColor: VColor.green,
            icon: icon
        )
        let lines = ["What is the main question?"]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: lines, font: font)
        let size = style.calculateSizeWithText(textSize)

        #expect(size.width > 0, "Width should be positive")
        #expect(size.height > 0, "Height should be positive")
        #expect(size.width > 50, "Width should be reasonable for icon + text + padding")
        #expect(size.height > NodeStyleConstants.categoryHeight, "Height should include category header + content")
    }

    @Test func testSingleLineTextSize() {
        let style = NodeStyleLayout.bareText
        let singleLine = ["Hello World"]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: singleLine, font: font)
        let size = style.calculateSizeWithText(textSize)

        // Single line should have height of font.size * 1.0 (tight), no padding
        let expectedHeight = font.size * 1.0  // bareText has no padding

        #expect(abs(size.height - expectedHeight) < 0.1, "Single line height should match font size")
        #expect(size.width > 0, "Width should be positive")
    }

    @Test func testMultiLineWrappedTextSize() {
        let style = NodeStyleLayout.bareText
        let wrappedLines = [
            "It will improve performance",
            "way more than anything else.",
            "you will see",
        ]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: wrappedLines, font: font)
        let size = style.calculateSizeWithText(textSize)

        // Multi-line should have height of lines.count * font.size * 1.2, no padding
        let expectedHeight = Double(wrappedLines.count) * font.size * 1.2  // bareText has no padding

        #expect(abs(size.height - expectedHeight) < 0.1, "Multi-line height should be lines * line height")

        // Width should be based on longest line, no padding
        let longestLine = wrappedLines.max(by: { $0.count < $1.count })!
        let expectedWidth = Double(longestLine.count) * font.size * font.charWidthRatio  // bareText has no padding
        #expect(abs(size.width - expectedWidth) < 0.1, "Width should match longest line")
    }

    @Test func testEmptyLinesReturnsPaddingOnly() {
        let style = NodeStyleLayout.bareText
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions
        let textSize = TextSizeEstimator.estimateSize(lines: [], font: font)
        let size = style.calculateSizeWithText(textSize)

        // bareText has no padding, so empty text returns zero size
        #expect(size.width == 0, "Empty lines should have 0px width")
        #expect(size.height == 0, "Empty lines should have 0px height")
    }

    @Test func testComparisonSingleVsMultiLine() {
        let style = NodeStyleLayout.bareText
        let singleLine = ["This is a long single line text"]
        let multiLine = ["This is a long", "single line text"]
        let font = VFont(size: 14)  // Use a fixed font for testing dimensions

        let singleTextSize = TextSizeEstimator.estimateSize(lines: singleLine, font: font)
        let singleSize = style.calculateSizeWithText(singleTextSize)

        let multiTextSize = TextSizeEstimator.estimateSize(lines: multiLine, font: font)
        let multiSize = style.calculateSizeWithText(multiTextSize)

        // Multi-line should be taller
        #expect(multiSize.height > singleSize.height, "Multi-line should be taller than single line")

        // Multi-line width should be narrower (text is wrapped)
        #expect(multiSize.width < singleSize.width, "Multi-line should be narrower when text is wrapped")
    }
}
