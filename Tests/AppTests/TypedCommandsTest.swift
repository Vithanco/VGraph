//  The named command surface: what it refuses, the queries that feed a menu,
//  and the option lists an adapter builds from them.
//
//  This file began as a comparison — every named command run beside its generic
//  twin, asserting the exported VGL matched. That comparison is what made the
//  inlining safe, and it retired with the generic path it compared against.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

/// What a named command does when it will not run.
///
/// The per-command suites cover the happy paths. These are the two rules that
/// hold across all twelve, and they are what is left of the comparison against
/// the generic path — which no longer exists to compare with.
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
    /// target has said something wrong, and silence would hide it.
    @Test func aNamedCommandRefusesWhatItCannotDo() throws {
        let session = try makeTestSession(vgl: conceptMap)

        #expect(throws: VError.self) { try session.toggleFolding(of: "a") }  // not a group
        #expect(throws: VError.self) { try session.delete("ghost") }  // no such element
        #expect(throws: VError.self) { try session.removeURL(from: "a") }  // no link stored
    }

    /// Nothing applied, so nothing recorded — a throw must not leave a half-step
    /// in [[History]].
    @Test func aRefusedCommandLeavesNoHistory() throws {
        let session = try makeTestSession(vgl: conceptMap)
        let before = try session.exportVGL()

        #expect(throws: VError.self) { try session.toggleFolding(of: "a") }

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
/// options the domain just offered.
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

    @Test func addSuccessorRefusesARelationshipItDidNotOffer() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        let before = try s.exportVGL()
        #expect(!s.successorCandidates(from: "a").isEmpty)

        #expect(
            throws: VError.commandOptionNotOffered(.addSuccessor, target: "a", option: "nonsense")
        ) {
            try s.addSuccessor(from: "a", using: EdgeType.Id(string: "nonsense"))
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

    /// Two relationships between Risk and Control, so retyping an Issue to a
    /// Risk leaves its one edge ambiguous — the smallest graph that asks.
    private func riskMap() throws -> TestSession {
        try makeTestSession(
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

    /// Exactly right still works — the guard tightened without narrowing what a
    /// correct caller may do.
    @Test func changeTypeAcceptsExactlyTheAnswersItAskedFor() throws {
        let s = try riskMap()
        let risk = s.retypeCandidates(for: "i1").first!

        try s.changeType(of: "i1", to: risk, edgeTypes: [EdgeType.Id(string: "monitored_by")])

        #expect(try s.exportVGL().contains("edge i1 -> c1: monitored_by"))
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

    private func riskMap() throws -> TestSession {
        try makeTestSession(
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
    }
}

/// The queries that replace `origin` for a pane building its own menu.
/// Each must agree with the graph it forwards to — they exist so the pane can
/// stop being handed the whole model (phase 5).
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
    }

    @Test func theTwoDynamicTitlesHaveTheirQueries() throws {
        let s = try session()

        #expect(s.isFolded("g1") == false)
        try s.toggleFolding(of: "g1")
        #expect(s.isFolded("g1") == true)
        #expect(s.isFolded("a") == false)  // not a group

        #expect(s.storedURL(of: "a") == nil)
        try s.setURL(of: "a", to: "https://example.com")
        #expect(s.storedURL(of: "a") == "https://example.com")
    }

    /// `storedURL` and `urlToOpen` deliberately disagree: a link typed straight
    /// into the VGL never passed `VURL`, so it is stored but not followable —
    /// and "Remove URL" must still be offered for exactly that link. Seeding the
    /// field from `urlToOpen` would throw the user's own text away.
    @Test func storedURLAndUrlToOpenAreNotTheSameQuestion() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A" [url: "javascript:alert(1)"];
                }
                """)

        #expect(s.storedURL(of: "a") == "javascript:alert(1)")
        #expect(s.urlToOpen(of: "a") == nil)
    }

    @Test func candidateQueriesAgreeWithTheGraph() throws {
        let s = try session()
        let edgeId = s.origin.edges.first!.id
        guard case .node(let a)? = s.origin.resolveCommandTarget(id: "a") else { return }

        #expect(s.successorCandidates(from: "a") == s.origin.successorCandidates(from: a))
        #expect(s.predecessorCandidates(to: "a") == s.origin.predecessorCandidates(to: a))
        #expect(s.retypeCandidates(for: "a") == s.origin.retypeCandidates(for: a))
        #expect(s.reverseCandidates(for: edgeId.id) == s.origin.reverseCandidates(for: edgeId))
        #expect(s.splitCandidates(for: edgeId.id) == s.origin.splitCandidates(for: edgeId))
    }

    /// A wrong-kind or unknown id answers empty rather than trapping — a stale
    /// click must stay harmless on the query side too.
    @Test func aWrongIdAnswersEmpty() throws {
        let s = try session()
        #expect(s.successorCandidates(from: "ghost").isEmpty)
        #expect(s.retypeCandidates(for: "g1").isEmpty)  // a group is not a node
        #expect(s.reverseCandidates(for: "a").isEmpty)  // a node is not an edge
    }

    /// Unknown types are the *result* of a break, never an option for one.
    @Test func nodeTypesExcludesUnknownTypes() throws {
        let s = try session()
        #expect(!s.nodeTypes().isEmpty)
        #expect(!s.nodeTypes().contains { $0.id.hasPrefix(NodeType.unknownPrefix) })
    }
}

/// The judgements the editor now makes for itself, kept in `EditorCore` so they
/// stay testable. See ADR-0013.
struct EditorCoreChoicesTest {
    /// A CLD joins Stock to Stock two ways — same and opposite — so reversing is
    /// a genuine question.
    @Test func moreThanOneReversalIsAQuestion() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        let options = EditorCore.reversalOptions(for: edgeId, in: s)
        #expect(options.count == s.reverseCandidates(for: edgeId).count)
        #expect(options.count > 1)
    }

    /// One candidate is not a choice, and none is not either — the command
    /// reverses without asking in both cases, so the editor must not put an
    /// empty or one-item list on screen.
    @Test func oneReversalOrNoneIsNotAQuestion() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node c: Choice "Pick";
                  node o: Outcome "Done";
                  edge c -> o;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        #expect(s.reverseCandidates(for: edgeId).count <= 1)
        #expect(EditorCore.reversalOptions(for: edgeId, in: s).isEmpty)
    }

    @Test func anUnknownIdIsNotAQuestion() throws {
        let s = try makeTestSession(vgl: "vgraph d: ConceptMap \"D\" { node a: Concept \"A\"; }")
        #expect(EditorCore.reversalOptions(for: "ghost", in: s).isEmpty)
    }
}

/// A command that produces no change must leave no trace.
struct NoChangeNoHistoryTest {
    /// A command whose result matches what is already stored must leave no
    /// trace — an undo step that undoes nothing is worse than none.
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

        // Setting a label to what it already is. "Rename" from the menu used to
        // be the other case, back when opening an editor went through a command
        // at all; it now touches nothing, so there is nothing left to guard.
        try session.setLabel(of: "a", to: "A")

        #expect(session.canUndo == false, "a command that changed nothing cut an undo step")
    }

    /// The guard must not swallow real changes.
    @Test func aRealChangeStillCutsAStep() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        try session.setLabel(of: "a", to: "Renamed")
        #expect(session.canUndo == true)
        #expect(session.label(of: "a") == "Renamed")
    }
}

/// `setURL` is the one named command that refuses ordinary user input rather
/// than programmer error, and the editor relies on that: a throw means "ask
/// again holding what was typed".
struct SetURLContractTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
    }

    @Test func aSafeLinkIsStored() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://example.com")
        #expect(s.storedURL(of: "a") == "https://example.com")
        #expect(s.urlToOpen(of: "a") == "https://example.com")
    }

    /// The throw the editor catches to re-ask. Nothing is stored and no undo
    /// step is cut — a rejected keystroke must not land in [[History]].
    @Test func aLinkVURLRefusesIsNotStored() throws {
        let s = try session()

        #expect(throws: VError.self) { try s.setURL(of: "a", to: "javascript:alert(1)") }

        #expect(s.storedURL(of: "a") == nil)
        #expect(s.canUndo == false)
    }

    /// Blank clears rather than refuses, so the field is how a link is removed
    /// as well as set.
    @Test func blankClearsTheLink() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://example.com")
        try s.setURL(of: "a", to: "   ")

        #expect(s.urlToOpen(of: "a") == nil)
        #expect(s.canUndo == true)  // clearing is a change worth undoing
    }
}

/// The option lists the editor now builds for itself, kept in `EditorCore` so
/// the judgements stay testable (phase 6e).
struct RelatedOptionsTest {
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                }
                """)
    }

    /// The break entry is always last and always present — that is what makes a
    /// [[Notation break]] reachable from the list.
    @Test func theBreakEntryIsAlwaysOffered() throws {
        let s = try conceptMap()
        let options = EditorCore.relatedOptions(from: "a", outgoing: true, in: s)

        #expect(options.last?.isBreak == true)
        #expect(options.count == s.successorCandidates(from: "a").count + 1)
    }

    /// A terminal node type: the notation offers nothing, so the break is the
    /// only entry. Before `VAvailability` this case was unreachable entirely.
    @Test func aTerminalTypeOffersOnlyTheBreak() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph dt: DecisionTree "Demo" {
                  node o: Outcome "Done";
                }
                """)
        let options = EditorCore.relatedOptions(from: "o", outgoing: true, in: s)

        #expect(options.map(\.isBreak) == [true])
    }

    /// One real candidate beside the break is not a choice — the editor applies
    /// it without showing a list, which is what `soleCandidate` is for.
    @Test func oneRealCandidateIsNotAChoice() throws {
        let s = try conceptMap()
        let options = EditorCore.relatedOptions(from: "a", outgoing: true, in: s)

        if s.successorCandidates(from: "a").count == 1 {
            #expect(VCommandOption.soleCandidate(in: options)?.isBreak == false)
        }
    }

    /// Node types behind the break exclude the unknown ones — those are what a
    /// break *produces*, never what it offers.
    @Test func breakTypesExcludeUnknownTypes() throws {
        let s = try conceptMap()
        let options = EditorCore.breakTypeOptions(in: s)

        #expect(!options.isEmpty)
        #expect(!options.contains { $0.id.hasPrefix(NodeType.unknownPrefix) })
        #expect(!options.contains { $0.isBreak })
    }

    /// Predecessors are the same question the other way round.
    @Test func predecessorsUseTheIncomingCandidates() throws {
        let s = try conceptMap()
        let options = EditorCore.relatedOptions(from: "r", outgoing: false, in: s)

        #expect(options.count == s.predecessorCandidates(to: "r").count + 1)
    }
}

/// `split` asks a narrower question than `addSuccessor`: the break entry is
/// offered only when the user asks for it (phase 6f).
struct SplitOptionsTest {
    /// A GoalTree `n -> c` has exactly one insertion, so there is no question —
    /// the editor applies it without a list.
    @Test func oneInsertionIsNoQuestion() throws {
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
        let edgeId = s.origin.edges.first { $0.from.id == "n" && $0.to.id == "c" }!.id.id

        #expect(s.splitCandidates(for: edgeId).count == 1)
        #expect(EditorCore.splitOptions(for: edgeId, notationBreak: .forbidden, in: s).isEmpty)
    }

    /// ⌥ turns it into one: the same single insertion, now beside the break.
    @Test func permittingTheBreakMakesItAQuestion() throws {
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
        let edgeId = s.origin.edges.first { $0.from.id == "n" && $0.to.id == "c" }!.id.id

        let options = EditorCore.splitOptions(for: edgeId, notationBreak: .permitted, in: s)
        #expect(options.count == 2)
        #expect(options.last?.isBreak == true)
    }

    /// Unlike `relatedOptions`, the break is *not* offered by default. Splitting
    /// an edge the notation has no shape for is a request the user must make.
    @Test func theBreakIsNotOfferedUnlessAskedFor() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
        let edgeId = s.origin.edges.first!.id.id

        #expect(s.splitCandidates(for: edgeId).isEmpty)
        #expect(EditorCore.splitOptions(for: edgeId, notationBreak: .forbidden, in: s).isEmpty)
        #expect(
            EditorCore.splitOptions(for: edgeId, notationBreak: .permitted, in: s)
                .map(\.isBreak) == [true])
    }
}

/// `connect` is the only command whose elements come from a drag rather than a
/// click, and the only one where ⌥ replaces the question instead of widening it
/// (phase 6g).
struct ConnectOptionsTest {
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node r: Relation "leads to";
                }
                """)
    }

    /// One type joins Concept to Relation, so the drop needs no question.
    @Test func oneEdgeTypeIsNoQuestion() throws {
        let s = try conceptMap()
        #expect(s.connectCandidates(from: "a", to: "r").count == 1)
        #expect(
            EditorCore.connectOptions(from: "a", to: "r", notationBreak: .forbidden, in: s).isEmpty)
    }

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

    /// A pair the notation will not join asks nothing either — the drop is
    /// refused before it gets here, or ⌥ turns it into a break.
    @Test func aPairTheNotationRefusesAsksNothing() throws {
        let s = try conceptMap()
        #expect(s.connectCandidates(from: "a", to: "a").isEmpty)
        #expect(
            EditorCore.connectOptions(from: "a", to: "a", notationBreak: .forbidden, in: s).isEmpty)
    }

    /// The ⌥ drop joins a pair the notation will not, minting an unknown edge
    /// type — the break made visible in the diagram, per [[Notation break]].
    @Test func aPermittedBreakConnectsAnyway() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
        #expect(s.connectCandidates(from: "a", to: "b").isEmpty)

        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)

        #expect(try s.exportVGL().contains("edge a -> b"))
        #expect(s.canUndo == true)
    }

    /// Without ⌥ the same drop is refused rather than quietly inventing a type.
    @Test func aRefusedPairIsNotConnected() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
        let before = try s.exportVGL()

        #expect(throws: VError.self) { try s.connect("a", to: "b", using: nil) }

        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == false)
    }
}

