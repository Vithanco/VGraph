// Covers the VCommand framework + GraphSession via the first command,
// "Toggle Folding": registry query, fold/unfold round-trip on the in-memory
// OriginGraph, and the export/reparse invariant.

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

    /// Folding is a display transform, so it must survive a save rather than being
    /// baked in: `FoldGroups` flattens a folded group into a proxy node and deletes
    /// its members, which would destroy the document on every save. Both VGL export
    /// paths are covered — the session's and the CLI formatter's.
    @Test func bothExportPathsKeepFoldState() throws {
        let s = try session()
        try s.toggleFolding(of: "g1")

        let document = try s.exportVGL()
        #expect(document.contains("folded group g1"))

        #expect(try makeTestApp().exportToVGL(document).contains("folded group g1"))
    }

    /// Group-only, and enabled. `GoldenMenuTest` owns the full list for every
    /// kind; this asserts the one fact this suite is about.
    @Test func onlyGroupsOfferToggleFolding() throws {
        let s = try session()

        let fold = EditorCore.menu(for: "g1", in: s).first { $0.id == .toggleFolding }
        #expect(fold?.enabled == true)
        #expect(fold?.title == "Fold group")

        #expect(!EditorCore.menu(for: "a", in: s).contains { $0.id == .toggleFolding })
        #expect(EditorCore.menu(for: "does-not-exist", in: s).isEmpty)
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

    /// A named command refuses rather than shrugging — an id nobody offered is a
    /// caller's mistake, not a stale click.
    @Test func anUnknownTargetIsRefused() throws {
        let s = try session()
        #expect(throws: VError.self) { try s.toggleFolding(of: "does-not-exist") }
        #expect(!(try s.exportVGL()).contains("folded group"))
    }

    @Test func aNodeIsRefused() throws {
        let s = try session()
        // Kind mismatch: folding is a group's business.
        #expect(throws: VError.self) { try s.toggleFolding(of: "a") }
    }

    /// Export → reparse → export is a fixpoint: the OriginGraph round-trips
    /// through VGL semantically unchanged.
    @Test func exportReparseIsStable() throws {
        let s = try session()
        try s.toggleFolding(of: "g1")  // fold, to exercise `folded group`
        let once = try s.exportVGL()
        try s.replaceDocument(vgl: once)
        let twice = try s.exportVGL()
        #expect(once == twice)
    }
}
