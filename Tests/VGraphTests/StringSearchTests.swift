//
//  StringSearchTests.swift
//  VGraph
//
//  The Foundation-free string search these extensions provide. Embedded Swift
//  has no Foundation, so `range(of:)`, `replacingOccurrences(of:with:)` and
//  `components(separatedBy:)` are ours — and `renderGraphJSON` escapes a whole
//  SVG through them, which is how their cost became a correctness-adjacent
//  concern rather than a detail.
//

import Darwin
import Testing

@testable import VGraph

@Suite("Foundation-free string search")
struct StringSearchTests {

    // MARK: - range(of:)

    @Test("Given a substring present once, when searched, then the range delimits it")
    func rangeFindsSubstring() {
        let s = "hello world"
        let r = try! #require(s.range(of: "world"))
        #expect(String(s[r]) == "world")
    }

    @Test("Given a match at the very start or very end, when searched, then it is still found")
    func rangeFindsAtBoundaries() {
        #expect("abc".range(of: "a") != nil)
        #expect("abc".range(of: "c") != nil)
        #expect("abc".range(of: "abc") != nil)
    }

    @Test("Given no match, when searched, then nil")
    func rangeMissesAbsentSubstring() {
        #expect("hello".range(of: "xyz") == nil)
        #expect("hi".range(of: "longer than self") == nil)
        #expect("hello".range(of: "") == nil)
        #expect("".range(of: "a") == nil)
    }

    @Test("Given a start index past an earlier match, when searched from it, then the later match is returned")
    func rangeFromHonoursStartIndex() {
        let s = "a-b-c"
        let first = try! #require(s.range(of: "-"))
        let second = try! #require(s.range(of: "-", from: first.upperBound))
        #expect(s.distance(from: s.startIndex, to: second.lowerBound) == 3)
        #expect(s.range(of: "-", from: second.upperBound) == nil)
    }

    @Test("Given a start index leaving too few characters, when searched from it, then nil rather than a trap")
    func rangeFromNearEndDoesNotOverrun() {
        let s = "abc"
        #expect(s.range(of: "bc", from: s.index(s.startIndex, offsetBy: 2)) == nil)
        #expect(s.range(of: "x", from: s.endIndex) == nil)
    }

    // MARK: - replacingOccurrences

    @Test("Given repeated targets, when replaced, then every occurrence is replaced")
    func replacesEveryOccurrence() {
        #expect("a.b.c".replacingOccurrences(of: ".", with: "-") == "a-b-c")
        #expect("aaa".replacingOccurrences(of: "a", with: "bb") == "bbbbbb")
        #expect("xxx".replacingOccurrences(of: "xx", with: "y") == "yx")
    }

    @Test("Given adjacent, leading and trailing targets, when replaced, then no text is dropped or duplicated")
    func replacesAtBoundaries() {
        #expect("..a..".replacingOccurrences(of: ".", with: "!") == "!!a!!")
        #expect("ab".replacingOccurrences(of: "ab", with: "") == "")
    }

    @Test("Given no occurrence or an empty target, when replaced, then the string is unchanged")
    func replacementLeavesUnmatchedStringsAlone() {
        #expect("hello".replacingOccurrences(of: "z", with: "!") == "hello")
        #expect("hello".replacingOccurrences(of: "", with: "!") == "hello")
        #expect("".replacingOccurrences(of: "a", with: "b") == "")
    }

    @Test("Given the JSON escape chain renderGraphJSON applies, when run, then each escape survives the next pass")
    func escapeChainIsStable() {
        let raw = #"<svg a="1">\n"# + "\n\ttab"
        let escaped =
            raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        #expect(escaped == #"<svg a=\"1\">\\n\n\ttab"#)
    }

    // MARK: - components(separatedBy:)

    @Test("Given separators between, at the ends, and doubled, when split, then empty fields are preserved")
    func componentsPreservesEmptyFields() {
        #expect("a,b,c".components(separatedBy: ",") == ["a", "b", "c"])
        #expect(",a,".components(separatedBy: ",") == ["", "a", ""])
        #expect("a,,b".components(separatedBy: ",") == ["a", "", "b"])
        #expect("abc".components(separatedBy: ",") == ["abc"])
        #expect("".components(separatedBy: ",") == [""])
        #expect("a".components(separatedBy: "") == ["a"])
    }

    @Test("Given a multi-character separator, when split, then it is matched whole")
    func componentsHandlesMultiCharacterSeparator() {
        #expect("a<>b<>c".components(separatedBy: "<>") == ["a", "b", "c"])
    }

    // MARK: - Cost

    // Not a timing assertion — a shape assertion. The previous implementations
    // copied the unsearched remainder on every match, so escaping an SVG cost
    // O(n²): a 99KB diagram took 30s in wasm. A test that merely *finished*
    // would have passed before the fix too.
    @Test("Given one input sixteen times longer than another, when every character is replaced, then it costs no more than sixteen of the short")
    func replacementDoesNotDegradeQuadratically() {
        // Thread CPU time, so time spent descheduled under load is not counted.
        func cpuNanos(_ work: () -> Void) -> Int {
            var start = timespec()
            var end = timespec()
            clock_gettime(CLOCK_THREAD_CPUTIME_ID, &start)
            work()
            clock_gettime(CLOCK_THREAD_CPUTIME_ID, &end)
            return (end.tv_sec - start.tv_sec) * 1_000_000_000 + (end.tv_nsec - start.tv_nsec)
        }
        func escape(_ s: String) { _ = s.replacingOccurrences(of: "\"", with: "\\\"") }
        let short = String(repeating: "\"x", count: 16_000)
        let long = String(repeating: "\"x", count: 256_000)
        escape(short)  // warm up, discard
        // Equal work on each side, so whatever load still leaks through
        // weighs on both alike; interleaved and the fastest kept.
        let runs = (0..<5).map { _ in
            (short: cpuNanos { for _ in 0..<16 { escape(short) } }, long: cpuNanos { escape(long) })
        }
        let ratio = Double(runs.map { $0.long }.min()!) / Double(runs.map { $0.short }.min()!)
        // Linear measures ~1x; the implementation this replaced measured ~10x.
        #expect(ratio < 3, "one 256k escape cost \(ratio)x sixteen 16k escapes — looks superlinear")
    }
}
