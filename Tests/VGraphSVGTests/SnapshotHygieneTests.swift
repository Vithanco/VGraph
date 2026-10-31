// Rename a test and its old expectation stays on disk forever while the new name
// records itself on the next run — nothing fails, and the directory rots.
//
// Collecting a used/unused set would be the direct check, but tests run in
// parallel and in no order, so "was this read this run?" has no reliable answer.
// The naming contract can be checked without ordering.

import Foundation
import Testing

struct SnapshotHygieneTests {

    var testSourceDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    /// Neither a prefix nor a function name contains a dash, so element 1 is always
    /// the function.
    func functionName(ofSnapshot fileName: String) -> String? {
        let parts = fileName.replacingOccurrences(of: ".svg", with: "").split(separator: "-")
        return parts.count >= 2 ? String(parts[1]) : nil
    }

    @Test func everySnapshotNamesATestThatStillExists() throws {
        let directory = testSourceDirectory.appendingPathComponent("__Snapshots__")
        let snapshots = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".svg") }
        try #require(!snapshots.isEmpty, "no snapshots found — has the directory moved?")

        var declaredFunctions: Set<String> = []
        for file in try FileManager.default.contentsOfDirectory(atPath: testSourceDirectory.path)
        where file.hasSuffix(".swift") {
            let source = try String(
                contentsOf: testSourceDirectory.appendingPathComponent(file), encoding: .utf8)
            for line in source.split(separator: "\n") {
                guard let range = line.range(of: "func ") else { continue }
                let afterKeyword = line[range.upperBound...]
                guard let parenthesis = afterKeyword.firstIndex(of: "(") else { continue }
                declaredFunctions.insert(String(afterKeyword[..<parenthesis]))
            }
        }

        for snapshot in snapshots.sorted() {
            guard let function = functionName(ofSnapshot: snapshot) else {
                Issue.record("\(snapshot) is not named `Prefix-testFunction[-variant].svg`")
                continue
            }
            // Bound first: inlined, the macro expands the whole set into the log.
            let isClaimed = declaredFunctions.contains(function)
            #expect(
                isClaimed,
                "\(snapshot) belongs to a test named \(function)(), which no longer exists — delete the file, or the rename left it behind"
            )
        }
    }
}
