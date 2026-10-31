//
//  ChangeDirectionTest.swift
//  VGraph
//
//  The ChangeDirection command: flip an edge, staying inside the notation unless
//  the user allows a break.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct ChangeDirectionTest {
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    /// A Concept Map has a type for both directions, so the flip is a one-shot
    /// command: nothing to ask, nothing to break.
    @Test func flipsAnEdgeTheNotationCanCarryBothWays() throws {
        let s = try conceptMap()
        let edgeId = s.origin.edges.first!.id.id

        try s.changeDirection(of: edgeId)

        let exported = try s.exportVGL()
        #expect(exported.contains("edge r -> a"))
        #expect(!exported.contains("edge a -> r"))
        // Round-trips: the flipped edge still matches a declared edge type.
        try s.replaceDocument(vgl: exported)
    }

    /// The flip re-seats the edge, and deleting it takes its attribute item with
    /// it — so everything the user wrote (label, the comment above it) has to be
    /// carried across by hand or it vanishes silently.
    @Test func carriesTheEdgesOwnAttributesAcross() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  // why this link matters
                  edge a -> r "because";
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        try s.changeDirection(of: edgeId)

        let exported = try s.exportVGL()
        #expect(exported.contains("edge r -> a \"because\""))
        #expect(exported.contains("// why this link matters"))
    }

    /// Two edge types join the same pair of node types in a Causal Loop Diagram,
    /// so the flip cannot be decided from the target alone.
    @Test func asksWhichRelationshipWhenSeveralCouldCarryTheFlip() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        // Two reversals, so the editor asks. `EditorCore` is what decides that.
        let options = EditorCore.reversalOptions(for: edgeId, in: s)
        #expect(Set(options.map { $0.id }) == ["same", "opposite"])
        // No "Other type…" escape hatch: for this command the notation break is
        // the ⌥ gesture, not a menu entry.
        #expect(!options.contains { $0.isBreak })

        try s.changeDirection(of: edgeId, to: EdgeType.Id(string: "opposite"))
        #expect(try s.exportVGL().contains("edge s2 -> s1: opposite"))
    }

    /// A Decision Tree Outcome is terminal, so nothing may point back out of it.
    /// The command greys out and says why; allowing the break enables it and
    /// routes the flip through an unknown edge type, which renders red and raises
    /// a quality warning — the break can never be silent.
    @Test func withoutAReverseTypeItWaitsForTheUserToAllowTheBreak() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node c: Choice "Take the offer";
                  node o: Outcome "Done";
                  edge c -> o;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        let greyed = EditorCore.menu(for: edgeId, in: s).first { $0.id == .changeDirection }
        #expect(greyed?.enabled == false)
        #expect(greyed?.title == "Change direction (breaks notation)")
        #expect(throws: VError.self) { try s.changeDirection(of: edgeId) }

        #expect(
            EditorCore.menu(for: edgeId, in: s, notationBreak: .permitted)
                .first { $0.id == .changeDirection }?.enabled == true)
        // No reversal on offer, so nothing to choose — the break reverses anyway.
        #expect(EditorCore.reversalOptions(for: edgeId, in: s).isEmpty)
        try s.changeDirection(of: edgeId, to: nil, notationBreak: .permitted)

        #expect(try s.exportVGL().contains("edge o -> c"))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    /// Edge-only: a node or a group has no direction to change.
    @Test func onlyEdgesOfferIt() throws {
        let s = try conceptMap()

        #expect(!EditorCore.menu(for: "a", in: s).contains { $0.id == .changeDirection })
        #expect(throws: VError.self) { try s.changeDirection(of: "a") }
    }
}
