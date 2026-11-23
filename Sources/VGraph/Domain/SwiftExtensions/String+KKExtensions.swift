extension String {
    /// Every string contains the empty one, as `range(of:)` would not say.
    func containsCaseInsensitive(_ searchString: String) -> Bool {
        searchString.isEmpty || lowercased().contains(searchString.lowercased())
    }
}

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
