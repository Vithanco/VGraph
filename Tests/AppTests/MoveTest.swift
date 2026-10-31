// Moving elements between groups, from the diagram pane's port. See ADR-0019.

import EditorCore
import Testing
import VGraph

@testable import App

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

    @Test func aNodeMovesIntoABoundary() throws {
        let s = try session()

        try s.move(["a"], into: "g1")

        #expect(s.origin.group(of: Node("a")) == Group(rawValue: "g1"))
        #expect(try s.exportVGL().contains("node a"))
    }

    @Test func movingOutIsMovingIntoTheRoot() throws {
        let s = try session()

        try s.move(["c"], into: s.rootGroupId())

        #expect(s.origin.group(of: Node("c")) == Group(rawValue: rootGroup))
    }

    @Test func theSessionReportsWhereASetMayGo() throws {
        let s = try session()

        let destinations = s.moveDestinations(for: ["a"])

        #expect(destinations.contains("g1"))
        #expect(!destinations.contains(s.rootGroupId()))
    }

    // MARK: - Refusals

    @Test func movingIntoItsOwnGroupIsRefused() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.move(["c"], into: "g1") }
    }

    @Test func theRootGroupCannotBeMoved() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.move([s.rootGroupId()], into: "g1") }
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

    @Test func emptyingABoundaryByMovingDeletesIt() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group g1 "G1" {
                    node c: Concept "C";
                  }
                }
                """)

        try s.move(["c"], into: s.rootGroupId())

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
    }
}
