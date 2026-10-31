//
//  ChangeEdgeTypeTest.swift
//  VGraph
//
//  ChangeType on an *edge*: say what the relationship is without deleting it and
//  drawing it again. See ADR-0023.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct ChangeEdgeTypeTest {
    /// Two edge types join the one node type, so an edge between two Stocks can
    /// become the other without either end moving.
    private func cld() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  edge s1 -> s2: same;
                }
                """)
    }

    /// Concept → Relation is the only type the notation declares for that pair,
    /// so there is nothing for the edge to become.
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node idea: Concept "Idea";
                  node link: Relation "leads to";
                  edge idea -> link;
                }
                """)
    }

    private func onlyEdge(_ s: TestSession) -> String { s.origin.edges.first!.id.id }

    // MARK: - Candidates

    @Test func offersEveryTypeButTheEdgesOwn() throws {
        let s = try cld()

        let candidates = s.retypeCandidates(edge: onlyEdge(s))

        #expect(candidates.map { $0.id.id } == ["opposite"])
    }

    @Test func offersNothingWhereTheNotationDeclaresOneType() throws {
        let s = try conceptMap()

        #expect(s.retypeCandidates(edge: onlyEdge(s)).isEmpty)
    }

    @Test func offersNothingForANode() throws {
        #expect(try cld().retypeCandidates(edge: "s1").isEmpty)
    }

    /// The whole reason this is not `connectCandidates` with the edge's own
    /// endpoints: the edge about to be replaced must not count against the bound
    /// it is about to vacate. `totalOutDegreeMax` closes the source outright, so the
    /// naive query answers *nothing at all* for the pair being retyped — and the
    /// edges most worth retyping are the ones that spend a budget.
    @Test("The bounds are counted against the graph minus the edge being retyped")
    func boundsExcludeTheEdgeBeingRetyped() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc", totalOutDegreeMax: 1]
                  edge type: next from: Step to: Step
                  edge type: blocks from: Step to: Step
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node s2: Step "Two";
                  edge s1 -> s2: next;
                }
                """)
        let edge = onlyEdge(s)

        // The naive query: s1's one outgoing edge is the one in hand, so the
        // source reads as closed and nothing comes back.
        #expect(s.connectCandidates(from: "s1", to: "s2").isEmpty)

        #expect(s.retypeCandidates(edge: edge).map { $0.id.id } == ["blocks"])
    }

    // MARK: - The command

    @Test func retypesTheEdgeAndWritesItToTheDocument() throws {
        let s = try cld()

        try s.changeType(of: onlyEdge(s), using: EdgeType.Id(string: "opposite"))

        let exported = try s.exportVGL()
        #expect(exported.contains("edge s1 -> s2: opposite"))
        try s.replaceDocument(vgl: exported)
    }

    /// Both ends stay put, so the arrow runs the way it did. Reorienting is
    /// `changeDirection`'s job (ADR-0021).
    @Test func neverFlipsTheEdge() throws {
        let s = try cld()

        try s.changeType(of: onlyEdge(s), using: EdgeType.Id(string: "opposite"))

        let exported = try s.exportVGL()
        #expect(!exported.contains("edge s2 -> s1"))
    }

    /// `reattach` carries the attributes across, which is the whole reason the
    /// command is not delete-then-connect.
    @Test func keepsTheLabelAndTheComments() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph cld: CLD "Demo" {
                  node s1: Stock "Price";
                  node s2: Stock "Demand";
                  // why this link matters
                  edge s1 -> s2: same "drives";
                }
                """)

        try s.changeType(of: onlyEdge(s), using: EdgeType.Id(string: "opposite"))

        let exported = try s.exportVGL()
        #expect(exported.contains("\"drives\""))
        #expect(exported.contains("// why this link matters"))
    }

    /// One alternative is not a choice, so the command picks it.
    @Test func picksTheOnlyAlternativeItself() throws {
        let s = try cld()

        try s.changeType(of: onlyEdge(s))

        #expect(try s.exportVGL().contains("edge s1 -> s2: opposite"))
    }

    @Test func refusesWhereThereIsNothingToBecome() throws {
        let s = try conceptMap()

        #expect(throws: VError.self) { try s.changeType(of: onlyEdge(s), using: nil) }
    }

    @Test func refusesATypeTheNotationNeverOffered() throws {
        let s = try cld()

        #expect(throws: VError.self) {
            try s.changeType(of: onlyEdge(s), using: EdgeType.Id(string: "sideways"))
        }
    }

    @Test func refusesToRetypeANode() throws {
        let s = try cld()

        #expect(throws: VError.self) {
            try s.changeType(of: "s1", using: EdgeType.Id(string: "opposite"))
        }
    }

    // MARK: - The menu

    /// It sits after `changeDirection`, so no existing entry moved.
    @Test func showsUpOnTheEdgeMenuNextToChangeDirection() throws {
        let commands = EditorCore.commands(on: .edge).map { $0.raw }

        #expect(commands.prefix(3).map { $0 } == ["changeDirection", "changeType", "split"])
    }

    /// Not `.forbiddenByNotation`: there is no break here, so ⌥ must not enable
    /// an item whose conversation would have nothing to offer.
    @Test func greyedRatherThanBreakableWhereThereIsNothingToBecome() throws {
        let s = try conceptMap()
        let edge = onlyEdge(s)

        #expect(EditorCore.availability(of: .changeType, on: edge, in: s) == .notApplicable)
        #expect(
            EditorCore.availability(of: .changeType, on: edge, in: s)
                .isEnabled(under: .permitted) == false)
    }

    @Test func availableWhereTheNotationOffersAnother() throws {
        let s = try cld()

        #expect(EditorCore.availability(of: .changeType, on: onlyEdge(s), in: s) == .available)
    }

    /// One candidate is not a question, as `retypeOptions` and `splitOptions`
    /// both rule. And no escape hatch, unlike a node's list.
    @Test func asksOnlyWhereThereIsAChoice() throws {
        let s = try cld()

        #expect(EditorCore.edgeRetypeOptions(for: onlyEdge(s), in: s).isEmpty)
    }

    @Test func offersEveryAlternativeWhereThereAreSeveral() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  edge type: next from: Step to: Step
                  edge type: blocks from: Step to: Step
                  edge type: informs from: Step to: Step
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node s2: Step "Two";
                  edge s1 -> s2: next;
                }
                """)

        let options = EditorCore.edgeRetypeOptions(for: onlyEdge(s), in: s)

        #expect(options.map { $0.id } == ["blocks", "informs"])
        #expect(!options.contains { $0.isBreak })
    }

    // MARK: - Declaring a way out of a break

    /// A ⌥-drag leaves a minted type. Promotion gives that same edge a real one
    /// — same edge, so the label and the comments survive (ADR-0024).
    private func broken() throws -> TestSession {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)
        return s
    }

    @Test func changeTypeIsReachableOnAnEdgeWearingAMintedType() throws {
        let s = try broken()
        let edge = onlyEdge(s)

        // The notation names nothing for Concept → Concept …
        #expect(s.retypeCandidates(edge: edge).isEmpty)
        // … and the command is still available, because declaring is the way out.
        #expect(s.hasUnknownType(edge: edge))
        #expect(EditorCore.availability(of: .changeType, on: edge, in: s) == .available)
        #expect(EditorCore.edgeRetypeOptions(for: edge, in: s).map { $0.id } == ["__declare__"])
    }

    @Test func declaringGivesTheEdgeARealTypeAndWritesTheNotation() throws {
        let s = try broken()

        try s.declareEdgeType(for: onlyEdge(s), named: "concept_to_concept")

        #expect(GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty)
        let exported = try s.exportVGL()
        #expect(exported.contains("vnotation ConceptMapExtended extends ConceptMap"))
        #expect(exported.contains("edge type: concept_to_concept"))
        #expect(exported.contains("vgraph demo: ConceptMapExtended"))
        try s.replaceDocument(vgl: exported)
        #expect(try s.origin.edgeType(for: s.origin.edges.first!.id).id.id == "concept_to_concept")
    }

    /// The minted type goes with the last edge wearing it. Promotion makes the
    /// document a `vnotation`, and the exporter writes *every* declaration — so
    /// an orphan would be emitted as a dead `edge type:` line on every export.
    @Test func thePromotedEdgeLeavesNoOrphanedMintedType() throws {
        let s = try broken()

        try s.declareEdgeType(for: onlyEdge(s), named: "concept_to_concept")

        #expect(!s.origin.edgeTypes.contains { $0.id.id.hasPrefix(EdgeType.unknownPrefix) })
        #expect(!(try s.exportVGL().contains(EdgeType.unknownPrefix)))
    }

    /// Two broken edges over one pair share a single minted type, so promoting
    /// one must not take the other's type away.
    @Test func theMintedTypeSurvivesWhileAnotherEdgeWearsIt() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  node c: Concept "C";
                }
                """)
        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)
        try s.connect("a", to: "c", using: nil, notationBreak: .permitted)
        let first = s.origin.edges.first!.id.id

        try s.declareEdgeType(for: first, named: "concept_to_concept")

        #expect(s.origin.edgeTypes.contains { $0.id.id.hasPrefix(EdgeType.unknownPrefix) })
        #expect(GenericQualityChecks.unknownEdgeTypes(graph: s.origin).count == 1)
        try s.replaceDocument(vgl: try s.exportVGL())
    }

    /// It keeps the edge, not just the shape — `reattach` with both ends unmoved.
    @Test func declaringKeepsTheLabelAndTheComments() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                }
                """)
        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)
        let edge = onlyEdge(s)
        try s.setLabel(of: edge, to: "drives")

        try s.declareEdgeType(for: edge, named: "concept_to_concept")

        #expect(try s.exportVGL().contains("\"drives\""))
    }

    @Test func aNameTheGraphCannotTakeIsRefused() throws {
        let s = try broken()
        let edge = onlyEdge(s)

        #expect(throws: VError.self) { try s.declareEdgeType(for: edge, named: "") }
        #expect(throws: VError.self) { try s.declareEdgeType(for: edge, named: "2fast") }
        #expect(throws: VError.self) { try s.declareEdgeType(for: edge, named: "has space") }
        #expect(throws: VError.self) { try s.declareEdgeType(for: edge, named: "edge") }
        // Already this notation's own — declaring it again would shadow it.
        #expect(throws: VError.self) {
            try s.declareEdgeType(for: edge, named: "concept_to_relation")
        }
        #expect(s.hasUnknownType(edge: edge))
    }

    /// The promotion happens once: a second declaration extends the block the
    /// first made, and the notation keeps its name.
    @Test func aSecondDeclarationExtendsTheSameNotation() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Concept "B";
                  node c: Concept "C";
                }
                """)
        try s.connect("a", to: "b", using: nil, notationBreak: .permitted)
        try s.declareEdgeType(for: s.origin.edges.first!.id.id, named: "concept_to_concept")
        try s.connect("b", to: "c", using: nil, notationBreak: .permitted)
        let second = s.origin.edges.first { $0.from.id == "b" && $0.to.id == "c" }!.id.id

        try s.declareEdgeType(for: second, named: "concept_beside_concept")

        let exported = try s.exportVGL()
        #expect(exported.contains("vnotation ConceptMapExtended extends ConceptMap"))
        #expect(!exported.contains("ConceptMapExtendedExtended"))
        #expect(exported.contains("edge type: concept_to_concept"))
        #expect(exported.contains("edge type: concept_beside_concept"))
        try s.replaceDocument(vgl: exported)
    }

    // MARK: - The conversation

    @Test func oneAlternativeSkipsTheMenuAndRetypesDirectly() throws {
        let s = try cld()
        let edge = onlyEdge(s)

        let (step, _) = EditorCore.begin(.changeType, on: edge, forcingChoice: false, in: s)

        #expect(step == .perform(.changeEdgeType(edge: edge, using: nil)))
    }

    @Test func theTypePickedRetypesTheEdge() throws {
        let s = try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  edge type: next from: Step to: Step
                  edge type: blocks from: Step to: Step
                  edge type: informs from: Step to: Step
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node s2: Step "Two";
                  edge s1 -> s2: next;
                }
                """)
        let edge = onlyEdge(s)
        let (_, opened) = EditorCore.begin(.changeType, on: edge, forcingChoice: false, in: s)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "blocks", title: "blocks"), in: opened, session: s)

        #expect(
            step
                == .perform(.changeEdgeType(edge: edge, using: EdgeType.Id(string: "blocks"))))
    }

    @Test func dismissesWhereThereIsNothingToBecome() throws {
        let s = try conceptMap()

        let (step, _) = EditorCore.begin(
            .changeType, on: onlyEdge(s), forcingChoice: false, in: s)

        #expect(step == .dismiss)
    }

    /// ⌥ has nothing to reach on an edge, so it must not open the node-type
    /// list the way it does for a node retype.
    @Test func theEscapeHatchIsNotAnAnswerHere() throws {
        let s = try cld()
        let (_, opened) = EditorCore.begin(
            .changeType, on: onlyEdge(s), forcingChoice: true, in: s)

        let (step, _) = EditorCore.next(after: EditorCore.breakOption, in: opened, session: s)

        #expect(step == .dismiss)
    }
}
