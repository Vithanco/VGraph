//
//  ConnectGestureTest.swift
//  VGraph
//
//  The `connect` gesture: drag one node onto another to create the edge between
//  them. Covers `connect`, `connectSources` and `connectTargets` — what was once
//  a second command catalogue is now three named methods. See ADR-0012.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

@Suite("Drag to connect")
struct ConnectGestureTest {

    // MARK: - Fixtures

    /// Concept → Relation is declared; Concept → Concept is not.
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  node r: Relation "leads to";
                }
                """)
    }

    /// Two edge types join the only node type, so a drop cannot be decided from
    /// the two nodes alone.
    private func causalLoopDiagram() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                }
                """)
    }

    // MARK: - What may be grabbed

    /// The arity-0 prefix. Every node may start a drag — a node with nowhere legal
    /// to go is answered by a red line, not by refusing the grab (ADR-0012).
    @Test("With nothing chosen, every node may be grabbed")
    func everyNodeMayStartTheDrag() throws {
        let s = try conceptMap()

        #expect(Set(s.connectSources()) == ["a", "b", "r"])
    }

    /// An edge cannot end on a group (`edgeEndpointIsGroup`), so a group is not a
    /// notation matter and ⌥ cannot make it one.
    @Test("A group is never a target, permitted or not")
    func groupsAreNeverTargets() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                  node r: Relation "leads to";
                }
                """)

        #expect(!s.connectSources().contains("g1"))
        #expect(
            !s.connectTargets(from: "a", notationBreak: .permitted)
                .contains("g1"))
    }

    // MARK: - Where it may be dropped

    /// Landing back where the drag started is a slip far more often than an
    /// intention, even where the notation would allow the self-loop.
    @Test("The node just grabbed is never a destination")
    func theGrabbedNodeIsExcluded() throws {
        let s = try causalLoopDiagram()

        // CLD declares Stock → Stock, so nothing but this rule excludes s1.
        #expect(s.connectTargets(from: "s1") == ["s2"])
    }

    /// Only nodes the notation joins are offered; ⌥ is what turns the red line
    /// green mid-drag, and then it is every other node — a relationship can be
    /// declared to any of them (ADR-0024).
    @Test("Allowing the break opens every other node")
    func permittingTheBreakOpensEverything() throws {
        let s = try conceptMap()

        #expect(s.connectTargets(from: "a") == ["r"])
        #expect(
            Set(s.connectTargets(from: "a", notationBreak: .permitted))
                == ["b", "r"])
    }

    @Test("An exhausted bound closes the destination")
    func boundsPruneDestinations() throws {
        // Declared in a `vnotation` rather than reused from a shipped one: no
        // compiled notation bounds anything yet (ADR-0011).
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  edge type: next from: Step to: Step [samePairMax: 1]
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node s2: Step "Two";
                  edge s1 -> s2;
                }
                """)

        #expect(s.connectTargets(from: "s1").isEmpty)
        #expect(s.connectTargets(from: "s2") == ["s1"])
    }

    // MARK: - What the drop produces

    @Test("One applicable type is created without a prompt")
    func aSingleTypeNeedsNoPrompt() throws {
        let s = try conceptMap()

        // No question: EditorCore says so, and the method takes no type.
        #expect(EditorCore.connectOptions(from: "a", to: "r", notationBreak: .forbidden, in: s).isEmpty)
        try s.connect("a", to: "r")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge a -> r"))
        // Round-trips: the new edge matches a declared edge type.
        try s.replaceDocument(vgl: exported)
    }

    @Test("Several applicable types are asked about")
    func severalTypesAskWhich() throws {
        let s = try causalLoopDiagram()

        try s.connect("s1", to: "s2", using: EdgeType.Id(string: "opposite"))
        #expect(try s.exportVGL().contains("edge s1 -> s2: opposite"))
    }

    /// A drop the notation forbids is a no-op, not a break — the line was red and
    /// the drop has to mean what the line said.
    @Test("An illegal drop changes nothing")
    func anIllegalDropIsANoOp() throws {
        let s = try conceptMap()
        let before = try s.exportVGL()

        #expect(throws: VError.self) { try s.connect("a", to: "b") }
        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
        #expect(EditorCore.connectOptions(from: "a", to: "b", notationBreak: .forbidden, in: s).isEmpty)
    }

    @Test("Allowing the break connects a pair the notation never joins, but never a group")
    func permittingTheBreakConnectsAnythingButAGroup() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node c: Concept "C";
                  }
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)

        #expect(throws: VError.self) {
            try s.connect("a", to: "g1", using: nil, notationBreak: .permitted)
        }
        #expect(!s.canUndo)

        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)
        #expect(s.canUndo)

        let exported = try s.exportVGL()
        #expect(exported.contains("edge a -> b"))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
        try s.replaceDocument(vgl: exported)
    }

    /// ⌥ *is* the escape hatch here, so it always mints the break — even over a
    /// pair the notation would have joined happily (ADR-0012). What it leaves
    /// behind is promotable through the edge's **Change type** (ADR-0024), and
    /// is a state the document can hold, close and reopen — the property the
    /// whole of ADR-0024 rests on.
    @Test("A break over a pair the notation *does* join still reparses")
    func aBreakOverADeclarablePairReparses() throws {
        let s = try conceptMap()

        try s.connect("a", to: "r", using: nil, notationBreak: .permitted)

        try s.replaceDocument(vgl: try s.exportVGL())
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    @Test("A drop lands in history like any other command")
    func theDropIsOneUndoStep() throws {
        let s = try conceptMap()
        #expect(!s.canUndo)

        try s.connect("a", to: "r")
        #expect(s.canUndo)

        #expect(try s.undo() != nil)
        #expect(s.origin.edges.isEmpty)
        #expect(!(try s.exportVGL().contains("edge a -> r")))
    }

    @Test("A stale drop on a vanished node does nothing")
    func aStaleDropIsHarmless() throws {
        let s = try conceptMap()

        #expect(throws: VError.self) { try s.connect("a", to: "gone") }
        #expect(throws: VError.self) { try s.connect("gone", to: "a") }
    }
}
