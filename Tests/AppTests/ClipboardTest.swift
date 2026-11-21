// Who answers ⌘C and ⌘V, and where a paste lands (#112). Focus decides the
// first, so the source pane's own copy and paste are never taken over.

import EditorCore
import Testing
import VGraph

@testable import App

struct ClipboardRoutingTest {
    @Test("Given focus in the diagram and a selection, when copying, then the graph copies")
    func theDiagramCopiesItsSelection() {
        #expect(graphAnswers(.copy, focus: .diagram, hasSelection: true))
    }

    @Test("Given focus in the diagram and no selection, when copying, then the browser's copy is left alone")
    func nothingSelectedIsNotAGraphCopy() {
        #expect(!graphAnswers(.copy, focus: .diagram, hasSelection: false))
    }

    @Test("Given focus in the source text, when copying, then the browser's copy is left alone")
    func textCopiesAsText() {
        #expect(!graphAnswers(.copy, focus: .text, hasSelection: true))
    }

    @Test("Given focus in the diagram, when pasting, then the graph pastes")
    func theDiagramPastes() {
        #expect(graphAnswers(.paste, focus: .diagram, hasSelection: false))
    }

    @Test("Given focus in the source text, when pasting, then the browser's paste is left alone")
    func textPastesAsText() {
        #expect(!graphAnswers(.paste, focus: .text, hasSelection: true))
    }
}

struct PasteDestinationTest {
    ///     root ── a
    ///          ├─ g ── d, e
    ///          └─ k ── f
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group g "G" {
                    node d: Concept "D";
                    node e: Concept "E";
                  }
                  group k "K" {
                    node f: Concept "F";
                  }
                }
                """)
    }

    @Test("Given one group selected, then the paste lands in it")
    func intoTheSelectedGroup() throws {
        #expect(Selection(["g"]).pasteDestination(in: try session()) == "g")
    }

    @Test("Given one detailed node selected, then the paste lands in it")
    func intoTheSelectedDetailedNode() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                }
                vgraph arch: Arch "Arch" {
                  group s: System "S" {
                    node c1: Container "C1";
                  }
                }
                """)

        #expect(Selection(["s"]).pasteDestination(in: s) == "s")
    }

    @Test("Given every member of g selected, then the paste lands in g")
    func intoAPromotedGroup() throws {
        #expect(Selection(["d", "e"]).pasteDestination(in: try session()) == "g")
    }

    @Test("Given one node selected, then the paste lands at the top level")
    func aNodeIsNoDestination() throws {
        #expect(Selection(["a"]).pasteDestination(in: try session()) == nil)
    }

    @Test("Given two groups selected, then the paste lands at the top level")
    func twoGroupsAreNoDestination() throws {
        #expect(Selection(["g", "k"]).pasteDestination(in: try session()) == nil)
    }

    @Test("Given nothing selected, then the paste lands at the top level")
    func nothingSelectedIsTheTopLevel() throws {
        #expect(Selection().pasteDestination(in: try session()) == nil)
    }
}
