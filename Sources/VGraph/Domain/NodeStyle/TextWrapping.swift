// Platform-specific imports for math functions (sqrt, floor)
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(WASILibc)
    import WASILibc
#endif

/// Platform-independent text wrapping algorithms
/// Uses the "least raggedness" algorithm to distribute words evenly across lines
public struct TextWrapping {

    public static func splitText(_ text: String) -> [String] {
        return text.split(
            maxSplits: 1000,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\n" }
        ).map { String($0) }
    }

    /// Tokenize for line-wrapping. Like `splitText(_:)`, but additionally introduces
    /// *soft breaks* after `/` and `-` (the break character stays attached to the left
    /// token). `softBreakBefore[i] == true` means token `i` follows a soft break — no
    /// space should be rendered there when joining.
    static func tokenizeForWrapping(_ text: String) -> (tokens: [String], softBreakBefore: [Bool]) {
        var tokens: [String] = []
        var softBreakBefore: [Bool] = []

        for chunk in splitText(text) {
            var current = ""
            var firstSubToken = true
            for character in chunk {
                current.append(character)
                if character == "/" || character == "-" {
                    tokens.append(current)
                    softBreakBefore.append(!firstSubToken)
                    current = ""
                    firstSubToken = false
                }
            }
            if !current.isEmpty {
                tokens.append(current)
                softBreakBefore.append(!firstSubToken)
            }
        }

        return (tokens, softBreakBefore)
    }

    /// Join one line, omitting the inter-token space where `softBreakBefore` is set.
    private static func joinLine(
        tokens: ArraySlice<String>, softBreakBefore: ArraySlice<Bool>
    ) -> String {
        zip(tokens, softBreakBefore).enumerated().map { index, entry in
            let (token, isSoft) = entry
            return index == 0 || isSoft ? token : " " + token
        }.joined()
    }

    /// This algorithm minimizes the variance in line lengths by:
    /// 1. Calculating cumulative word widths
    /// 2. Computing an ideal line width (total width / number of lines)
    /// 3. Using dynamic programming to find the distribution that minimizes squared differences
    ///
    ///
    /// Algorithm from: https://stackoverflow.com/questions/5059956/algorithm-to-divide-text-into-3-evenly-sized-groups
    public static func splitText(_ text: String, numberOfLines: Int) -> [String] {
        if text.trimmingWhitespace().isEmpty {
            return []
        }
        assert(numberOfLines > 0)

        let (words, softBreakBefore) = tokenizeForWrapping(text)
        let lineCount = min(numberOfLines, words.count)
        assert(lineCount > 0)

        // Prefix sums: characters in words[0..<k], and gaps before them — 1 for a
        // hard break, 0 for a soft one or for the first word.
        let charactersBefore = words.reduce(into: [0]) { sums, word in sums.append(sums[sums.count - 1] + word.count) }
        let gapsBefore = words.indices.reduce(into: [0]) { sums, index in
            sums.append(sums[sums.count - 1] + ((index == 0 || softBreakBefore[index]) ? 0 : 1))
        }
        let totalWidth = charactersBefore[words.count] + gapsBefore[words.count]
        let idealLineWidth = Float(totalWidth - (lineCount - 1)) / Float(lineCount)

        /// Squared distance from the ideal width for one line holding words[first..<end].
        func cost(_ first: Int, _ end: Int) -> Float {
            let gapsInLine = end > first ? gapsBefore[end] - gapsBefore[first + 1] : 0
            let remainingWidth = idealLineWidth - Float(gapsInLine + charactersBefore[end] - charactersBefore[first])
            return remainingWidth * remainingWidth
        }

        // best[lines][end]: the least cost of putting words[0..<end] on that many
        // lines, and where the last of them starts.
        typealias Split = (cost: Float, lastLineStart: Int)
        let noLines: [Split] = [(0, -1)] + words.map { _ in (Float.infinity, -1) }
        let best = (0..<lineCount).reduce(into: [noLines]) { table, previousLines in
            table.append(
                (0...words.count).map { end in
                    (0..<end).reduce((cost: table[previousLines][0].cost + cost(0, end), lastLineStart: 0)) { cheapest, start in
                        let candidate = table[previousLines][start].cost + cost(start, end)
                        return candidate < cheapest.cost || (candidate == cheapest.cost && start < cheapest.lastLineStart)
                            ? (candidate, start) : cheapest
                    }
                })
        }

        // Walk back from the last line; an empty line (two one-letter words at the end) is skipped.
        var lines: [String] = []
        var end = words.count
        for line in (1...lineCount).reversed() {
            let start = best[line][end].lastLineStart
            if start < end {
                lines.append(joinLine(tokens: words[start..<end], softBreakBefore: softBreakBefore[start..<end]))
            }
            end = start
        }
        return Array(lines.reversed())
    }

