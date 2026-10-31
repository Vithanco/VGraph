//
//  LoopMarkersCommandTest.swift
//  VGraph
//
//  Which loops a Causal Loop Diagram marks is the author's choice (ADR-0028), so
//  it is reachable from the canvas menu and not only by writing VGL.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct LoopMarkersCommandTest {

    private let cld = """
        vgraph cld: CLD "Demo" {
          group g "Market" {
            node price: Stock "Price";
          }
          node demand: Stock "Demand";
          edge price -> demand: opposite;
          edge demand -> price: same;
        }
        """

    private func titles(_ id: String, in session: TestSession) -> [String] {
        EditorCore.menu(for: id, in: session).map { $0.title }
    }

    @Test("A CLD's canvas menu offers the choice")
    func offeredOnTheCanvas() throws {
        let session = try makeTestSession(vgl: cld)
        #expect(titles(session.rootGroupId(), in: session).contains("Loop markers…"))
    }

    /// It is a setting of the whole diagram, and only a CLD draws loop markers.
    @Test("Neither a boundary nor another notation offers it")
    func offeredNowhereElse() throws {
        let session = try makeTestSession(vgl: cld)
        #expect(!titles("g", in: session).contains("Loop markers…"))

        let conceptMap = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        #expect(!titles(conceptMap.rootGroupId(), in: conceptMap).contains("Loop markers…"))
    }

    @Test("The question names all three choices and marks the current one")
    func asksWithTheCurrentMarked() throws {
        let session = try makeTestSession(vgl: cld)
        let (step, _) = EditorCore.begin(
            .loopMarkers, on: session.rootGroupId(), forcingChoice: false, in: session)

        guard case .ask(let prompt, let options) = step else {
            Issue.record("expected a question, got \(step)")
            return
        }
        #expect(prompt == "Loop markers")
        #expect(options.map { $0.id } == ["all", "independent", "none"])
        #expect(options.map { $0.title } == ["All loops ✓", "Independent loops", "No loop markers"])
    }

    @Test("The answer settles on setting it")
    func answerSetsIt() throws {
        let session = try makeTestSession(vgl: cld)
        let (_, conversation) = EditorCore.begin(
            .loopMarkers, on: session.rootGroupId(), forcingChoice: false, in: session)
        let (step, _) = EditorCore.next(
            after: VCommandOption(id: "independent", title: "Independent loops"), in: conversation,
            session: session)

        #expect(step == .perform(.setLoopMarkers(.independent)))
    }

    /// A document edit like any other: it is what the file says, and undo takes
    /// it back.
    @Test("Setting it changes the document, and one undo restores it")
    func setIsUndoable() throws {
        let session = try makeTestSession(vgl: cld)

        try session.setLoopMarkers(.none)
        #expect(session.loopMarkers() == LoopMarkers.none)
        #expect(try session.exportVGL().contains("loopmarkers: none"))

        _ = try session.undo()
        #expect(session.loopMarkers() == .all)
    }

    @Test("A notation that marks no loops has no setting to read")
    func noSettingOutsideCLD() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                }
                """)
        #expect(session.loopMarkers() == nil)
    }
}
