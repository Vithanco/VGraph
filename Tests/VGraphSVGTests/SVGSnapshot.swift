// The byte-level ratchet on rendered SVG. It replaced a comparison against a
// second renderer, which is what let that renderer go — ADR-0015 has the why.
//
// A snapshot says nothing about whether the output is *right*. That is the job of
// the assertions beside it; the snapshot only catches the rest of the document
// moving underneath them.

import Foundation
import Testing

enum SVGSnapshot {

    private static var isRecording: Bool {
        ProcessInfo.processInfo.environment["UPDATE_SNAPSHOTS"] == "1"
    }

    private static var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("__Snapshots__")
    }

    /// `#function` arrives as `someTest()`, hence the `dropLast(2)`.
    static func caseName(_ prefix: String, _ function: String, _ variant: String? = nil) -> String {
        let base = function.hasSuffix("()") ? String(function.dropLast(2)) : function
        guard let variant else { return "\(prefix)-\(base)" }
        return "\(prefix)-\(base)-\(variant)"
    }

    /// A missing snapshot is recorded and then *fails* rather than passing quietly:
    /// a new expectation should be something a human looked at, not something a
    /// green run created.
    static func verify(
        _ actual: String, named name: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let file = directory.appendingPathComponent("\(name).svg")

        guard !isRecording else {
            write(actual, to: file, sourceLocation: sourceLocation)
            return
        }

        guard let expected = try? String(contentsOf: file, encoding: .utf8) else {
            write(actual, to: file, sourceLocation: sourceLocation)
            Issue.record(
                "No snapshot for \"\(name)\" — recorded one. Check the diff, then re-run.",
                sourceLocation: sourceLocation)
            return
        }

        guard actual != expected else { return }

        Issue.record(
            """
            Snapshot "\(name)" does not match.
            \(firstDifference(between: expected, and: actual))
            Re-run with UPDATE_SNAPSHOTS=1 once the change is intended.
            """,
            sourceLocation: sourceLocation)
    }

    private static func write(_ contents: String, to file: URL, sourceLocation: SourceLocation) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            Issue.record("Could not write snapshot \(file.lastPathComponent): \(error)", sourceLocation: sourceLocation)
        }
    }

    /// A whole-document diff is unreadable in a test log and the interesting part
    /// is nearly always one attribute.
    private static func firstDifference(between expected: String, and actual: String) -> String {
        let expectedChars = Array(expected)
        let actualChars = Array(actual)
        var index = 0
        while index < expectedChars.count, index < actualChars.count, expectedChars[index] == actualChars[index] {
            index += 1
        }

        let window = 90
        let start = max(0, index - window / 2)
        func excerpt(_ characters: [Character]) -> String {
            let end = min(characters.count, index + window)
            return start >= end ? "«end of string»" : String(characters[start..<end])
        }

        return """
            First difference at offset \(index):
              expected: …\(excerpt(expectedChars))…
                actual: …\(excerpt(actualChars))…
            """
    }
}
