// Moving elements between groups, from the diagram pane's port. See ADR-0019.

import Testing
import VGraph

@testable import App

/// The rules — what may go where, what an emptied boundary does — belong to
/// `MovingElementsTests`. Here is only what the session adds: edges refused,
/// folding left alone, one undo step.
struct MoveTest {
    ///     root ── a, b
    ///          └─ g1 ── c, d
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          node b: Concept "B";
          group g1 "G1" {
            node c: Concept "C";
            node d: Concept "D";
          }
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    @Test func anEdgeCannotBeMoved() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  group g1 "G1" {
                    node c: Concept "C";
                  }
                  edge a -> b;
                }
                """)
        let edgeId = s.origin.edges[0].id.id

        #expect(throws: VError.self) { try s.move([edgeId], into: "g1") }
    }

    // MARK: - What comes with it

    /// The moved element goes inside and the destination stays folded: folding
    /// is the author's alone (it used to open, ADR-0016).
    @Test func aFoldedDestinationStaysFolded() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  folded group g1 "G1" {
                    node c: Concept "C";
                  }
                }
                """)

        try s.move(["a"], into: "g1")

        #expect(s.isFolded("g1"))
        #expect(s.origin.group(of: Node("a")) == Group(rawValue: "g1"))
    }

    /// One command is one [[Snapshot]] however many elements it names.
    @Test func aMoveIsOneUndoStep() throws {
        let s = try session()
        let before = try s.exportVGL()

        try s.move(["a", "b"], into: "g1")
        #expect(s.canUndo)

        _ = try s.undo()
        #expect(try s.exportVGL() == before)
    }
}
