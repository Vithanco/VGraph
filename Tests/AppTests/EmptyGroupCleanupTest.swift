// A command that empties a group removes it. A rule about *commands*, not an
// invariant on the graph — a hand-written empty group is left alone, or a
// document would change on load and stop round-tripping. See ADR-0018.

import Testing
import VGraph

@testable import App

struct EmptyGroupCleanupTest {

    @Test func deletingTheLastNodeRemovesTheBoundary() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group g1 "G1" {
                    node c: Concept "C";
                  }
                }
                """)

        try s.delete("c")

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
        #expect(!(try s.exportVGL().contains("g1")))
    }

    @Test func aBoundaryWithSomethingLeftInItSurvives() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "G1" {
                    node c: Concept "C";
                    node d: Concept "D";
                  }
                }
                """)

        try s.delete("c")

        #expect(s.origin.has(group: Group(rawValue: "g1")))
    }

    /// Upward, until something still holds content — or the [[Root group]],
    /// which is never deleted (ADR-0016).
    @Test func removalCascadesThroughNesting() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group outer "Outer" {
                    group inner "Inner" {
                      node f: Concept "F";
                    }
                  }
                }
                """)

        try s.delete("f")

        #expect(!s.origin.has(group: Group(rawValue: "inner")))
        #expect(!s.origin.has(group: Group(rawValue: "outer")))
        #expect(s.origin.has(node: Node("a")))
    }

    /// The boundary of the rule. Nothing emptied this one, so nothing removes
    /// it — otherwise a document would lose a group its author wrote on purpose,
    /// the moment it was opened.
    @Test func aHandWrittenEmptyGroupIsLeftAlone() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  group hollow "Hollow" {
                  }
                }
                """)

        try s.delete("b")

        #expect(s.origin.has(group: Group(rawValue: "hollow")))
        #expect(try s.exportVGL().contains("hollow"))
    }

    /// One command is one [[Snapshot]]: the node and the boundary it emptied
    /// come back together.
    @Test func theCleanupIsPartOfTheSameUndoStep() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  group g1 "G1" {
                    node c: Concept "C";
                  }
                }
                """)
        let before = try s.exportVGL()

        try s.delete("c")
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
    }
}
