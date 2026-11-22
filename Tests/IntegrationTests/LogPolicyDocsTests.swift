import Foundation
import Testing

@Suite
struct LogPolicyDocsTests {
    private func read(_ path: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            url.deleteLastPathComponent()
        }
        return try String(contentsOf: url.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("The hosted-server privacy note says diagrams are not stored, logs hold request metadata and warnings, and names VGRAPH_LOG_LEVEL")
    func privacyNote() throws {
        let note = try read("SECURITY.md")
        #expect(note.contains("Diagrams are not stored"))
        #expect(note.contains("request metadata and warnings"))
        #expect(note.contains("VGRAPH_LOG_LEVEL"))
    }
}
