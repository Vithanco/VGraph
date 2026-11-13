// Deleting a whole [[Effective selection]] at once. See ADR-0018.

import Testing
import VGraph

@testable import App

struct DeleteSelectionTest {
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

    @Test func everythingNamedGoes() throws {
        let s = try session()

        try s.delete(all: ["a", "b"])

        #expect(!s.origin.has(node: Node("a")))
        #expect(!s.origin.has(node: Node("b")))
        #expect(s.origin.has(node: Node("c")))
    }

    /// One command is one [[Snapshot]], however many elements it names — the
    /// difference between this and the adapter calling `delete` in a loop, which
    /// would leave the user pressing ⌘Z once per node.
    @Test func theWholeSetIsOneUndoStep() throws {
        let s = try session()
        let before = try s.exportVGL()

        try s.delete(all: ["a", "b"])
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
    }

    /// The selection is collapsed first: every detail of a detailed node chosen
    /// *is* the node chosen, so it goes whole. Only a detailed node can tell
    /// this from tidying up afterwards — a plain group emptied by the same
    /// deletes disappears either way, but an emptied detailed node is a node
    /// again, which is what a lone `delete` of its last detail leaves behind.
    @Test func aPromotedGroupIsWhatGetsDeleted() throws {
        let vgl = """
            vnotation Arch {
              node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
              node type: Container [nodeStyle: roundedBox]
            }

            vgraph g: Arch "G" {
              node keep: System "Keep";
              group core: System "Core" {
                node api: Container "API";
              }
            }
            """
        let single = try makeTestSession(vgl: vgl)
        try single.delete("api")
        #expect(single.origin.has(node: Node("core")))

        let s = try makeTestSession(vgl: vgl)
        try s.delete(all: ["api"])

        #expect(!s.origin.has(group: Group(rawValue: "core")))
        #expect(!s.origin.has(node: Node("core")))
        #expect(s.origin.has(node: Node("keep")))
    }

    @Test func deletingNothingIsRefused() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.delete(all: []) }
    }

    /// Selecting everything no longer collapses to the [[Root group]] — promotion
    /// stops below it (ADR-0018) — so this empties the diagram rather than being
    /// refused. Emptying is an ordinary edit, and one undo brings it all back;
    /// deleting the *document* is still the document's business (ADR-0016).
    @Test func deletingEverythingEmptiesTheDiagram() throws {
        let s = try session()
        let before = try s.exportVGL()

        try s.delete(all: ["a", "b", "g1"])
        #expect(s.origin.nodes.isEmpty)
        #expect(s.origin.groups.isEmpty)

        _ = try s.undo()
        #expect(try s.exportVGL() == before)
    }

    /// Naming the root outright is still refused — nothing in the editor can
    /// produce it, since a click on blank canvas clears instead of selecting.
    @Test func theRootGroupItselfCannotBeDeleted() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.delete(all: [s.rootGroupId()]) }
    }
}
