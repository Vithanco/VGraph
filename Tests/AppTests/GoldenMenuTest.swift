//
//  GoldenMenuTest.swift
//  VGraph
//
//  The complete right-click menu, pinned exactly, for every element kind under
//  both notation-break modes.
//
//  A *safety net*, not a unit test. Which commands are offered, what they are
//  called and which are greyed out used to be `VGraph`'s and is now the
//  editor's (ADR-0013). Nothing else asserts the whole list, so nothing else
//  would notice a rule quietly disappearing.
//
//  It passed unchanged across that move, which is the evidence the move was a
//  relocation and not a rewrite. Expect to update it deliberately — a diff here
//  is a change to what the user sees.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct GoldenMenuTest {
    /// A ConceptMap covering all three target kinds: a node inside a group, a
    /// relation node, the edge between them, and the group itself.
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    /// A DecisionTree Outcome is terminal — the notation declares nothing
    /// leaving it — and the edge arriving at it may not be reversed. The fixture
    /// for "greyed out because the notation says so".
    private func decisionTree() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node c: Choice "Pick";
                  node o: Outcome "Done";
                  edge c -> o;
                }
                """)
    }

    /// One line per offered command: `id | title | enabled`. A list and not a
    /// set — menu order is part of what is pinned here.
    ///
    /// Goes through `EditorCore.menu`, not `availableCommands` directly: this is
    /// the menu the editor actually draws, and the whole point of that target is
    /// that it stays under test while its implementation migrates.
    private func menu(
        _ session: TestSession, _ elementId: String, _ notationBreak: VNotationBreak = .forbidden
    ) -> String {
        EditorCore.menu(for: elementId, in: session, notationBreak: notationBreak)
            .map { "\($0.id.raw) | \($0.title) | \($0.enabled ? "enabled" : "greyed")" }
            .joined(separator: "\n")
    }

    // MARK: - One menu per target kind

    @Test func nodeMenu() throws {
        #expect(
            menu(try conceptMap(), "a") == """
                addSuccessor | Add successor | enabled
                addPredecessor | Add predecessor | enabled
                changeType | Change type | enabled
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)
    }

    /// `split` is already a notation break here: inserting a node between a
    /// Concept and a Relation is not a shape the notation declares.
    @Test func edgeMenu() throws {
        let session = try conceptMap()
        let edgeId = session.origin.edges.first!.id.id

        #expect(
            menu(session, edgeId) == """
                changeDirection | Change direction | enabled
                changeType | Change type | greyed
                split | Split (breaks notation) | greyed
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)
    }

    /// `toggleFolding` is group-only — it is absent from the two menus above
    /// rather than greyed, which is `appliesTo` doing its job.
    @Test func groupMenu() throws {
        #expect(
            menu(try conceptMap(), "g1") == """
                addNode | Add node… | enabled
                toggleFolding | Fold group | enabled
                changeType | Change type | greyed
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                ungroup | Ungroup | enabled
                delete | Delete | enabled
                """)
    }

    /// The same menu on the [[Root group]] — what a right-click on blank canvas
    /// opens. One live row out of nine: the rest are things the diagram as a
    /// whole cannot be (folded, typed, deleted, renamed), and they are
    /// `.notApplicable` rather than notation-broken, so ⌥ leaves this menu exactly
    /// as it is (ADR-0016).
    @Test func rootGroupMenu() throws {
        let session = try conceptMap()
        #expect(
            menu(session, session.rootGroupId()) == """
                addNode | Add node… | enabled
                toggleFolding | Fold group | greyed
                changeType | Change type | greyed
                setLabel | Rename | greyed
                openURL | Open URL | greyed
                setURL | Add URL… | greyed
                removeURL | Remove URL | greyed
                ungroup | Ungroup | greyed
                delete | Delete | greyed
                layoutDirection | Layout direction… | enabled
                """)
    }

    @Test func unknownIdOffersNothing() throws {
        #expect(menu(try conceptMap(), "ghost") == "")
    }

    // MARK: - What ⌥ may change

    /// Holding ⌥ may only *enable*. Nothing may appear, disappear or move — a
    /// break is permission, not a different menu.
    @Test func permittingTheBreakOnlyEnables() throws {
        let session = try conceptMap()
        let edgeId = session.origin.edges.first!.id.id

        for id in ["a", "g1", edgeId] {
            let forbidden = menu(session, id, .forbidden).split(separator: "\n")
            let permitted = menu(session, id, .permitted).split(separator: "\n")

            #expect(forbidden.count == permitted.count, "menu length changed for \(id)")
            for (before, after) in zip(forbidden, permitted) {
                let commandId = { (line: Substring) in line.split(separator: "|")[0] }
                #expect(commandId(before) == commandId(after), "command moved for \(id)")
            }
        }
    }

    // MARK: - Greyed by the notation

    /// A terminal node type — the notation declares nothing leaving a
    /// DecisionTree Outcome. `addSuccessor` greys out, now *says why*, and ⌥
    /// reaches it.
    ///
    /// This test previously asserted the two menus were identical, which was the
    /// bug: "nothing to lead to" and "the notation forbids it unless you insist"
    /// were the same `false`, so ⌥ could not open the "Other type…" path that
    /// exists precisely for this case. `VAvailability` separates them.
    @Test func terminalNodeMenuRespondsToTheBreak() throws {
        let session = try decisionTree()

        #expect(
            menu(session, "o") == """
                addSuccessor | Add successor (breaks notation) | greyed
                addPredecessor | Add predecessor | enabled
                changeType | Change type | enabled
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)

        #expect(
            menu(session, "o", .permitted) == """
                addSuccessor | Add successor (breaks notation) | enabled
                addPredecessor | Add predecessor | enabled
                changeType | Change type | enabled
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)
    }

    /// The contrast: commands that *are* notation-breakable grey out, say why in
    /// their title, and ⌥ enables them. This is the behaviour `addSuccessor`
    /// above should have — and `changeType` is the counter-example in the same
    /// menu, greyed under both, because retyping an edge has no break to reach
    /// (ADR-0023).
    @Test func breakableEdgeCommandsRespondToTheBreak() throws {
        let session = try decisionTree()
        let edgeId = session.origin.edges.first!.id.id

        #expect(
            menu(session, edgeId) == """
                changeDirection | Change direction (breaks notation) | greyed
                changeType | Change type | greyed
                split | Split (breaks notation) | greyed
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)

        #expect(
            menu(session, edgeId, .permitted) == """
                changeDirection | Change direction (breaks notation) | enabled
                changeType | Change type | greyed
                split | Split (breaks notation) | enabled
                setLabel | Rename | enabled
                openURL | Open URL | greyed
                setURL | Add URL… | enabled
                removeURL | Remove URL | greyed
                delete | Delete | enabled
                """)
    }
}
