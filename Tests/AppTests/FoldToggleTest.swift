// Toggling a group's fold: the export keeps the fold state, and the menu
// title follows it.

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct FoldToggleTest {
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
            edge a -> b;
          }
          node c: Concept "C";
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    @Test func toggleFoldingRoundTrips() throws {
        let s = try session()

        // Fold: the plain `group` becomes `folded group`; contents survive.
        try s.toggleFolding(of: "g1")
        let folded = try s.exportVGL()
        #expect(folded.contains("folded group g1"))
        #expect(folded.contains("node a"))
        #expect(folded.contains("node b"))

        // The menu now labels it "Unfold group".
        #expect(
            EditorCore.menu(for: "g1", in: s)
                .first { $0.id == .toggleFolding }?.title == "Unfold group")

        // Unfold: back to a plain `group`, no `folded` keyword.
        try s.toggleFolding(of: "g1")
        let unfolded = try s.exportVGL()
        #expect(!unfolded.contains("folded group g1"))
        #expect(unfolded.contains("group g1"))
        #expect(unfolded.contains("node a"))
    }
}
