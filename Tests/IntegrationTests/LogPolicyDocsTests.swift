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

    @Test("The Dockerfile sets VGRAPH_LOG_LEVEL to warn")
    func dockerfileSetsLevel() throws {
        #expect(try read("Dockerfile").contains("ENV VGRAPH_LOG_LEVEL=warn"))
    }

    @Test("The hosted-server privacy note says diagrams are not stored, logs hold request metadata and warnings, and names VGRAPH_LOG_LEVEL")
    func privacyNote() throws {
        let note = try read("SECURITY.md")
        #expect(note.contains("Diagrams are not stored"))
        #expect(note.contains("request metadata and warnings"))
        #expect(note.contains("VGRAPH_LOG_LEVEL"))
    }

    @Test("The README of the Node server points to the same note")
    func nodeReadmePoints() throws {
        #expect(try read("vgraph-mcp-node/README.md").contains("SECURITY.md"))
    }
}
