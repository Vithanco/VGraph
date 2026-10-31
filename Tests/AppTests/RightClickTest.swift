//
//  RightClickTest.swift
//  VGraph
//
//  What a right-click settles before a menu appears: which element it is
//  about, and what the [[Selection]] becomes on the way (ADR-0018, ADR-0016).
//
//  One rule for the whole interaction — make sure the pointed element is
//  covered, then build the menu from the [[Effective selection]] — with two
//  exceptions that are easy to state and were previously asserted nowhere:
//  blank canvas and edges.
//
//  Resolving the click to an id stays in the editor; `closest` is the browser's
//  job and it does it correctly. What arrives here is the id, or `nil` for a
//  miss.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct RightClickTest {
    /// A node inside a group, a relation node, and the edge between them —
    /// every path a right-click can take.
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                    node b: Concept "B";
                  }
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    /// A miss is not nothing: blank canvas is the [[Root group]], which the
    /// renderer draws no element for (ADR-0016). The root is a menu target and
    /// never something selected, so whatever was gathered is dropped — leaving
    /// no doubt about what the canvas menu acts on.
    @Test("Blank canvas addresses the root group and clears the selection")
    func aMissAddressesTheRootGroup() throws {
        let session = try conceptMap()

        let decided = EditorCore.rightClick(
            on: nil, holding: Selection(["a"]), in: session)

        #expect(decided?.target == session.rootGroupId())
        #expect(decided?.selection.isEmpty == true)
        #expect(decided?.fromSelection == false)
    }

    /// An edge cannot join a [[Selection]] — its group is derived from its
    /// endpoints (ADR-0017), so a set command has nothing to do with one, and it
    /// would vanish from the [[Effective selection]] a moment after arriving.
    /// So it takes the single-element path too, and clears.
    @Test("An edge addresses itself and clears the selection")
    func anEdgeIsNeverPartOfASelection() throws {
        let session = try conceptMap()
        let edgeId = session.origin.edges.first!.id.id

        let decided = EditorCore.rightClick(
            on: edgeId, holding: Selection(["a"]), in: session)

        #expect(decided?.target == edgeId)
        #expect(decided?.selection.isEmpty == true)
        #expect(decided?.fromSelection == false)
    }

    /// The ordinary path: an element the [[Selection]] does not cover replaces
    /// it, exactly as a plain click would have done, and the menu is then built
    /// from the [[Effective selection]].
    @Test("An uncovered element replaces the selection")
    func anUncoveredElementBecomesTheSelection() throws {
        let session = try conceptMap()

        let decided = EditorCore.rightClick(
            on: "b", holding: Selection(["a"]), in: session)

        #expect(decided?.target == "b")
        #expect(decided?.selection == Selection(["b"]))
        #expect(decided?.fromSelection == true)
    }

    /// *Covered*, not *a member*. Right-clicking a node inside a fully promoted
    /// group must not clear the promotion and reselect the bare node — the group
    /// already covers it, so the selection is left exactly as it was (ADR-0018).
    @Test("An element a selected group already covers leaves the selection alone")
    func aCoveredElementDoesNotCollapseThePromotion() throws {
        let session = try conceptMap()

        let decided = EditorCore.rightClick(
            on: "a", holding: Selection(["g1"]), in: session)

        #expect(decided?.target == "a")
        #expect(decided?.selection == Selection(["g1"]))
        #expect(decided?.fromSelection == true)
    }

    /// A stale id names nothing, so there are no commands to offer — and an
    /// empty menu is worse than none: the browser's own menu should appear
    /// instead of an empty box.
    ///
    /// **A deliberate change from the pre-`EditorCore` editor**, which cleared
    /// the [[Selection]] *before* discovering there was no menu to show.
    /// Clearing while showing nothing is a surprise the user cannot connect to
    /// their action, so the selection now survives a right-click that offers
    /// nothing.
    @Test("An element that names nothing offers no menu and changes nothing")
    func aStaleIdOffersNothing() throws {
        let session = try conceptMap()

        let decided = EditorCore.rightClick(
            on: "gone", holding: Selection(), in: session)

        #expect(decided == nil)
    }

    // MARK: - Edge bundles (ADR-0027)

    /// A bundle has no label, type or ends of its own, so all it offers is to
    /// unfold what it runs into — each folded end its own row and target.
    @Test("A bundle between two folded groups offers to unfold each, and nothing else")
    func bundleOffersOnlyUnfolding() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  folded group g1 "Left" {
                    node a: Concept "A";
                  }
                  folded group g2 "Right" {
                    node r: Relation "R";
                  }
                  edge a -> r;
                }
                """)

        let menu = EditorCore.rightClickOnBundle(unfolding: ["g1", "g2"], holding: Selection(), in: session)
        let decided = try #require(menu)

        #expect(decided.items.map { $0.id } == [.toggleFolding, .toggleFolding])
        #expect(decided.items.map { $0.target } == ["g1", "g2"])
        #expect(decided.items.map { $0.title } == ["Unfold “Left”", "Unfold “Right”"])
        #expect(decided.items.allSatisfy { $0.enabled })
        #expect(!decided.fromSelection)
    }
}
