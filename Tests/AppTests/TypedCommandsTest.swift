//  The named command surface: what it refuses, the queries that feed a menu,
//  and the option shapes only a second adapter would see.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

/// Two relationships between Risk and Control, so retyping an Issue to a Risk
/// leaves its one edge ambiguous — the smallest graph that asks.
private func riskMap() throws -> TestSession {
    try makeTestSession(
        vgl: """
            \(riskMapNotation)

            vgraph rm: RiskMap "Demo" {
              node i1: Issue "Late delivery";
              node c1: Control "Weekly review";
              edge i1 -> c1;
            }
            """)
}

/// What a named command does when it will not run.
struct NamedCommandRefusalTest {
    private let conceptMap = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
          }
          node r: Relation "leads to";
          edge a -> r;
        }
        """

    /// A named call refuses rather than shrugging. A menu may shrug — a stale
    /// click is harmless — but a caller that named both its command and its
    /// target has said something wrong, and silence would hide it. Nothing
    /// applied, so nothing is recorded: a throw must not leave a half-step in
    /// [[History]].
    @Test func aNamedCommandRefusesWhatItCannotDo() throws {
        let session = try makeTestSession(vgl: conceptMap)
        let before = try session.exportVGL()

        #expect(throws: VError.self) { try session.toggleFolding(of: "a") }  // not a group
        #expect(throws: VError.self) { try session.toggleFolding(of: "ghost") }  // no such element
        #expect(throws: VError.self) { try session.delete("ghost") }  // no such element
        #expect(throws: VError.self) { try session.removeURL(from: "a") }  // no link stored

        #expect(session.canUndo == false)
        #expect(try session.exportVGL() == before)
    }
}

/// Naming an option the domain never offered.
///
/// The commands that take a choice all resolve it against a candidate list, and
/// four of them used to answer a miss by returning successfully having changed
/// nothing — the `.unavailable` shrug ADR-0013 claims to have removed, wearing a
/// different coat. A caller that named a command, a target *and* an option has
/// said three things, and getting the third wrong is still saying something
/// wrong. `MenuAgreesWithExecutionTest` cannot catch these: it only ever replays
/// options the domain just offered. (`addSuccessor`'s is in `AddSuccessorTest`.)
struct NamedCommandOptionRefusalTest {
    /// Two reversals on offer, so the command asks — and an answer naming
    /// neither is not one of them.
    @Test func changeDirectionRefusesAReversalItDidNotOffer() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id
        let before = try s.exportVGL()
        #expect(s.reverseCandidates(for: edgeId).count > 1)

        #expect(
            throws: VError.commandOptionNotOffered(
                .changeDirection, target: edgeId, option: "nonsense")
        ) {
            try s.changeDirection(of: edgeId, to: EdgeType.Id(string: "nonsense"))
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    @Test func addPredecessorRefusesARelationshipItDidNotOffer() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        #expect(!s.predecessorCandidates(to: "a").isEmpty)

        #expect(
            throws: VError.commandOptionNotOffered(.addPredecessor, target: "a", option: "nonsense")
        ) {
            try s.addPredecessor(to: "a", using: EdgeType.Id(string: "nonsense"))
        }

        #expect(s.canUndo == false)
    }

    /// The drag-to-connect path. More than one type joins two Stocks, so the
    /// drop asks; an answer outside that list is refused rather than dropped.
    @Test func connectRefusesAnEdgeTypeItDidNotOffer() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                }
                """)
        let before = try s.exportVGL()
        #expect(s.connectCandidates(from: "s1", to: "s2").count > 1)

        #expect(
            throws: VError.commandOptionNotOffered(.connect, target: "s2", option: "nonsense")
        ) {
            try s.connect("s1", to: "s2", using: EdgeType.Id(string: "nonsense"))
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    /// `changeType` is the one command that holds a conversation, so its answers
    /// go astray in two ways: too few, and one that names no option. The second
    /// used to leave the node un-retyped with no word said.
    @Test func changeTypeRefusesAnEdgeAnswerItDidNotOffer() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!
        let before = try s.exportVGL()
        #expect(s.ambiguousEdges(ifRetyping: "i1", to: risk).count == 1)

        #expect(
            throws: VError.commandOptionNotOffered(.changeType, target: "i1", option: "nonsense")
        ) {
            try s.changeType(of: "i1", to: risk, edgeTypes: [EdgeType.Id(string: "nonsense")])
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }
}

