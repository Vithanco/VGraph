// The setLabel command behind inline editing. See ADR-0009.

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct SetLabelTest {
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
          }
          node r: Relation "leads to";
          edge a -> r;
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    /// Committing text from the inline editor.
    @Test func commitsNewTextToANode() throws {
        let s = try session()

        try s.setLabel(of: "a", to: "Market value")

        #expect(try s.exportVGL().contains("node a: Concept \"Market value\""))
    }

    /// Edges and groups carry labels too, and the same command reaches all three.
    @Test func commitsNewTextToAnEdgeAndAGroup() throws {
        let s = try session()

        let edgeId = s.origin.edges.first!.id.id
        try s.setLabel(of: edgeId, to: "clarifies")
        #expect(try s.exportVGL().contains("\"clarifies\""))

        try s.setLabel(of: "g1", to: "Domain")
        #expect(try s.exportVGL().contains("group g1 \"Domain\""))
    }

    /// Committing nothing restores the placeholder rather than leaving an element
    /// with no visible text — an empty label is dropped on export and comes back as
    /// the element id, so "empty" would not survive a reparse anyway.
    @Test func committingEmptyTextRestoresThePlaceholder() throws {
        let s = try session()

        try s.setLabel(of: "a", to: "")

        #expect(try s.exportVGL().contains("node a: Concept \"Change Me\""))
    }

    /// A type with no user text has nothing to rename, so the menu entry greys out.
    @Test func renameIsDisabledForATypeWithNoUserText() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph crt: CRT "Demo" {
                  node u: UndesirableEffect "Sales are falling";
                  node j: AndJunctor;
                  edge u -> j;
                }
                """)

        #expect(EditorCore.menu(for: "u", in: s).first { $0.id == .setLabel }?.enabled == true)
        #expect(EditorCore.menu(for: "j", in: s).first { $0.id == .setLabel }?.enabled == false)
        #expect(throws: VError.self) { try s.setLabel(of: "j", to: "nope") }
    }
}
