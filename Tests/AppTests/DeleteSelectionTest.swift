// Deleting a whole [[Effective selection]] at once. See ADR-0018.

import EditorCore
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

    /// The selection is collapsed first, so deleting `c` and `d` deletes the
    /// boundary they complete — the group is what was selected, and a group
    /// takes its contents with it.
    @Test func aPromotedGroupIsWhatGetsDeleted() throws {
        let s = try session()

        try s.delete(all: ["c", "d"])

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
        #expect(!s.origin.has(node: Node("c")))
        #expect(s.origin.has(node: Node("a")))
    }

    /// Deleting a selection can never *empty* a boundary, for the same reason
    /// grouping cannot: every member selected is exactly the promotion
    /// condition, so the boundary is what gets deleted, contents and all. The
    /// cleanup rule stays where the case is real — a single `delete` on one
    /// node, which no promotion precedes.
    @Test func aFullyChosenBoundaryIsDeletedRatherThanEmptied() throws {
        let s = try session()

        try s.delete(all: ["c", "d", "a"])

        #expect(!s.origin.has(group: Group(rawValue: "g1")))
        #expect(!s.origin.has(node: Node("a")))
        #expect(s.origin.has(node: Node("b")))
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

    // MARK: - The menu offers it

    @Test func severalElementsOfferGroupingAndDeleting() throws {
        let s = try session()

        let items = EditorCore.menu(forSelection: Selection(["a", "b"]), in: s)

        var ids: [VCommandID] = []
        for item in items { ids.append(item.id) }
        #expect(ids == [.addGroup, .delete])
    }

    @Test func aGreyedDeleteRowMeansTheCommandWouldRefuse() throws {
        let s = try session()
        let selection = Selection([s.rootGroupId()])

        let items = EditorCore.menu(forSelection: selection, in: s)
        var delete: MenuItem?
        for item in items where item.id == .delete { delete = item }

        #expect(delete?.enabled == false)
        #expect(throws: VError.self) { try s.delete(all: selection.effective(in: s)) }
    }
}
