//
//  ChangeNodeTypeTest.swift
//  VGraph
//
//  The ChangeType command: give a node another type, staying inside the notation
//  unless the user allows a break.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct ChangeNodeTypeTest {
    private func ibis() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: IBIS "Demo" {
                  node q: Question "Which way?";
                  node a: Answer "Turn left";
                  node p: Pro "It is quicker";
                  edge q -> a;
                  edge a -> p;
                }
                """)
    }

    /// An IBIS Answer is joined to a Pro, to a Con and to a Question, so a Pro can
    /// become either of the other two — but not an Answer, which nothing joins an
    /// Answer to.
    @Test func offersOnlyTheTypesEveryEdgeSurvives() throws {
        let s = try ibis()

        let options = EditorCore.retypeOptions(for: "p", notationBreak: .forbidden, in: s)
        #expect(options.map { $0.id } == ["Question", "Con"])
        // No "Other type…" until the user asks to go past the notation.
        #expect(!options.contains { $0.isBreak })

        try s.changeType(of: "p", to: NodeType(string: "Con"))

        let exported = try s.exportVGL()
        #expect(exported.contains("node p: Con \"It is quicker\""))
        #expect(!exported.contains("node p: Pro"))
        // Round-trips: the edge into it now matches a declared edge type.
        try s.replaceDocument(vgl: exported)
    }

    /// Nothing is deleted and re-added, so everything the user wrote about the
    /// node — its label, the comment above it, its place in the document — simply
    /// stays where it was. Contrast `reattach(edge:)`, which carries it by hand.
    @Test func keepsEverythingTheUserWroteAboutTheNode() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: IBIS "Demo" {
                  node q: Question "Which way?";
                  // the strongest argument we have
                  node p: Pro "It is quicker" [color: "#008000"];
                  node a: Answer "Turn left";
                  edge q -> a;
                  edge a -> p;
                }
                """)

        try s.changeType(of: "p", to: NodeType(string: "Con"))

        let exported = try s.exportVGL()
        #expect(exported.contains("// the strongest argument we have"))
        #expect(exported.contains("node p: Con \"It is quicker\" [backgroundcolor: \"#008000\"]"))
        // Still the second declaration, ahead of the Answer it hangs off.
        #expect(exported.range(of: "node p:")!.lowerBound < exported.range(of: "node a:")!.lowerBound)
    }

    /// A Concept Map joins a Relation to a Concept and to an EmphasizedConcept, so
    /// emphasising one is the single thing the notation allows — nothing to ask.
    @Test func theOnlySubstitutionNeedsNoQuestion() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)

        try s.changeType(of: "a", to: s.retypeCandidates(for: "a").first!)

        let exported = try s.exportVGL()
        #expect(exported.contains("node a: EmphasizedConcept \"A\""))
        try s.replaceDocument(vgl: exported)
    }

    /// A Concept Map Relation can only ever be reached from a Concept, so there is
    /// no other type it could be. The command greys out and says why; allowing the
    /// break enables it and routes the edge that no longer fits through an unknown
    /// edge type, which renders red and raises a quality warning.
    @Test func withNoSubstitutionItWaitsForTheUserToAllowTheBreak() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)

        let greyed = EditorCore.menu(for: "r", in: s).first { $0.id == .changeType }
        #expect(greyed?.enabled == false)
        #expect(greyed?.title == "Change type (breaks notation)")
        #expect(throws: VError.self) { try s.changeType(of: "r", to: NodeType(string: "Concept")) }

        // ⌥ offers the break and nothing else — the notation has no substitution.
        #expect(
            EditorCore.retypeOptions(for: "r", notationBreak: .permitted, in: s).map(\.isBreak)
                == [true])
        // Behind it, everything but what it already is.
        #expect(
            EditorCore.breakTypeOptions(in: s, excluding: "r").map { $0.id }
                == ["Concept", "EmphasizedConcept"])

        try s.changeType(
            of: "r", to: NodeType(string: "Concept"), edgeTypes: [], notationBreak: .permitted)

        #expect(try s.exportVGL().contains("node r: Concept \"leads to\""))
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
    }

    /// Where a notation declares two relationships between the same pair of types,
    /// the new node type does not say which one an edge should land on — so the
    /// command asks, once, for that edge alone.
    @Test func asksWhichRelationshipWhenTheNewTypeDoesNotDecideIt() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation RiskMap {
                  node type: Risk [nodeStyle: roundedBox, color: "#cc3333"]
                  node type: Issue [nodeStyle: roundedBox, color: "#3366cc"]
                  node type: Control [nodeStyle: roundedBox, color: "#339933"]

                  edge type: mitigated_by from: Risk to: Control
                  edge type: monitored_by from: Risk to: Control
                  edge type: fixed_by from: Issue to: Control
                }

                vgraph rm: RiskMap "Demo" {
                  node i1: Issue "Late delivery";
                  node c1: Control "Weekly review";
                  edge i1 -> c1;
                }
                """)

        // Only Risk keeps the edge to the Control attachable, so there is no type
        // question — straight to the edge one: two ways to attach it.
        let risk = s.retypeCandidates(for: "i1").first!
        let decisions = s.ambiguousEdges(ifRetyping: "i1", to: risk)
        #expect(decisions.map(\.prompt) == ["Late delivery → Weekly review"])
        #expect(decisions[0].options.map { $0.id.id } == ["mitigated_by", "monitored_by"])

        try s.changeType(of: "i1", to: risk, edgeTypes: [EdgeType.Id(string: "monitored_by")])

        let exported = try s.exportVGL()
        #expect(exported.contains("node i1: Risk \"Late delivery\""))
        #expect(exported.contains("edge i1 -> c1: monitored_by"))
        try s.replaceDocument(vgl: exported)
    }

    /// Two ambiguous edges, two questions — asked in the order the document
    /// declares them (`c2` first, though its id sorts second), and each naming its
    /// own ends, or a replayed answer would land on the wrong edge.
    @Test func asksAboutTheEdgesInDocumentOrder() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation RiskMap {
                  node type: Risk [nodeStyle: roundedBox, color: "#cc3333"]
                  node type: Issue [nodeStyle: roundedBox, color: "#3366cc"]
                  node type: Control [nodeStyle: roundedBox, color: "#339933"]

                  edge type: mitigated_by from: Risk to: Control
                  edge type: monitored_by from: Risk to: Control
                  edge type: fixed_by from: Issue to: Control
                }

                vgraph rm: RiskMap "Demo" {
                  node i1: Issue "Late delivery";
                  node c1: Control "Weekly review";
                  node c2: Control "Daily standup";
                  edge i1 -> c2;
                  edge i1 -> c1;
                }
                """)

        // Both questions up front, in the order the answers are consumed — which
        // is document order, not id order.
        let risk = s.retypeCandidates(for: "i1").first!
        #expect(
            s.ambiguousEdges(ifRetyping: "i1", to: risk).map(\.prompt)
                == ["Late delivery → Daily standup", "Late delivery → Weekly review"])

        try s.changeType(
            of: "i1", to: risk,
            edgeTypes: [EdgeType.Id(string: "mitigated_by"), EdgeType.Id(string: "monitored_by")])

        let exported = try s.exportVGL()
        #expect(exported.contains("edge i1 -> c2: mitigated_by"))
        #expect(exported.contains("edge i1 -> c1: monitored_by"))
    }

    /// A break already in the document is not a licence for another: the unknown
    /// edge type holding the broken Relation → Relation edge together is not
    /// offered as a way to make `c` a Relation.
    @Test func anExistingBreakDoesNotWidenWhatIsAllowed() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node r1: Relation "a";
                  node r2: Relation "b";
                  edge r1 -> r2;
                  node c: Concept "C";
                  node r3: Relation "leads to";
                  edge c -> r3;
                }
                """)
        #expect(!GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)

        #expect(s.origin.retypeCandidates(for: Node(string: "c")).map { $0.id } == ["EmphasizedConcept"])
    }

    /// A loop is the one edge whose *both* ends move with the node, so the type
    /// it lands on is the one joining the new type to itself.
    @Test func aLoopMovesBothOfItsEnds() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  node type: Task [nodeStyle: roundedBox, color: "#339933"]

                  edge type: step_repeats from: Step to: Step
                  edge type: task_repeats from: Task to: Task
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "Review";
                  edge s1 -> s1;
                }
                """)

        try s.changeType(of: "s1", to: s.retypeCandidates(for: "s1").first!)

        let exported = try s.exportVGL()
        #expect(exported.contains("node s1: Task \"Review\""))
        #expect(exported.contains("edge s1 -> s1"))
        try s.replaceDocument(vgl: exported)
        #expect(try s.origin.edgeType(for: s.origin.edges.first!.id).id.id == "task_repeats")
    }

    /// Every kind offers `changeType` now, but each answers from its own list
    /// (ADR-0020, ADR-0023). The node form is still node-only: a `NodeType` is
    /// not something an edge can be given.
    @Test func theNodeFormIsRefusedForAnEdge() throws {
        let s = try ibis()
        let edgeId = s.origin.edges.first!.id.id

        #expect(EditorCore.menu(for: edgeId, in: s).contains { $0.id == .changeType })
        #expect(s.retypeCandidates(for: edgeId).isEmpty)
        #expect(throws: VError.self) { try s.changeType(of: edgeId, to: NodeType(string: "Con")) }
    }
}
