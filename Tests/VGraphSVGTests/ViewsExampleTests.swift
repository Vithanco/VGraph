import Foundation
import TestSupport
import Testing

@testable import App
@testable import VGraph

@Suite("The docs examples")
struct ViewsExampleTests {
    private let app = VGraphTestApp()

    private static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/examples")

    private static func docsExample(_ name: String) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }

    private static var allExamples: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".vgl") }
            .sorted()
    }

    @Test("Given a docs example, when parsed, then it has nodes", arguments: allExamples)
    func parses(name: String) throws {
        #expect(!(try app.parseGraph(try Self.docsExample(name))).nodes.isEmpty)
    }

    private var source: String { get throws { try Self.docsExample("c4-internet-banking-views.vgl") } }

    /// The editor's example is tested view by view in `ExampleGraphsTests`; this keeps the docs copy from drifting.
    @Test("Given the docs views example, then it is the editor's C4 example")
    func isTheEditorExample() throws {
        let example = try #require(exampleGraphs.first { $0.name.hasPrefix("C4 — Internet Banking") })
        #expect(
            try source.trimmingCharacters(in: .whitespacesAndNewlines)
                == example.vgl.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("Given the example, when the default and context views are compared, then the nodes they show differ, not only their styling")
    func viewsDifferInNodes() throws {
        let graph = try app.parseGraph(source)
        let whole = Set(try graph.displaying(view: nil).nodes.map { $0.id })
        let context = Set(try graph.displaying(view: "context").nodes.map { $0.id })
        #expect(context != whole)
    }

    @Test("Given the single-level docs example, when rendered, then it is the container diagram and its quality report is clean")
    func containerExample() throws {
        let result = try app.renderGraph(try Self.docsExample("c4-internet-banking.vgl"))
        #expect(result.qualityReport.isClean, "\(result.qualityReport.messages.map { $0.message })")
        for id in ["customer", "staticContent", "ui", "backend", "statementStore", "database", "cbs", "ses"] {
            #expect(result.svg.contains("id=\"node-\(id)\""), "\(id)")
        }
        #expect(result.svg.contains("id=\"group-ibs\""))
    }
}