/// The answers a command requires are a **precondition**, checked on entry.
///
/// The adapter asks first — `reverseCandidates`, `connectCandidates`,
/// `ambiguousEdges(ifRetyping:to:)` — and then calls once, carrying everything.
/// Nothing here resumes: a throw ends the command and the editor closes the
/// menu. `commandAnswersMismatched` was `commandNeedsMoreInput` while the replay
/// loop existed to supply the missing input; ADR-0013 deleted the loop, and the
/// obligation it leaves behind sits entirely with the caller.
///
/// None of this is reachable from the WASM editor by construction — it only
/// calls once its own question list is exhausted. These pin the contract for the
/// second adapter, and for the case where the graph moves under a conversation.
struct NamedCommandAnswerPreconditionTest {
    // MARK: - An answer was required and none came

    /// One reversal is picked without asking, so `nil` is a legitimate call. Two
    /// is a question, and `nil` no longer answers it.
    @Test func changeDirectionRefusesNilWhenThereIsAChoice() throws {
        let s = try twoReversals()
        let edgeId = s.origin.edges.first!.id.id
        let before = try s.exportVGL()
        #expect(s.reverseCandidates(for: edgeId).count > 1)

        #expect(throws: VError.commandAnswersMismatched(.changeDirection, target: edgeId)) {
            try s.changeDirection(of: edgeId, to: nil)
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    /// The same rule on the drop: one edge type joining the pair is chosen for
    /// the user, more than one has to be named.
    @Test func connectRefusesNilWhenThereIsAChoice() throws {
        let s = try twoConnections()
        let before = try s.exportVGL()
        #expect(s.connectCandidates(from: "s1", to: "s2").count > 1)

        #expect(throws: VError.commandAnswersMismatched(.connect, target: "s2")) {
            try s.connect("s1", to: "s2", using: nil)
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    // MARK: - The count has to match, in both directions

    @Test func changeTypeRefusesTooFewAnswers() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!
        let before = try s.exportVGL()
        #expect(s.ambiguousEdges(ifRetyping: "i1", to: risk).count == 1)

        #expect(throws: VError.commandAnswersMismatched(.changeType, target: "i1")) {
            try s.changeType(of: "i1", to: risk, edgeTypes: [])
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    /// The direction that used to pass. A surplus meant the caller's list came
    /// from a different set of questions, so its answers may be aligned to edges
    /// it was never asked about — and the extras were dropped in silence.
    @Test func changeTypeRefusesMoreAnswersThanItAskedFor() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!
        let before = try s.exportVGL()
        #expect(s.ambiguousEdges(ifRetyping: "i1", to: risk).count == 1)

        #expect(throws: VError.commandAnswersMismatched(.changeType, target: "i1")) {
            try s.changeType(
                of: "i1", to: risk,
                edgeTypes: [
                    EdgeType.Id(string: "monitored_by"), EdgeType.Id(string: "mitigated_by"),
                ])
        }

        #expect(s.canUndo == false)
        #expect(try s.exportVGL() == before)
    }

    // MARK: - The graph operation underneath holds the same line

    // `GraphSession` guards the count before delegating, so these pin that
    // `VGraph.retyping` refuses on its own too — a second caller reaching the
    // domain directly cannot slip past.

    @Test func retypingRefusesWhenItRunsOutOfAnswers() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!
        let node = s.origin.nodes.first { $0.id == "i1" }!

        #expect(throws: VError.commandAnswersMismatched(.changeType, target: "i1")) {
            _ = try s.origin.retyping(node, to: risk, edgeTypes: [])
        }
    }

    @Test func retypingRefusesAnswersItNeverConsumed() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!
        let node = s.origin.nodes.first { $0.id == "i1" }!

        #expect(throws: VError.commandAnswersMismatched(.changeType, target: "i1")) {
            _ = try s.origin.retyping(
                node, to: risk,
                edgeTypes: [
                    EdgeType.Id(string: "monitored_by"), EdgeType.Id(string: "mitigated_by"),
                ])
        }
    }

    // MARK: - Fixtures

    private func twoReversals() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
    }

    private func twoConnections() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                }
                """)
    }
}

/// The queries a pane builds its own menu from.
struct MenuQueriesTest {
    private func session() throws -> TestSession {
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

    @Test func kindNamesWhatTheIdIs() throws {
        let s = try session()
        #expect(s.kind(of: "a") == .node)
        #expect(s.kind(of: "g1") == .group)
        #expect(s.kind(of: s.origin.edges.first!.id.id) == .edge)
        #expect(s.kind(of: "ghost") == nil)
        #expect(s.label(of: "ghost") == nil)
    }

    /// A wrong-kind or unknown id answers empty rather than trapping — a stale
    /// click must stay harmless on the query side too.
    @Test func aWrongIdAnswersEmpty() throws {
        let s = try session()
        #expect(s.successorCandidates(from: "ghost").isEmpty)
        #expect(s.retypeCandidates(for: "g1").isEmpty)  // a group is not a node
        #expect(s.reverseCandidates(for: "a").isEmpty)  // a node is not an edge
        #expect(s.reverseCandidates(for: "ghost").isEmpty)
    }

    /// Unknown types are the *result* of a break, never an option for one — so
    /// the document has to hold one for the exclusion to have anything to do.
    @Test func nodeTypesExcludesUnknownTypes() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node x: InvalidType "X";
                }
                """)
        #expect(s.origin.nodeTypes.contains { $0.id.hasPrefix(NodeType.unknownPrefix) })

        #expect(!s.nodeTypes().isEmpty)
        #expect(!s.nodeTypes().contains { $0.id.hasPrefix(NodeType.unknownPrefix) })
    }
}

