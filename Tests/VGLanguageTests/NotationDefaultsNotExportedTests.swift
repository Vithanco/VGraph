//
//  NotationDefaultsNotExportedTests.swift
//  VGraph
//
//  A document says what its author wrote, not what its notation installed.
//  Graph attributes are the one place that diffs against the attribute's own
//  default rather than against the notation, which is how a notation's settings
//  reach a document and pin themselves there against a later change to it.
//

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("A notation's graph attributes stay out of the document")
struct NotationDefaultsNotExportedTests {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func roundTrip(_ source: String) throws -> String {
        try VGLExporter().export(graph: parse(source))
    }

    private let cld = """
        vgraph tired: CLD "Why am I always tired?" {
            node tired: Stock "Tiredness";
            node coffee: Stock "Coffee";
            node sleep: Stock "Good Sleep";
            edge tired -> coffee: same;
            edge coffee -> sleep: opposite;
            edge sleep -> tired: opposite;
        }
        """

    @Test("CLD's layout engine and spacing are not written into the document")
    func cldKeepsItsOwnSettings() throws {
        let exported = try roundTrip(cld)

        #expect(!exported.contains("layoutengine:"))
        #expect(!exported.contains("overlap:"))
        #expect(!exported.contains("sep:"))
        #expect(!exported.contains("splines:"))
    }

    @Test("Timeline's direction is not written into the document")
    func timelineKeepsItsOwnDirection() throws {
        let exported = try roundTrip(
            """
            vgraph t: Timeline "T" {
                node a: Event "One";
                node b: Event "Two";
                edge a -> b;
            }
            """)

        #expect(!exported.contains("layoutdirection:"))
    }

    @Test("An author's override of a notation's own attribute survives")
    func anExplicitOverrideSurvives() throws {
        let exported = try roundTrip(
            """
            vgraph tired: CLD "Why am I always tired?" {
                splines: ortho
                node tired: Stock "Tiredness";
                node coffee: Stock "Coffee";
                edge tired -> coffee: same;
            }
            """)

        #expect(exported.contains("splines: ortho"))
    }

    /// Driven off the registry so a notation added later is covered the day it
    /// is registered. Empty is what makes the assertion total: the document has
    /// nothing of its own to say, so any line inside the braces came from the
    /// notation.
    @Test("An empty document carries nothing but its declaration", arguments: NotationRegistry.entries.map(\.id))
    func anEmptyDocumentSaysNothing(notation: String) throws {
        let source = "vgraph t: \(notation) \"T\" {\n}"
        let exported = try roundTrip(source)

        let body =
            exported
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != "}" }

        #expect(body.isEmpty, "\(notation) leaked: \(body.joined(separator: " | "))")
    }

    @Test("The notation still supplies its settings on reparse")
    func reparsingRestoresTheNotationsSettings() throws {
        let graph = try parse(try roundTrip(cld))

        let engine: String = try graph.get(graphAttribute: Attributes.Group.layoutEngine)
        let splines: String = try graph.get(graphAttribute: Attributes.Group.splines)

        #expect(engine == "neato")
        #expect(splines == "curved")
    }
}
