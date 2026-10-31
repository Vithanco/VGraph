// Covers the GraphSession undo/redo history: command steps, typing-burst
// coalescing (edit), document-load reset (replaceDocument), and redo
// invalidation. See docs/adr/0006-undo-redo-history.md.

import Testing
import VGLanguage
import VGraph

@testable import App

struct HistoryTest {
    let base = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
            edge a -> b;
          }
          node c: Concept "C";
        }
        """

    // Two further valid, textually-distinct documents for the text-edit path.
    let editedOnce = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
            edge a -> b;
          }
          node c: Concept "C";
          node d: Concept "D";
        }
        """
    let editedTwice = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
            edge a -> b;
          }
          node c: Concept "C";
          node d: Concept "D";
          node e: Concept "E";
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: base)
    }

    @Test func freshSessionHasNoHistory() throws {
        let s = try session()
        #expect(s.canUndo == false)
        #expect(s.canRedo == false)
        #expect(try s.undo() == nil)
        #expect(try s.redo() == nil)
    }

    @Test func commandPushesUndoableStep() throws {
        let s = try session()
        try s.toggleFolding(of: "g1")
        #expect(s.canUndo == true)
        #expect(s.canRedo == false)
        #expect((try s.exportVGL()).contains("folded group g1"))

        // Undo returns the pre-command VGL and reverts the OriginGraph.
        let undone = try s.undo()
        #expect(undone == base)
        #expect(!(try s.exportVGL()).contains("folded group g1"))
        #expect(s.canUndo == false)
        #expect(s.canRedo == true)

        // Redo re-applies the fold.
        let redone = try s.redo()
        #expect(redone?.contains("folded group g1") == true)
        #expect((try s.exportVGL()).contains("folded group g1"))
        #expect(s.canRedo == false)
    }

    @Test func typingBurstCoalescesToOneStep() throws {
        let s = try session()
        // Two edits within one open run collapse into a single undo step.
        try s.textEdited(vgl: editedOnce)
        try s.textEdited(vgl: editedTwice)
        #expect(s.canUndo == true)

        // A single undo jumps back past the whole burst to the pre-run text.
        let undone = try s.undo()
        #expect(undone == base)
        #expect(s.canUndo == false)
    }

    @Test func endingTextEditingCutsANewStepForTheNextEdit() throws {
        let s = try session()
        try s.textEdited(vgl: editedOnce)
        s.textEditingEnded()  // e.g. textarea blur
        try s.textEdited(vgl: editedTwice)

        // Sealed between edits ⇒ two distinct undo steps.
        #expect(try s.undo() == editedOnce)
        #expect(try s.undo() == base)
        #expect(s.canUndo == false)
    }

    @Test func unchangedEditIsNotRecorded() throws {
        let s = try session()
        try s.textEdited(vgl: base)  // identical to current state → no-op
        #expect(s.canUndo == false)
    }

    @Test func replaceDocumentResetsHistory() throws {
        let s = try session()
        try s.toggleFolding(of: "g1")
        #expect(s.canUndo == true)

        try s.replaceDocument(vgl: base)
        #expect(s.canUndo == false)
        #expect(s.canRedo == false)
    }

    @Test func newChangeAfterUndoInvalidatesRedo() throws {
        let s = try session()
        try s.toggleFolding(of: "g1")
        _ = try s.undo()
        #expect(s.canRedo == true)

        // A fresh command from the undone state drops the forward history.
        try s.toggleFolding(of: "g1")
        #expect(s.canRedo == false)
        #expect(s.canUndo == true)
    }

    /// A distinct, valid document keyed by `i` (varies the graph label).
    private func doc(_ i: Int) -> String {
        """
        vgraph demo: ConceptMap "Demo \(i)" {
          node c: Concept "C";
        }
        """
    }

    @Test func historyIsBoundedAtMaxDepth() throws {
        let s = try session()
        // Push well past the cap (maxHistory = 100); seal each so every edit cuts
        // its own entry.
        for i in 1...150 {
            try s.textEdited(vgl: doc(i))
            s.textEditingEnded()
        }
        // The cap bounds how far back undo can walk: 99 steps to the oldest kept
        // entry, then no more. The earliest states (base, doc(1)…doc(50)) fell off.
        var steps = 0
        while s.canUndo {
            _ = try s.undo()
            steps += 1
        }
        #expect(steps == 99)
        #expect((try s.exportVGL()).contains("Demo 51"))
    }

    @Test func invalidEditIsNonDestructive() throws {
        let s = try session()
        try s.textEdited(vgl: editedOnce)
        s.textEditingEnded()
        let before = try s.exportVGL()

        // A parse failure throws before mutating: origin and history are untouched.
        #expect(throws: VError.self) { try s.textEdited(vgl: "vgraph broken {{{ not valid") }
        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == true)
        #expect(s.canRedo == false)
    }
}
