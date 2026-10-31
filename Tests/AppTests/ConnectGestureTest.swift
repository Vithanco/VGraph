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

    @Test("Only nodes the notation can be joined to are offered")
    func destinationsFollowTheNotation() throws {
        let s = try conceptMap()

        #expect(s.connectTargets(from: "a") == ["r"])
    }

    /// Landing back where the drag started is a slip far more often than an
    /// intention, even where the notation would allow the self-loop.
    @Test("The node just grabbed is never a destination")
    func theGrabbedNodeIsExcluded() throws {
        let s = try causalLoopDiagram()

        // CLD declares Stock → Stock, so nothing but this rule excludes s1.
        #expect(s.connectTargets(from: "s1") == ["s2"])
    }

    /// What turns the red line green mid-drag. Still every node under ⌥ — a
    /// relationship can be declared to any of them (ADR-0024).
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

    /// The gesture's whole reason for existing is that `arity` is satisfied.
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

        let options = EditorCore.connectOptions(
            from: "s1", to: "s2", notationBreak: .forbidden, in: s)
        #expect(Set(options.map { $0.id }) == ["same", "opposite"])
        // ⌥ is the escape hatch for this command, so the list carries none.
        #expect(!options.contains { $0.isBreak })
        // The prompt is the editor's to build now, from the two labels.
        #expect(s.label(of: "s1") == "Price" && s.label(of: "s2") == "Demand")

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
    }

    /// ⌥ *is* the escape hatch here, so it always mints the break — even over a
    /// pair the notation would have joined happily (ADR-0012). What it leaves
    /// behind is promotable through the edge's **Change type** (ADR-0024).
    @Test("Allowing the break always produces an unknown edge type")
    func permittingTheBreakAlwaysMintsUnknown() throws {
        let s = try conceptMap()

        try s.connect("a", to: "r", using: nil, notationBreak: .permitted)

        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    @Test("Allowing the break connects a pair the notation never joins")
    func permittingTheBreakConnectsAnythingButAGroup() throws {
        let s = try conceptMap()

        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)

        let exported = try s.exportVGL()
        #expect(exported.contains("edge a -> b"))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
        try s.replaceDocument(vgl: exported)
    }

    /// The property the whole of ADR-0024 rests on: a break is a state the
    /// document can hold, close and reopen.
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

    // MARK: - Where the new edge belongs

    @Test("An edge between two members joins their group")
    func anEdgeWithinAGroupJoinsIt() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                    node r: Relation "leads to";
                  }
                }
                """)

        try s.connect("a", to: "r")
        #expect(s.origin.group(of: Edge.Id(string: "a_r")) == Group(rawValue: "g1"))
    }

    /// Neither group holds both ends, so the edge falls back to the group that
    /// does — the root, same as for a node nobody grouped.
    @Test("An edge across groups belongs to neither")
    func anEdgeAcrossGroupsIsUngrouped() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "One" {
                    node a: Concept "A";
                  }
                  group g2 "Two" {
                    node r: Relation "leads to";
                  }
                }
                """)

        try s.connect("a", to: "r")
        #expect(s.origin.group(of: Edge.Id(string: "a_r")) == Group(rawValue: rootGroup))
    }

    // MARK: - Gesture-only

    /// The sharpest consequence of a separate family, and the one the compiler
    /// cannot check: `connect` must never reach a menu (ADR-0012).
    ///
    /// It used to also assert `connect` was absent from the menu registry. There
    /// is no registry now — `EditorCore.commands(on:)` lists what each kind
    /// offers, and `connect` is simply not among them — so the menu itself is
    /// the only place left to check, which is where a user would have seen it.
    @Test("connect never appears in a menu")
    func connectIsGestureOnly() throws {
        let s = try conceptMap()

        for id in ["a", "b", "r"] {
            #expect(!EditorCore.menu(for: id, in: s).contains { $0.id == .connect })
            #expect(
                !EditorCore.menu(for: id, in: s, notationBreak: .permitted)
                    .contains { $0.id == .connect })
        }
        // `connect` is not a menu command at all: the drag is the only way in.
    }

}
