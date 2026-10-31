// The diagram pane's [[Selection]] — adapter state the domain never hears
// about, and the menu built from it. See ADR-0018.

import EditorCore
import Testing
import VGraph

@testable import App

struct SelectionTest {
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

    // MARK: - Gathering

    @Test func aClickReplacesWhateverWasThere() {
        #expect(Selection(["a", "b"]).replacing(with: "c").ids == ["c"])
    }

    @Test func shiftClickAddsAndRemovesTheSameElement() {
        let one = Selection().toggling("a")
        #expect(one.ids == ["a"])
        #expect(one.toggling("a").isEmpty)
    }

    @Test func aRubberBandAddsWithoutDuplicating() {
        #expect(Selection(["a"]).adding(["a", "b"]).ids == ["a", "b"])
    }

    // MARK: - Promotion is derived, so a toggle stays invertible

    /// The rule the whole design turns on. ⇧-clicking `g1`'s last member
    /// promotes to the group; ⇧-clicking it again must fall back to the parts.
    /// Were the promotion written into the selection, the second click would
    /// have nothing to remove and the toggle would be a one-way door.
    @Test func promotingAndThenUnpickingGoesBackToTheParts() throws {
        let s = try session()

        let both = Selection(["c"]).toggling("d")
        #expect(both.effective(in: s) == ["g1"])

        let back = both.toggling("d")
        #expect(back.ids == ["c"])
        #expect(back.effective(in: s) == ["c"])
    }

    // MARK: - Pruning

    /// Held by id, so a text edit that deletes an element leaves a stale one
    /// behind. Pruned where it is used rather than eagerly — a parse failure is
    /// non-destructive, so the session always answers against a valid graph.
    @Test func staleIdsArePrunedAway() throws {
        let s = try session()

        #expect(Selection(["a", "ghost"]).pruned(in: s).ids == ["a"])
    }

    // MARK: - Coverage, which is what a right-click tests

    /// "Covered" is *this element or any of its ancestors*, not membership.
    /// Right-clicking a node inside a fully promoted group must not clear the
    /// promotion and reselect the bare node.
    @Test func anElementInsideAPromotedGroupIsCovered() throws {
        let s = try session()
        let selection = Selection(["c", "d"])

        #expect(selection.effective(in: s) == ["g1"])
        #expect(selection.covers("c", in: s))
        #expect(selection.covers("g1", in: s))
    }

    @Test func anUnrelatedElementIsNotCovered() throws {
        let s = try session()

        #expect(!Selection(["c", "d"]).covers("a", in: s))
    }

    @Test func anElementOfAPartialGroupIsNotCoveredBySibling() throws {
        let s = try session()

        #expect(!Selection(["c"]).covers("d", in: s))
    }

    @Test func nothingIsCoveredByAnEmptySelection() throws {
        let s = try session()

        #expect(!Selection().covers("a", in: s))
    }

    // MARK: - The menu

    /// A one-element selection reproduces today's menu exactly, plus the group
    /// row — an assertion rather than a hope, because that equality is what
    /// keeps the two entry points from drifting.
    @Test func oneElementGivesTodaysMenuPlusGrouping() throws {
        let s = try session()

        let single = EditorCore.menu(for: "a", in: s)
        let fromSelection = EditorCore.menu(forSelection: Selection(["a"]), in: s)

        var ids: [VCommandID] = []
        for item in fromSelection { ids.append(item.id) }
        #expect(ids.contains(.addGroup))

        var withoutGrouping: [MenuItem] = []
        for item in fromSelection where item.id != .addGroup { withoutGrouping.append(item) }
        #expect(withoutGrouping == single)
    }

    /// Several elements have no single element to be asked about, so the menu
    /// offers only what applies to a set.
    @Test func severalElementsOfferOnlyTheSetCommands() throws {
        let s = try session()

        let items = EditorCore.menu(forSelection: Selection(["a", "b"]), in: s)

        var ids: [VCommandID] = []
        for item in items { ids.append(item.id) }
        #expect(ids == [.addGroup, .delete])
    }

    @Test func theGroupRowIsPlainWhenNothingHasToMove() throws {
        let s = try session()

        let items = EditorCore.menu(forSelection: Selection(["a", "b"]), in: s)

        #expect(items[0].title == "Group")
        #expect(items[0].enabled)
    }

    /// The row states what it would cost, which is the whole warning — the
    /// operation is one undo step, so it needs no dialog (ADR-0018).
    @Test func theGroupRowNamesWhatItWouldMove() throws {
        let s = try session()

        let items = EditorCore.menu(forSelection: Selection(["a", "c"]), in: s)

        #expect(items[0].title == "Group (moves 1 out of their boundaries)")
        #expect(items[0].enabled)
    }

    /// Selecting everything collapses to the [[Root group]], which cannot be
    /// wrapped — so the command wraps its *contents* instead, and the row stays
    /// live. Refusing here greyed the button on any two-node diagram, which is
    /// what the browser showed.
    @Test func groupingTheWholeDiagramIsOffered() throws {
        let s = try session()

        let items = EditorCore.menu(forSelection: Selection(["a", "b", "g1"]), in: s)

        var grouping: MenuItem?
        for item in items where item.id == .addGroup { grouping = item }
        #expect(grouping?.enabled == true)
        #expect(grouping?.title == "Group")
    }

    /// What the menu offers and what the command does must agree — the same
    /// invariant `MenuAgreesWithExecutionTest` protects for single elements.
    /// A diagram with nothing in it is what is left to disagree about.
    @Test func aGreyedGroupRowMeansTheCommandWouldRefuse() throws {
        let s = try makeTestSession(vgl: "vgraph demo: ConceptMap \"Demo\" {\n}")
        let selection = Selection([s.rootGroupId()])

        let items = EditorCore.menu(forSelection: selection, in: s)
        var grouping: MenuItem?
        for item in items where item.id == .addGroup { grouping = item }

        #expect(grouping?.enabled == false)
        #expect(throws: VError.self) {
            _ = try s.addGroup(containing: selection.effective(in: s))
        }
    }
}
