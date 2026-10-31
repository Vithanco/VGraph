//
//  ChangeGroupTypeTest.swift
//  VGraph
//
//  ChangeType on a *group*: give a boundary its kind without writing VGL, and
//  take it away again.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct ChangeGroupTypeTest {
    private let team = GroupType(string: "Team")

    private func teams() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Teams {
                  node type: Member [nodeStyle: roundedBox]
                  edge type: helps from: Member to: Member
                  group type: Team
                  group type: Guild
                  group type: Chapter
                }

                vgraph org: Teams "Org" {
                  node lead: Member "Lead";
                  group core "Core" {
                    node ann: Member "Ann";
                  }
                  edge lead -> ann;
                }
                """)
    }

    /// ConceptMap registers no group types at all — the fixture for "there is no
    /// question to ask".
    private func conceptMap() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                }
                """)
    }

    // MARK: - Enumeration

    @Test func listsTheNotationsGroupTypes() throws {
        let types = try teams().groupTypes().map { $0.id }
        #expect(types == ["Team", "Guild", "Chapter"])
    }

    @Test func listsNothingForANotationWithoutBoundaries() throws {
        #expect(try conceptMap().groupTypes().isEmpty)
    }

    // MARK: - The command

    @Test func typesAPlainGroupAndWritesItToTheDocument() throws {
        let s = try teams()

        try s.changeType(of: "core", to: team)

        let exported = try s.exportVGL()
        #expect(exported.contains("group core: Team \"Core\""))
        try s.replaceDocument(vgl: exported)
    }

    @Test func typedGroupBecomesPlainAgain() throws {
        let s = try teams()
        try s.changeType(of: "core", to: team)

        try s.changeType(of: "core", to: nil)

        let exported = try s.exportVGL()
        #expect(exported.contains("group core \"Core\""))
        #expect(!exported.contains("group core: Team"))
    }

    @Test func refusesATypeTheNotationNeverRegistered() throws {
        let s = try teams()

        #expect(throws: VError.self) {
            try s.changeType(of: "core", to: GroupType(string: "TrustBoundary"))
        }
    }

    /// The canvas is a group (ADR-0016) but not a boundary — it has no outside to
    /// draw one around.
    @Test func refusesTheRootGroup() throws {
        let s = try teams()

        #expect(throws: VError.self) {
            try s.changeType(of: s.rootGroupId(), to: team)
        }
    }

    @Test func refusesToTypeANode() throws {
        let s = try teams()

        #expect(throws: VError.self) {
            try s.changeType(of: "ann", to: team)
        }
    }

    // MARK: - The menu

    @Test func offersEveryTypeButTheGroupsOwn() throws {
        let s = try teams()
        try s.changeType(of: "core", to: team)

        let options = EditorCore.groupRetypeOptions(for: "core", in: s)

        #expect(options.map { $0.id } == ["Guild", "Chapter", "__plain__"])
        #expect(options.last?.title == "Plain group")
    }

    /// A plain group is already plain, so clearing is not on offer.
    @Test func offersNoPlainEntryForAnUntypedGroup() throws {
        let options = EditorCore.groupRetypeOptions(for: "core", in: try teams())

        #expect(options.map { $0.id } == ["Team", "Guild", "Chapter"])
    }

    @Test func offersNothingWhereTheNotationHasNoBoundaries() throws {
        #expect(EditorCore.groupRetypeOptions(for: "g1", in: try conceptMap()).isEmpty)
    }

    /// Not `.forbiddenByNotation`: ⌥ must not mint a boundary kind, since the
    /// unknown group type exists only as the result of a bad document.
    @Test func greyedRatherThanBreakableWhereThereAreNoBoundaries() throws {
        let s = try conceptMap()

        #expect(EditorCore.availability(of: .changeType, on: "g1", in: s) == .notApplicable)
        #expect(EditorCore.availability(of: .changeType, on: "g1", in: s).isEnabled(under: .permitted) == false)
    }

    @Test func availableWhereTheNotationHasGroupTypes() throws {
        #expect(EditorCore.availability(of: .changeType, on: "core", in: try teams()) == .available)
    }

    // MARK: - The conversation

    /// The menu offers it, so clicking it must ask something. `retypeOptions`
    /// answers from the *node* list and a group is not in it.
    @Test func clickingItOnAGroupAsksForABoundaryKind() throws {
        let s = try teams()

        let (step, _) = EditorCore.begin(.changeType, on: "core", forcingChoice: false, in: s)

        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.map { $0.id } == ["Team", "Guild", "Chapter"])
    }

    @Test func theKindPickedTypesTheBoundary() throws {
        let s = try teams()
        let (_, opened) = EditorCore.begin(.changeType, on: "core", forcingChoice: false, in: s)

        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "Team", title: "Team"),
            in: opened, session: s)

        #expect(
            step == .perform(.changeGroupType(group: "core", to: team)))
    }

    /// "Plain group" is an answer, not a cancel: it settles the same command
    /// with `nil`, which deletes the attribute.
    @Test func thePlainEntryClearsTheBoundary() throws {
        let s = try teams()
        try s.changeType(of: "core", to: team)
        let (_, opened) = EditorCore.begin(.changeType, on: "core", forcingChoice: false, in: s)

        let (step, _) = EditorCore.next(
            after: EditorCore.plainGroupOption, in: opened, session: s)

        #expect(step == .perform(.changeGroupType(group: "core", to: nil)))
    }

    /// The item is greyed there, so the conversation is unreachable from the
    /// menu — but opening it anyway must dismiss rather than ask an empty list.
    @Test func dismissesWhereTheNotationHasNoBoundaries() throws {
        let s = try conceptMap()

        let (step, _) = EditorCore.begin(.changeType, on: "g1", forcingChoice: false, in: s)

        #expect(step == .dismiss)
    }

    /// ⌥ must not turn this into a node retype: the target is still a group, so
    /// the boundary list is what comes back.
    @Test func forcingTheChoiceStillAsksForABoundaryKind() throws {
        let s = try teams()

        let (step, _) = EditorCore.begin(.changeType, on: "core", forcingChoice: true, in: s)

        guard case .ask(_, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(options.map { $0.id } == ["Team", "Guild", "Chapter"])
    }
}
