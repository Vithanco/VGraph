//
//  ReparseIdentityTest.swift
//  VGraph
//
//  An adapter holds element ids. A reparse mints new ones. The rule that keeps
//  those two facts from colliding.
//
//  Found by the browser suite, not this one: opening an inline editor re-seeded
//  the textarea from a canonical export without the session recording that text,
//  so the *next* sync reparsed — renumbering the edge and stranding the id the
//  editor had captured on double-click. `setLabel` then refused an id that no
//  longer existed, and the label silently never landed.
//

import Testing
import VGLanguage
import VGraph

@testable import App

struct ReparseIdentityTest {
    /// Deliberately not canonical: spaces, semicolons, no trailing newline. What
    /// a `?vgl=` URL or a typing user actually supplies.
    private let handWritten = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "My Group" {
            node idea: Concept "Idea";
          };
          node detail: Concept "Detail";
          edge idea -> detail;
        }
        """

    /// The hazard itself, stated so it is not rediscovered the hard way: an edge
    /// has no id in the text, so parsing generates one — and a *second* parse of
    /// semantically identical text generates a different one.
    @Test func reparsingEquivalentTextRenumbersGeneratedIds() throws {
        let session = try makeTestSession(vgl: handWritten)
        let before = session.origin.edges.first!.id.id

        // Same graph, different formatting — which is exactly what the editor
        // writes back after any command.
        try session.textEdited(vgl: try session.exportVGL())

        #expect(
            session.origin.edges.first!.id.id != before,
            "ids are stable across a reparse now — delete this test and the rule it guards")
    }

    /// The rule. After a command applies, the text the adapter puts on screen is
    /// already the document, so feeding it back changes nothing — and every id
    /// the adapter is holding stays valid.
    @Test func afterACommandTheExportedTextIsAlreadyTheDocument() throws {
        let session = try makeTestSession(vgl: handWritten)
        try session.setLabel(of: "idea", to: "Renamed")

        let edgeId = session.origin.edges.first!.id.id
        let steps = session.canUndo

        // What the editor writes into the textarea, handed straight back.
        try session.textEdited(vgl: try session.exportVGL())

        #expect(
            session.origin.edges.first!.id.id == edgeId,
            "syncing a command's own export renumbered ids; held ids are now stale")
        #expect(session.canUndo == steps, "the round trip cut an extra undo step")
    }

    /// The same rule where it actually broke: nothing was applied. Opening an
    /// editor must leave the document alone *including* its formatting, because
    /// an adapter that re-seeds its text surface from an export it never told
    /// the session about has quietly desynchronised the two.
    @Test func lookingAtALabelChangesNothing() throws {
        let session = try makeTestSession(vgl: handWritten)
        let edgeId = session.origin.edges.first!.id.id

        // Everything the editor does to open an inline edit: sync, ask what to
        // put in the field. No command runs.
        try session.textEdited(vgl: handWritten)
        _ = session.label(of: edgeId)
        _ = session.kind(of: edgeId)

        #expect(session.canUndo == false, "opening an editor left an undo step")
        #expect(session.origin.edges.first!.id.id == edgeId)

        // And the id is still good for the commit that follows.
        #expect(throws: Never.self) { try session.setLabel(of: edgeId, to: "leads to") }
        #expect(try session.exportVGL().contains("leads to"))
    }

    /// The rule applied to a node that did not exist a moment ago. `addNode` hands
    /// back an id the editor immediately opens an [[Inline edit]] on — and it
    /// re-seeds the textarea in between. A round trip that renumbered anything
    /// would leave the editor typing into a node that no longer exists (ADR-0016).
    @Test func aCreatedNodeSurvivesTheEditorsOwnRoundTrip() throws {
        let session = try makeTestSession(vgl: handWritten)

        // `idea` and `detail` are both Concepts, so the new one is the third.
        let created = try session.addNode(in: nil, ofType: NodeType(string: "Concept"))
        #expect(created == "concept_3")

        let edgeId = session.origin.edges.first!.id.id
        let steps = session.canUndo

        try session.textEdited(vgl: try session.exportVGL())

        #expect(
            session.origin.edges.first!.id.id == edgeId,
            "syncing the add's own export renumbered ids; the new node's id is now stale")
        #expect(session.canUndo == steps, "the round trip cut an extra undo step")

        // What `beginInlineEdit` asks for, on the id it was handed.
        #expect(session.kind(of: created!) == .node)
        #expect(session.label(of: created!) == "Change Me")
    }
}
