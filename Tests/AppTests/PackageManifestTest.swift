import Foundation
import Testing

private let manifest = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // AppTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // repo root
    .appendingPathComponent("Package.swift")

struct PackageManifestTest {
    /// SwiftPM refuses a version-tagged dependency whose targets use
    /// `unsafeFlags`, even ones limited to wasm, so no release could be used.
    @Test func declaresNoUnsafeFlags() throws {
        let source = try String(contentsOf: manifest, encoding: .utf8)
        let offending = source.split(separator: "\n").filter { $0.contains("unsafeFlags(") }
        #expect(offending.isEmpty, "pass compiler flags from the build script instead: \(offending)")
    }
}
