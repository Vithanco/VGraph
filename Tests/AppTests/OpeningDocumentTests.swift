//
//  OpeningDocumentTests.swift
//  VGraph
//
//  What the editor opens with, when the URL, the last session and the built-in
//  demo all have a claim on it.
//
//  The rules are pure and the consequences are user-visible — a draft shown
//  where a link was followed is someone else's diagram in your editor — so they
//  live here rather than in the wasm target where no Swift test can reach them.
//

import EditorCore
import Testing

struct OpeningDocumentTests {
    let demo = "vgraph demo: ConceptMap \"Demo\" { }"
    let draft = "vgraph mine: ConceptMap \"Half-finished\" { }"

    /// A link must show the same diagram to everyone who follows it. Whatever
    /// this browser was last doing is beside the point.
    @Test("A document named in the URL beats a saved draft")
    func urlWins() {
        let opening = EditorCore.documentToOpen(
            urlDocument: "vgraph shared: ConceptMap \"Shared\" { }",
            urlAwaitsFetch: false, draft: draft, fallback: demo)

        #expect(opening.vgl.contains("Shared"))
        #expect(opening.restoredDraft == false)
    }

    /// `?src=` is fetched by the host *after* mount, so at this point the
    /// document is not in hand — but restoring a draft meanwhile would show the
    /// wrong diagram and then yank it away.
    @Test("A URL that is still fetching its document also beats a draft")
    func pendingFetchWins() {
        let opening = EditorCore.documentToOpen(
            urlDocument: nil, urlAwaitsFetch: true, draft: draft, fallback: demo)

        #expect(opening.vgl == demo)
        #expect(opening.restoredDraft == false)
    }

    @Test("With nothing in the URL, the draft comes back")
    func draftIsRestored() {
        let opening = EditorCore.documentToOpen(
            urlDocument: nil, urlAwaitsFetch: false, draft: draft, fallback: demo)

        #expect(opening.vgl == draft)
        #expect(opening.restoredDraft == true)
    }

    /// Announcing a restore that changes nothing on screen reads as a fault:
    /// the reader hunts for what came back and finds the same demo.
    @Test("A draft identical to what would open anyway is not announced")
    func anIdenticalDraftIsNotARestore() {
        let opening = EditorCore.documentToOpen(
            urlDocument: nil, urlAwaitsFetch: false, draft: demo, fallback: demo)

        #expect(opening.vgl == demo)
        #expect(opening.restoredDraft == false)
    }

    /// Emptying the textarea is how someone starts over; it must not be read as
    /// "nothing was saved, so bring back the demo I just cleared".
    @Test("An empty or blank draft is nothing to restore")
    func blankDraftsAreIgnored() {
        for blank in ["", "   \n  "] {
            let opening = EditorCore.documentToOpen(
                urlDocument: nil, urlAwaitsFetch: false, draft: blank, fallback: demo)

            #expect(opening.vgl == demo)
            #expect(opening.restoredDraft == false)
        }
    }

    /// The URL parameter can be present and empty — `?vgl=` with nothing after
    /// it — which asks for nothing, not for an empty document.
    @Test("An empty URL document is not a document")
    func emptyURLDocumentIsIgnored() {
        let opening = EditorCore.documentToOpen(
            urlDocument: "", urlAwaitsFetch: false, draft: draft, fallback: demo)

        #expect(opening.vgl == draft)
        #expect(opening.restoredDraft == true)
    }
}
