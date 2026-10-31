// Covers GraphSession's diff surface over its version store.

import Testing
import VGLanguage
import VGraph

@testable import App

struct SessionDiffTest {
    let base = """
        vgraph demo: ConceptMap "Demo" {
          node c: Concept "C";
        }
        """
    let withD = """
        vgraph demo: ConceptMap "Demo" {
          node c: Concept "C";
          node d: Concept "D";
        }
        """
    let grouped = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
          }
        }
        """

    @Test func freshSessionHasNothingToDiffAgainst() throws {
        let s = try makeTestSession(vgl: base)
        #expect(s.diffToParent() == nil)  // root has no parent
        #expect(s.unifiedDiffToParent() == nil)
    }

    @Test func diffToParentShowsWhatTheLastEditChanged() throws {
        let s = try makeTestSession(vgl: base)
        try s.textEdited(vgl: withD)

        let diff = try #require(s.diffToParent())
        #expect(diff.contains(.insert("  node d: Concept \"D\";")))
        #expect(
            !diff.contains(where: {
                guard case .delete = $0 else { return false }
                return true
            }))
    }

    @Test func unifiedDiffToParentPrefixesChangedLines() throws {
        let s = try makeTestSession(vgl: base)
        try s.textEdited(vgl: withD)

        let unified = try #require(s.unifiedDiffToParent())
        #expect(unified.contains("+   node d: Concept \"D\";"))
    }

    @Test func diffBetweenTwoHeldVersions() throws {
        let s = try makeTestSession(vgl: base)
        let first = s.currentVersion
        try s.textEdited(vgl: withD)
        s.textEditingEnded()
        let second = s.currentVersion

        let diff = try #require(s.diff(from: first, to: second))
        #expect(diff.contains(.insert("  node d: Concept \"D\";")))

        // Reversed, the same change reads as a deletion.
        let reversed = try #require(s.diff(from: second, to: first))
        #expect(reversed.contains(.delete("  node d: Concept \"D\";")))
    }

    @Test func diffToParentAfterACommandDescribesTheCommandsEdit() throws {
        let s = try makeTestSession(vgl: grouped)

        try s.toggleFolding(of: "g1")
        let unified = try #require(s.unifiedDiffToParent())
        #expect(unified.contains("folded group g1"))
    }

    /// A command records the *re-exported* VGL, so history and the text the
    /// editor writes back to the textarea cannot drift apart.
    @Test func recordedCommandVersionIsTheReExportedVGL() throws {
        let s = try makeTestSession(vgl: grouped)

        try s.toggleFolding(of: "g1")
        let exported = try s.exportVGL()

        _ = try s.undo()
        #expect(try s.redo() == exported)
    }
}
