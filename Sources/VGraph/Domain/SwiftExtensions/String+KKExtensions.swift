// From http://stackoverflow.com/questions/24044851/how-do-you-use-string-substringwithrange-or-how-do-ranges-work-in-swift

extension String {
    public var nrOfLines: Int {
        var lineCount = 1
        for char in self where char == "\n" {
            lineCount += 1
        }
        return self.isEmpty ? 0 : lineCount
    }

    public func substring(from: Int?, to: Int?) -> String {
        if let start = from {
            guard start < self.count else {
                return ""
            }
        }

        if let end = to {
            guard end >= 0 else {
                return ""
            }
        }

        if let start = from, let end = to {
            guard end - start >= 0 else {
                return ""
            }
        }

        let startIndex: String.Index
        if let start = from, start >= 0 {
            startIndex = self.index(self.startIndex, offsetBy: start)
        } else {
            startIndex = self.startIndex
        }

        let endIndex: String.Index
        if let end = to, end >= 0, end < self.count {
            endIndex = self.index(self.startIndex, offsetBy: end + 1)
        } else {
            endIndex = self.endIndex
        }

        return String(self[startIndex..<endIndex])
    }

    public func substring(from: Int) -> String {
        return self.substring(from: from, to: nil)
    }

    public func substring(to: Int) -> String {
        return self.substring(from: nil, to: to)
    }

    public func substring(from: Int?, length: Int) -> String {
        guard length > 0 else {
            return ""
        }

        let end: Int
        if let start = from, start > 0 {
            end = start + length - 1
        } else {
            end = length - 1
        }

        return self.substring(from: from, to: end)
    }

    public func substring(length: Int, to: Int?) -> String {
        guard let end = to, end > 0, length > 0 else {
            return ""
        }

        let start: Int
        if let end = to, end - length > 0 {
            start = end - length + 1
        } else {
            start = 0
        }

        return self.substring(from: start, to: to)
    }

    public func removeTrailing(trail: String) -> String {
        guard self.hasSuffix(trail) else {
            return self
        }
        return self.substring(to: self.count - trail.count - 1)
    }

    public func trimmed() -> String {
        let whitespaceAndNewlines: [Character] = [" ", "\t", "\n", "\r"]

        guard let startIndex = self.firstIndex(where: { !whitespaceAndNewlines.contains($0) }) else {
            return ""
        }

        guard let endIndex = self.lastIndex(where: { !whitespaceAndNewlines.contains($0) }) else {
            return ""
        }

        return String(self[startIndex...endIndex])
    }

    public func ensure(endsWith suffix: String) -> String {
        if self.hasSuffix(suffix) {
            return self
        }
        return self + suffix
    }

    public func ensure(startsWith prefix: String) -> String {
        if self.hasPrefix(prefix) {
            return self
        }
        return prefix + self
    }

    public func containsCaseInsensitive(_ searchString: String) -> Bool {
        let lowercaseSelf = self.lowercased()
        let lowercaseSearch = searchString.lowercased()

        guard lowercaseSearch.count <= lowercaseSelf.count else {
            return false
        }

        for i in 0...(lowercaseSelf.count - lowercaseSearch.count) {
            let startIndex = lowercaseSelf.index(lowercaseSelf.startIndex, offsetBy: i)
            let endIndex = lowercaseSelf.index(startIndex, offsetBy: lowercaseSearch.count)
            let substring = lowercaseSelf[startIndex..<endIndex]

            if substring == lowercaseSearch {
                return true
            }
        }

        return false
    }
}

func lessThanForOptStrings(lhs: String?, rhs: String?) -> Bool {
    if let left = lhs, let right = rhs {
        return left < right
    }
    if lhs != nil {
        return true
    }
    return false
}

// from https://stackoverflow.com/questions/26306326/swift-apply-uppercasestring-to-only-the-first-letter-of-a-string
extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + self.dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

// from https://stackoverflow.com/questions/34940044/how-to-remove-all-the-spaces-and-n-r-in-a-string/34940183
extension StringProtocol where Self: RangeReplaceableCollection {
    var removingAllWhitespacesAndNewlines: Self {
        return filter { !$0.isNewline && !$0.isWhitespace }
    }

    mutating func removeAllWhitespacesAndNewlines() {
        removeAll { $0.isNewline || $0.isWhitespace }
    }
}

// from https://stackoverflow.com/questions/32851720/how-to-remove-special-characters-from-string-in-swift-2
extension String {
    var stripped: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-=().!_")
        return self.filter { okayChars.contains($0) }
    }
}

let nilString: String? = Optional<String>.none

extension StringProtocol {
    public func trimmingCharacters(in characters: String) -> String {
        let trimSet = Set(characters)

        guard let startIndex = firstIndex(where: { !trimSet.contains($0) }) else {
            return ""
        }

        guard let endIndex = lastIndex(where: { !trimSet.contains($0) }) else {
            return ""
        }

        return String(self[startIndex...endIndex])
    }
}

// Hand-rolled stdlib-only equivalents of Foundation String methods, deliberately
// named after them: Embedded Swift has no Foundation, and the call sites are
// shared with the native build.

extension String {
    public func components(separatedBy separator: String) -> [String] {
        guard !separator.isEmpty else { return [self] }

        var result: [String] = []
        var searchIndex = self.startIndex

        while let range = self.range(of: separator, from: searchIndex) {
            result.append(String(self[searchIndex..<range.lowerBound]))
            searchIndex = range.upperBound
        }

        result.append(String(self[searchIndex...]))
        return result
    }

    public func components(separatedBy separator: Character) -> [String] {
        return self.split(separator: separator).map(String.init)
    }

    public func range(of searchString: String) -> Range<String.Index>? {
        range(of: searchString, from: self.startIndex)
    }

    /// Search from `start` rather than from the beginning.
    ///
    /// Scanning a string for many matches needs this: without it a caller has
    /// to slice a fresh `String` of everything still unsearched on each step,
    /// which is what made `replacingOccurrences` quadratic. Neither this nor
    /// the no-argument form walks the string to measure a distance per
    /// position — the end of the candidate window moves in step with its start.
    public func range(of searchString: String, from start: String.Index) -> Range<String.Index>? {
        guard !searchString.isEmpty else { return nil }

        // Also the length check: nil means fewer than `count` characters left.
        guard
            var potentialEnd = self.index(
                start, offsetBy: searchString.count, limitedBy: self.endIndex)
        else { return nil }

        var searchStart = start

        while true {
            if self[searchStart..<potentialEnd].elementsEqual(searchString) {
                return searchStart..<potentialEnd
            }
            guard potentialEnd < self.endIndex else { return nil }
            searchStart = self.index(after: searchStart)
            potentialEnd = self.index(after: potentialEnd)
        }
    }

    public func contains(_ substring: String) -> Bool {
        return self.range(of: substring) != nil
    }

    public func replacingOccurrences(of target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }

        var result = ""
        result.reserveCapacity(self.count)
        var searchIndex = self.startIndex

        while let range = self.range(of: target, from: searchIndex) {
            result.append(contentsOf: self[searchIndex..<range.lowerBound])
            result.append(contentsOf: replacement)
            searchIndex = range.upperBound
        }

        result.append(contentsOf: self[searchIndex...])
        return result
    }

    public func trimmingWhitespace() -> String {
        var start = self.startIndex
        var end = self.endIndex

        while start < end && self[start].isWhitespace {
            start = self.index(after: start)
        }

        while end > start && self[self.index(before: end)].isWhitespace {
            end = self.index(before: end)
        }

        return String(self[start..<end])
    }
}