/// A command that produces no change must leave no trace.
struct NoChangeNoHistoryTest {
    /// A command whose result matches what is already stored must leave no
    /// trace — an undo step that undoes nothing is worse than none. The real
    /// change after it is the control: the guard must not swallow those.
    @Test func aCommandThatChangesNothingCutsNoUndoStep() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        // Normalise first, so `currentVGL` is the canonical text a command
        // would re-export — and reset history along with it.
        try session.replaceDocument(vgl: try session.exportVGL())
        #expect(session.canUndo == false)

        try session.setLabel(of: "a", to: "A")

        #expect(session.canUndo == false, "a command that changed nothing cut an undo step")

        try session.setLabel(of: "a", to: "Renamed")

        #expect(session.canUndo == true)
    }

    /// Retyping to what it already is changes nothing — a second adapter's path,
    /// since the editor's list leaves the current type out.
    @Test func retypingToTheSameTypeCutsNoUndoStep() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
        let before = try s.exportVGL()
        try s.replaceDocument(vgl: before)
        let same = try #require(s.nodeTypes().first { $0.id == "Concept" })

        try s.changeType(of: "a", to: same, edgeTypes: [], notationBreak: .permitted)

        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == false)
    }
}

/// `split` asks a narrower question than `addSuccessor`: the break entry is
/// offered only when the user asks for it. What `begin` cannot show is the
/// shape of the list itself, so it is pinned here.
struct SplitOptionsTest {
    /// A GoalTree `n -> c` has exactly one insertion.
    private func session() throws -> (TestSession, edge: String) {
        let s = try makeTestSession(
            vgl: """
                vgraph gt: GoalTree "Demo" {
                  node g: Goal "Win";
                  node c: CriticalSuccessFactor "Ship";
                  node n: NecessaryCondition "Test";
                  edge c -> g;
                  edge n -> c;
                }
                """)
        return (s, s.origin.edges.first { $0.from.id == "n" && $0.to.id == "c" }!.id.id)
    }

    /// One insertion is no question — the editor applies it without a list.
    @Test func oneInsertionIsNoQuestion() throws {
        let (s, edgeId) = try session()

        #expect(s.splitCandidates(for: edgeId).count == 1)
        #expect(EditorCore.splitOptions(for: edgeId, notationBreak: .forbidden, in: s).isEmpty)
    }

    /// ⌥ turns it into one: the same single insertion, now beside the break.
    @Test func permittingTheBreakMakesItAQuestion() throws {
        let (s, edgeId) = try session()

        let options = EditorCore.splitOptions(for: edgeId, notationBreak: .permitted, in: s)
        #expect(options.count == 2)
        #expect(options.last?.isBreak == true)
    }
}

/// `connect` is the only command where ⌥ replaces the question instead of
/// widening it.
struct ConnectOptionsTest {
    /// ⌥ does not widen the list — it *replaces* it. The gesture's escape hatch
    /// mints an unknown edge type outright, so there is nothing to choose.
    @Test func permittingTheBreakAsksNothing() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                }
                """)

        #expect(s.connectCandidates(from: "s1", to: "s2").count > 1)
        #expect(
            EditorCore.connectOptions(from: "s1", to: "s2", notationBreak: .forbidden, in: s).count
                > 1)
        #expect(
            EditorCore.connectOptions(from: "s1", to: "s2", notationBreak: .permitted, in: s)
                .isEmpty)
    }
}
