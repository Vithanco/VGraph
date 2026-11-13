// Covers TextDiff's line-based Myers diff and unified-text rendering.

import Testing

@testable import App

struct TextDiffTest {
    @Test func identicalInputsAreAllEqual() {
        let text = "a\nb\nc"
        let script = TextDiff.lines(from: text, to: text)
        #expect(script == [.equal("a"), .equal("b"), .equal("c")])
    }

    @Test func bothEmptyProducesNoLines() {
        #expect(TextDiff.lines(from: "", to: "") == [])
    }

    @Test func pureInsert() {
        let script = TextDiff.lines(from: "a\nc", to: "a\nb\nc")
        #expect(script == [.equal("a"), .insert("b"), .equal("c")])
    }

    @Test func pureDelete() {
        let script = TextDiff.lines(from: "a\nb\nc", to: "a\nc")
        #expect(script == [.equal("a"), .delete("b"), .equal("c")])
    }

    @Test func interleavedChanges() {
        // Line 2 replaced, line 4 appended.
        let old = "1\n2\n3"
        let new = "1\nX\n3\n4"
        let script = TextDiff.lines(from: old, to: new)
        #expect(script == [.equal("1"), .delete("2"), .insert("X"), .equal("3"), .insert("4")])
    }

    @Test func fromEmptyIsAllInserts() {
        let script = TextDiff.lines(from: "", to: "a\nb")
        #expect(script == [.insert("a"), .insert("b")])
    }

    @Test func toEmptyIsAllDeletes() {
        let script = TextDiff.lines(from: "a\nb", to: "")
        #expect(script == [.delete("a"), .delete("b")])
    }

    @Test func trailingNewlineDoesNotProduceAPhantomLine() {
        // "a\nb\n" splits to ["a", "b"], same as "a\nb".
        let script = TextDiff.lines(from: "a\nb\n", to: "a\nb")
        #expect(script == [.equal("a"), .equal("b")])
    }

    /// A replaced line is a delete immediately followed by an insert: no equal
    /// line separates them, so no gap marker belongs between them.
    @Test func unifiedTextMarksInsertAndDeletePrefixes() {
        #expect(TextDiff.unified(from: "a\nb\nc", to: "a\nx\nc") == "  a\n- b\n+ x\n  c")
    }

    @Test func unifiedTextOfIdenticalInputsIsEmpty() {
        let text = "a\nb\nc"
        #expect(TextDiff.unified(from: text, to: text) == "")
    }

    /// Each hunk gets context on *both* sides. The equal run between two
    /// distant hunks has to close the first before opening the second.
    @Test func unifiedTextKeepsTrailingContextAfterAnEarlierHunk() {
        var old = ["start-old"]
        var new = ["start-new"]
        for i in 1...8 {
            old.append("same\(i)")
            new.append("same\(i)")
        }
        old.append("end-old")
        new.append("end-new")
        let unified = TextDiff.unified(
            from: old.joined(separator: "\n"), to: new.joined(separator: "\n"), context: 2)

        let lines = unified.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(
            lines == [
                "- start-old",
                "+ start-new",
                "  same1",  // trailing context closing the first hunk
                "  same2",
                "@@ ... @@",
                "  same7",  // leading context opening the second
                "  same8",
                "- end-old",
                "+ end-new",
            ])
    }

    @Test func unifiedTextDoesNotOpenWithAGapMarker() {
        // Nothing precedes the first hunk, so there is no gap to mark.
        let unified = TextDiff.unified(from: "e1\ne2\ne3\ne4\ne5\nold", to: "e1\ne2\ne3\ne4\ne5\nnew", context: 2)
        #expect(!unified.hasPrefix("@@"))
        #expect(unified.hasPrefix("  e4"))
    }
}
