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
            whereSeparator: { (s: Character) -> Bool in
                return s == " " || s == "\n"
            }
        ).map { String($0) }
    }

    public static func countWords(_ text: String) -> Int {
        return splitText(text).count
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
            for ch in chunk {
                current.append(ch)
                if ch == "/" || ch == "-" {
                    tokens.append(current)
                    softBreakBefore.append(firstSubToken ? false : true)
                    current = ""
                    firstSubToken = false
                }
            }
            if !current.isEmpty {
                tokens.append(current)
                softBreakBefore.append(firstSubToken ? false : true)
            }
        }

        return (tokens, softBreakBefore)
    }

    /// Join one line, omitting the inter-token space where `softBreakBefore` is set.
    private static func joinLine(
        tokens: ArraySlice<String>, softBreakBefore: ArraySlice<Bool>
    ) -> String {
        var result = ""
        var first = true
        var sbIter = softBreakBefore.makeIterator()
        for tok in tokens {
            let soft = sbIter.next() ?? false
            if !first && !soft {
                result += " "
            }
            result += tok
            first = false
        }
        return result
    }

    /// This algorithm minimizes the variance in line lengths by:
    /// 1. Calculating cumulative word widths
    /// 2. Computing an ideal line width (total width / number of lines)
    /// 3. Using dynamic programming to find the distribution that minimizes squared differences
    ///
    ///
    /// Algorithm from: https://stackoverflow.com/questions/5059956/algorithm-to-divide-text-into-3-evenly-sized-groups
    public static func splitText(_ text: String, numberOfLines: Int) -> [String] {
        if text.trimmed().isEmpty {
            return []
        }
        assert(numberOfLines > 0)

        let (words, softBreakBefore) = tokenizeForWrapping(text)
        let linesNr = numberOfLines > words.count ? words.count : numberOfLines
        assert(linesNr > 0)

        var cumwordwidth = [Int]()
        cumwordwidth.append(0)
        for word in words {
            cumwordwidth.append(cumwordwidth[cumwordwidth.count - 1] + word.count)
        }

        // Prefix-sum of gap widths. cumGap[k] = sum of gapBefore[0..<k], where
        // gapBefore[i] is 1 for a hard break preceding token i and 0 for a soft break
        // (or for token 0). Used by the cost function below.
        var cumGap = [Int]()
        cumGap.append(0)
        for i in 0..<words.count {
            let gap = (i == 0 || softBreakBefore[i]) ? 0 : 1
            cumGap.append(cumGap[cumGap.count - 1] + gap)
        }

        let totalwidth = cumwordwidth[cumwordwidth.count - 1] + cumGap[cumGap.count - 1]
        let linewidth: Float = Float(totalwidth - (linesNr - 1)) / Float(linesNr)

        // Cost function for one line containing words[i..<j]
        // Delivers squared difference between ideal linewidth and actual width.
        // Number of inter-token gaps within words[i..<j] is cumGap[j] - cumGap[i+1].
        let cost = { (i: Int, j: Int) -> Float in
            let gapsInLine = j > i ? cumGap[j] - cumGap[i + 1] : 0
            let actuallinewidth = gapsInLine + (cumwordwidth[j] - cumwordwidth[i])
            let remainingWidth: Float = linewidth - Float(actuallinewidth)
            return remainingWidth * remainingWidth
        }

        typealias MinRag = (Float, Int)  // (cost for lines so far, word index)

        var best = [[MinRag]]()
        var tmp = [MinRag]()

        tmp.append((0, -1))
        for _ in words {
            tmp.append((Float.infinity, -1))
        }
        best.append(tmp)

        for l in 0...linesNr - 1 {
            tmp = [MinRag]()
            for j in 0...words.count {
                var min: MinRag = (best[l][0].0 + cost(0, j), 0)
                for k in 0..<j {
                    let loc: Float = best[l][k].0 + cost(k, j)
                    if loc < min.0 || (loc == min.0 && k < min.1) {
                        min = (loc, k)
                    }
                }
                tmp.append(min)
            }
            best.append(tmp)
        }

        var lines = [String]()
        var b = words.count
        for o in (1...linesNr).reversed() {
            let a = best[o][b].1
            // Handle edge case where two one-letter words are at the end
            if a < b {
                lines.append(
                    joinLine(
                        tokens: words[a..<b],
                        softBreakBefore: softBreakBefore[a..<b]
                    )
                )
            }
            b = a
        }

        return Array(lines.reversed())
    }

    /// This searches for the number of lines that produces the most square-like
    /// text block by minimizing the product of width and height.
    /// - Returns: Tuple of (optimal line count, lines array, estimated width, estimated height)
    public static func findOptimalLineBreaks(
        _ text: String,
        characterWidthToHeightRatio: Double = 0.6,
        lineHeightMultiplier: Double = 1.2,
        maxWidth: Double? = nil
    ) -> (lineCount: Int, lines: [String], width: Double, height: Double) {

        let (tokens, softBreakBefore) = tokenizeForWrapping(text)
        let wordCount = tokens.count
        if wordCount == 0 {
            return (0, [], 0, 0)
        }

        let minLinesForWidth: Int
        if let maxWidth = maxWidth {
            let maxCharsPerLine = Int(floor(maxWidth / characterWidthToHeightRatio))

            // Find minimum lines needed to fit text within width.
            // A soft break preceding a token costs 0 chars; a hard break costs 1.
            var currentLineLength = 0
            var requiredLines = 1

            for (index, word) in tokens.enumerated() {
                let wordLength = word.count
                let gap = (index > 0 && !softBreakBefore[index]) ? 1 : 0
                let spaceNeeded = currentLineLength + gap + wordLength

                if spaceNeeded > maxCharsPerLine && currentLineLength > 0 {
                    requiredLines += 1
                    currentLineLength = wordLength
                } else {
                    currentLineLength = spaceNeeded
                }
            }

            minLinesForWidth = requiredLines
        } else {
            minLinesForWidth = 1
        }

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

            let maxLineLength = lines.map { $0.count }.max() ?? 0
            let estimatedWidth = Double(maxLineLength) * characterWidthToHeightRatio
            let estimatedHeight = Double(numLines) * lineHeightMultiplier

            if let maxWidth = maxWidth, estimatedWidth > maxWidth {
                continue
            }

            let area = estimatedWidth * estimatedHeight

            if area < bestArea {
                bestArea = area
                bestLineCount = numLines
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
            let maxLineLength = lines.map { $0.count }.max() ?? 0
            bestLineCount = fallbackLineCount
            bestLines = lines
            bestWidth = Double(maxLineLength) * characterWidthToHeightRatio
            bestHeight = Double(fallbackLineCount) * lineHeightMultiplier
        }

        return (bestLineCount, bestLines, bestWidth, bestHeight)
    }
}
