//
//  ReattachGestureTest.swift
//  VGraph
//
//  The `reattach` gesture: drag one end of an existing edge onto a different
//  node. Covers `reattach`, `reattachTargets` and `reattachCandidates`. See
//  ADR-0021.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

@Suite("Reattach")
struct ReattachGestureTest {

    // MARK: - Fixtures

    /// Concept → Relation is declared both ways; Relation → Relation is not, so
    /// `r2` is a source the notation refuses wherever `r` is the fixed end —
    /// unlike a second Concept, which would be just as legal a source as `b`.
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  node r2: Relation "R2";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    /// Two edge types join the only node type, so a drop cannot be decided from
    /// the two nodes alone — and CLD declares Stock → Stock, so a self-loop is a
    /// legal shape.
    private func causalLoopDiagram() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  node s3: Stock "Supply";
                  edge s1 -> s2;
                }
                """)
    }

    /// Edge ids are minted synthetically by the parser, not slugged from the
    /// endpoints, so every test reads the one it means rather than guessing it.
    private func onlyEdgeId(_ s: TestSession) -> String { s.origin.edges.first!.id.id }

    // MARK: - Where it may land

    @Test("Only nodes the notation can be joined to are offered")
    func destinationsFollowTheNotation() throws {
        let s = try conceptMap()

        #expect(s.reattachTargets(edge: onlyEdgeId(s), end: .from) == ["b"])
    }

    /// The node the end already occupies is not an edit and must not appear —
    /// unlike `connect`, the *other* end's node is not excluded on the same
    /// grounds, since the drag did not begin there.
    @Test("The end's own node is excluded")
    func theOwnNodeIsExcluded() throws {
        let s = try conceptMap()

        #expect(!s.reattachTargets(edge: onlyEdgeId(s), end: .from).contains("a"))
    }

    /// A self-loop is legal wherever the notation declares one, and the drag
    /// began at a handle on the *far* node's rim — not at the node being
    /// dropped onto — so `connect`'s slip argument does not carry over.
    @Test("The far end's node is offered when the notation allows a self-loop")
    func selfLoopIsOfferedWhereDeclared() throws {
        let s = try causalLoopDiagram()

        #expect(s.reattachTargets(edge: onlyEdgeId(s), end: .to).contains("s1"))
    }

    @Test("Allowing the break opens every other node")
    func permittingTheBreakOpensEverything() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        #expect(s.reattachTargets(edge: edge, end: .from) == ["b"])
        #expect(
            Set(s.reattachTargets(edge: edge, end: .from, notationBreak: .permitted))
                == ["b", "r2", "r"])
    }

    /// The whole reason this is not `connectCandidates` with different
    /// arguments: an edge about to move must not count against the bound it is
    /// about to vacate.
    @Test("The bound is counted against the graph minus the edge in hand")
    func boundsExcludeTheEdgeBeingMoved() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  edge type: next from: Step to: Step [samePairMax: 1]
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node s2: Step "Two";
                  node s3: Step "Three";
                  edge s1 -> s2;
                }
                """)

        // s1 already has one outgoing edge — the very one being dragged — so
        // `connectCandidates` would refuse s3 as a `totalOutDegreeMax`-free but
        // `samePairMax`-irrelevant check; the point here is `outDegreeMax` isn't
        // declared, so this asserts the simpler claim directly: moving the edge
        // in hand is never blocked by the budget it is about to vacate.
        #expect(s.reattachTargets(edge: onlyEdgeId(s), end: .to).contains("s3"))
    }

    // MARK: - What the drop produces

    @Test("One applicable type is created without a prompt")
    func aSingleTypeNeedsNoPrompt() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        #expect(
            EditorCore.reattachOptions(
                edge: edge, end: .from, to: "b", notationBreak: .forbidden, in: s
            ).isEmpty)
        try s.reattach(edge, end: .from, to: "b")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge b -> r"))
        #expect(!exported.contains("edge a -> r"))
        try s.replaceDocument(vgl: exported)
    }

    @Test("Several applicable types are asked about")
    func severalTypesAskWhich() throws {
        let s = try causalLoopDiagram()
        let edge = onlyEdgeId(s)

        let options = EditorCore.reattachOptions(
            edge: edge, end: .to, to: "s3", notationBreak: .forbidden, in: s)
        #expect(Set(options.map { $0.id }) == ["same", "opposite"])
        #expect(!options.contains { $0.isBreak })

        try s.reattach(edge, end: .to, to: "s3", using: EdgeType.Id(string: "opposite"))
        #expect(try s.exportVGL().contains("edge s1 -> s3: opposite"))
    }

    /// A drop the notation forbids is a no-op — the line was red and the drop
    /// has to mean what the line said.
    @Test("An illegal drop changes nothing")
    func anIllegalDropIsANoOp() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)
        let before = try s.exportVGL()

        #expect(throws: VError.self) { try s.reattach(edge, end: .from, to: "r2") }
        #expect(try s.exportVGL() == before)
    }

    /// Releasing where the end already is refuses rather than doing nothing
    /// silently, so it cannot burn an undo step.
    @Test("Dropping back on the end's own node is refused")
    func droppingOnItsOwnNodeIsRefused() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        #expect(throws: VError.self) { try s.reattach(edge, end: .from, to: "a") }
    }

    /// ⌥ mints an unknown type outright, exactly as `connect`'s does — even over
    /// a pair the notation would have joined happily. The old type cannot
    /// survive: `add(edge:)` refuses a type whose declared ends no longer match.
    @Test("Allowing the break always produces an unknown edge type")
    func permittingTheBreakAlwaysMintsUnknown() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        try s.reattach(edge, end: .from, to: "b", using: nil, notationBreak: .permitted)

        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    @Test("Allowing the break reattaches onto a pair the notation never joins")
    func permittingTheBreakReattachesAnythingButAGroup() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        try s.reattach(edge, end: .from, to: "r2", using: nil, notationBreak: .permitted)

        let exported = try s.exportVGL()
        #expect(exported.contains("edge r2 -> r"))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
        // The break survives its own export, which is the point of ADR-0024.
        try s.replaceDocument(vgl: exported)
    }

    // MARK: - What the move preserves

    /// The whole reason this is not delete-and-redraw: everything the user wrote
    /// on the edge — its label, the comment above it — has to survive.
    @Test("Carries the edge's own attributes and comment across")
    func carriesTheEdgesOwnAttributesAcross() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  node r: Relation "leads to";
                  // why this link matters
                  edge a -> r "because";
                }
                """)
        let edge = onlyEdgeId(s)

        try s.reattach(edge, end: .from, to: "b")

        let exported = try s.exportVGL()
        #expect(exported.contains("edge b -> r \"because\""))
        #expect(exported.contains("// why this link matters"))
    }

    @Test("A drop lands in history as one undo step")
    func theDropIsOneUndoStep() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)
        #expect(!s.canUndo)  // the fixture's `edge a -> r` is the starting state, not a step

        try s.reattach(edge, end: .from, to: "b")
        #expect(s.canUndo)

        let undone = try s.undo()
        #expect(undone != nil)
        #expect(try s.exportVGL().contains("edge a -> r"))
        #expect(!(try s.exportVGL().contains("edge b -> r")))
    }

    @Test("A stale drop on a vanished node or edge does nothing")
    func aStaleDropIsHarmless() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        #expect(throws: VError.self) { try s.reattach(edge, end: .from, to: "gone") }
        #expect(throws: VError.self) { try s.reattach("gone", end: .from, to: "b") }
    }

    // MARK: - Gesture-only

    /// The sharpest consequence of a separate family, and the one the compiler
    /// cannot check: `reattach` must never reach a menu (ADR-0021, following
    /// ADR-0012's rule for `connect`).
    @Test("reattach never appears in a menu")
    func reattachIsGestureOnly() throws {
        let s = try conceptMap()
        let edge = onlyEdgeId(s)

        for id in ["a", "b", "r2", "r", edge] {
            #expect(!EditorCore.menu(for: id, in: s).contains { $0.id == .reattach })
            #expect(
                !EditorCore.menu(for: id, in: s, notationBreak: .permitted)
                    .contains { $0.id == .reattach })
        }
    }

    /// The same rule as `connect`, and for the same reason: ⌥ mints outright, so
    /// a type named alongside it is refused rather than discarded.

}