    /// This searches for the number of lines that produces the most square-like
    /// text block by minimizing the product of width and height.
    /// - Returns: Tuple of (optimal line count, lines array, estimated width, estimated height)
    public static func findOptimalLineBreaks(
        _ text: String,
        characterWidthToHeightRatio: Double,
        lineHeightMultiplier: Double,
        maxWidth: Double
    ) -> (lineCount: Int, lines: [String], width: Double, height: Double) {

        let (tokens, softBreakBefore) = tokenizeForWrapping(text)
        let wordCount = tokens.count
        if wordCount == 0 {
            return (0, [], 0, 0)
        }

        let minLinesForWidth = greedyLineCount(
            tokens, softBreakBefore: softBreakBefore,
            maxCharsPerLine: Int(floor(maxWidth / characterWidthToHeightRatio)))

        // Start searching around the square root of word count, but respect width constraint
        let approxLines = Int(floor(sqrt(Double(wordCount))))
        let minLines = max(minLinesForWidth, approxLines - 3)
        let maxLines = max(minLines, approxLines + 5)

        var bestArea = Double.infinity
        var bestLineCount = minLines
        var bestLines = [String]()
        var bestWidth = 0.0
        var bestHeight = 0.0

        for numLines in minLines...min(maxLines, wordCount) {
            let lines = splitText(text, numberOfLines: numLines)
            let (estimatedWidth, estimatedHeight) = size(of: lines)

            if estimatedWidth > maxWidth {
                continue
            }

            let area = estimatedWidth * estimatedHeight

            if area < bestArea {
                bestArea = area
                bestLineCount = lines.count
                bestLines = lines
                bestWidth = estimatedWidth
                bestHeight = estimatedHeight
            }
        }

        // Safety net: if every candidate was rejected by the width filter (e.g. a single
        // long unbreakable token exceeds maxWidth), fall back to the narrowest layout
        // we can produce. Overflowing the bounding box is far better than silently
        // dropping the label entirely.
        if bestLines.isEmpty {
            let fallbackLineCount = max(minLinesForWidth, 1)
            let lines = splitText(text, numberOfLines: fallbackLineCount)
            bestLineCount = lines.count
            bestLines = lines
            (bestWidth, bestHeight) = size(of: lines)
        }

        return (bestLineCount, bestLines, bestWidth, bestHeight)

        /// From the lines produced: `splitText` may return fewer than it was asked for.
        func size(of lines: [String]) -> (width: Double, height: Double) {
            let longestLine = lines.map { $0.count }.max() ?? 0
            return (Double(longestLine) * characterWidthToHeightRatio, Double(lines.count) * lineHeightMultiplier)
        }
    }

    /// The fewest lines that keep every line within `maxCharsPerLine`, filling
    /// each as far as it goes. A soft break costs no character; a hard one costs a space.
    private static func greedyLineCount(_ tokens: [String], softBreakBefore: [Bool], maxCharsPerLine: Int) -> Int {
        let (lines, _) = tokens.enumerated().reduce((lines: 1, currentLength: 0)) { state, entry in
            let gap = (entry.offset > 0 && !softBreakBefore[entry.offset]) ? 1 : 0
            let spaceNeeded = state.currentLength + gap + entry.element.count
            guard spaceNeeded > maxCharsPerLine && state.currentLength > 0 else { return (state.lines, spaceNeeded) }
            return (state.lines + 1, entry.element.count)
        }
        return lines
    }
}