/// `changeType` is the only command that still holds a conversation, and the
/// only one whose question count depends on an earlier answer (phase 6h).
struct ChangeTypeTest {
    private let conceptMap = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          node r: Relation "leads to";
          edge a -> r;
        }
        """

    private func pair() throws -> (typed: TestSession, generic: TestSession) {
        (try makeTestSession(vgl: conceptMap), try makeTestSession(vgl: conceptMap))
    }

    /// The common case: retyping decides every edge on its own, so there is
    /// nothing to ask and one call does it.
    @Test func usuallyNoEdgeIsLeftAmbiguous() throws {
        let s = try makeTestSession(vgl: conceptMap)
        guard let target = s.retypeCandidates(for: "a").first else { return }

        #expect(s.ambiguousEdges(ifRetyping: "a", to: target).isEmpty)
    }

    /// A type the notation does not offer goes through the break, which is two
    /// answers rather than one — the positioning the named method hides.
    @Test func aTypeTheNotationRefusesGoesThroughTheBreak() throws {
        let s = try makeTestSession(vgl: conceptMap)
        let offered = s.retypeCandidates(for: "a")
        guard
            let outside = s.nodeTypes().first(where: { type in
                !offered.contains { $0.id == type.id }
            })
        else { return }

        try s.changeType(of: "a", to: outside, edgeTypes: [], notationBreak: .permitted)

        #expect(try s.exportVGL().contains(outside.id))
    }

    /// Retyping to what it already is changes nothing — and since a no-op
    /// command cuts no undo step, it leaves no trace either.
    @Test func retypingToTheSameTypeLeavesNoTrace() throws {
        let s = try makeTestSession(vgl: conceptMap)
        let before = try s.exportVGL()
        try s.replaceDocument(vgl: before)

        guard let same = s.nodeTypes().first(where: { $0.id == "Concept" }) else { return }
        try s.changeType(of: "a", to: same, edgeTypes: [], notationBreak: .permitted)

        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == false)
    }

    /// `retypeOptions` follows the same rule as `splitOptions`: no question
    /// unless there is more than one candidate or the user asked for the break.
    @Test func retypeOptionsAskOnlyWhenThereIsAChoice() throws {
        let s = try makeTestSession(vgl: conceptMap)
        let candidates = s.retypeCandidates(for: "a")

        let forbidden = EditorCore.retypeOptions(for: "a", notationBreak: .forbidden, in: s)
        #expect(forbidden.isEmpty == (candidates.count <= 1))

        let permitted = EditorCore.retypeOptions(for: "a", notationBreak: .permitted, in: s)
        #expect(permitted.last?.isBreak == true)
    }
}

/// The drag's two questions, now asked by name rather than through the gesture
/// catalogue (phase 8a).
struct ConnectTargetsTest {
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                  node b: Concept "B";
                  node r: Relation "leads to";
                }
                """)
    }

    /// Every node may be grabbed, including one inside a group — refusing the
    /// grab would answer "where can this go?" before the user has asked
    /// (ADR-0012). Groups are not nodes and never appear.
    @Test func everyNodeMayStartADrag() throws {
        let s = try conceptMap()
        #expect(Set(s.connectSources()) == ["a", "b", "r"])
        #expect(!s.connectSources().contains("g1"))
    }

    /// Only what the notation joins — a Concept reaches a Relation, not another
    /// Concept.
    @Test func onlyWhatTheNotationJoinsMayReceive() throws {
        let s = try conceptMap()
        #expect(s.connectTargets(from: "a") == ["r"])
    }

    /// ⌥ opens every other node, which is the whole point of the break.
    @Test func permittingTheBreakOpensEverythingElse() throws {
        let s = try conceptMap()
        #expect(Set(s.connectTargets(from: "a", notationBreak: .permitted)) == ["b", "r"])
    }

    /// Never the node the drag started on: landing back where you began is a
    /// slip far more often than an intention.
    @Test func theGrabbedNodeIsNeverATarget() throws {
        let s = try conceptMap()
        #expect(!s.connectTargets(from: "a", notationBreak: .permitted).contains("a"))
    }

}
