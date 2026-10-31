//
//  DrivingPortsTest.swift
//  VGraph
//
//  The three driving ports and the announcement that pairs with them.
//  See docs/adr/0013-driving-ports-and-named-commands.md.
//
//  Half of this file is a *compile* test: the pane types below name a port and
//  never `AppPorts`, `ForStoreDocumentVersions` or `GraphSession`, which is the
//  whole claim of the ADR. If they still build, the claim holds.
//

import Testing
import VGLanguage
import VGraph

@testable import App

// MARK: - Components written against one port each

/// A text pane. Can put VGL in and colour it; cannot render, command or undo,
/// because nothing on its port offers to.
private struct TextPane<Session: ForEditVGL> {
    let session: Session

    func type(_ vgl: String) throws { try session.textEdited(vgl: vgl) }
    func blur() { session.textEditingEnded() }
    func overlay(for source: String) -> String {
        session.highlightHTML(source, semantic: false, diagnostics: nil)
    }
}

/// A diagram pane. Changes the graph by command or gesture; has no way to touch
/// the text, and no way to read the graph beyond one element's label.
private struct DiagramPane<Session: ForEditAGraphVisually> {
    let session: Session

    func label(of id: String) -> String? { session.label(of: id) }
    func fold(_ groupId: String) throws { try session.toggleFolding(of: groupId) }
    func isFolded(_ groupId: String) -> Bool { session.isFolded(groupId) }
    func dropTargets(dragging id: String) -> [String] {
        session.connectTargets(from: id, notationBreak: .forbidden)
    }
}

/// The toolbar: the document as a whole, neither pane.
private struct Toolbar<Session: ForManageADocument> {
    let session: Session

    var undoEnabled: Bool { session.canUndo }
    var redoEnabled: Bool { session.canRedo }
    func saveVGL() throws -> String { try session.exportVGL() }
    func open(_ vgl: String) throws { try session.replaceDocument(vgl: vgl) }
}

/// A diagram pane that also wants ⌘Z, so it holds the document's port too — the
/// composition constraint the ADR flagged as unproven in Embedded Swift. Still
/// static dispatch; nothing here is an existential.
private struct DiagramPaneWithUndo<Session: ForEditAGraphVisually & ForManageADocument> {
    let session: Session

    func undoFromTheDiagram() throws -> String? { try session.undo() }
    func labelAfterUndo(of id: String) throws -> String? {
        _ = try session.undo()
        return session.label(of: id)
    }
}

// MARK: - The observer

/// Counts announcements. A class because the session holds it by value and the
/// test has to see what the session's copy was told.
private final class CountingObserver: ForObserveDocumentChanges {
    private final class Box { var count = 0 }
    private let box = Box()

    var count: Int { box.count }
    func documentChanged() { box.count += 1 }
}

private typealias WatchedSession = GraphSession<
    ParseOnlyPorts<NoOpLogger>, InMemoryVersionStore, CountingObserver
>

struct DrivingPortsTest {
    /// A ConceptMap, so `connect` has somewhere legal to land: the notation
    /// joins a Concept to a Relation and not to another Concept.
    let base = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
          }
          node r: Relation "leads to";
        }
        """
    let edited = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
            node b: Concept "B";
          }
          node r: Relation "leads to";
          node d: Concept "D";
        }
        """

    private func watched() throws -> (WatchedSession, CountingObserver) {
        let observer = CountingObserver()
        let session = try makeTestApp().makeSession(
            vgl: base, versionStore: InMemoryVersionStore(), observer: observer)
        return (session, observer)
    }

    // MARK: Conformance

    @Test func aTextPaneDrivesTheSessionThroughItsPortAlone() throws {
        let pane = TextPane(session: try makeTestSession(vgl: base))
        try pane.type(edited)
        pane.blur()
        // The pane never names `VGraphApplication`, yet still reaches the
        // highlighter behind it — the reason `highlightHTML` is on this port.
        #expect(pane.overlay(for: base).contains("<span class=\"vg-kw\">vgraph</span>"))
    }

    @Test func aDiagramPaneReadsAndChangesThroughItsPortAlone() throws {
        let pane = DiagramPane(session: try makeTestSession(vgl: base))
        #expect(pane.label(of: "a") == "A")
        #expect(pane.label(of: "ghost") == nil)
        #expect(pane.isFolded("g1") == false)
        try pane.fold("g1")
        #expect(pane.isFolded("g1") == true)

        #expect(pane.dropTargets(dragging: "a") == ["r"])
    }

    @Test func aToolbarManagesTheDocumentThroughItsPortAlone() throws {
        let toolbar = Toolbar(session: try makeTestSession(vgl: base))
        #expect(toolbar.undoEnabled == false)
        #expect(try toolbar.saveVGL().contains("node a"))

        try toolbar.open(edited)
        // A load resets history rather than adding to it.
        #expect(toolbar.undoEnabled == false)
        #expect(toolbar.redoEnabled == false)
    }

    /// The `A & B` composition the ADR asked to see compile before relying on it.
    @Test func aPaneMayHoldTwoPortsAtOnce() throws {
        let session = try makeTestSession(vgl: base)
        let pane = DiagramPaneWithUndo(session: session)

        try session.textEdited(vgl: edited)  // adds node d
        #expect(session.label(of: "d") == "D")
        #expect(try pane.labelAfterUndo(of: "d") == nil)  // back to `base`, d gone
        #expect(try pane.undoFromTheDiagram() == nil)  // already at the oldest
    }

    // MARK: Announcement

    @Test func constructingASessionAnnouncesNothing() throws {
        let (_, observer) = try watched()
        #expect(observer.count == 0)
    }

    @Test func everyPathThatMovesTheDocumentAnnouncesOnce() throws {
        let (session, observer) = try watched()

        try session.textEdited(vgl: edited)
        #expect(observer.count == 1)

        try session.toggleFolding(of: "g1")
        #expect(observer.count == 2)

        _ = try session.undo()
        #expect(observer.count == 3)

        _ = try session.redo()
        #expect(observer.count == 4)

        try session.replaceDocument(vgl: base)
        #expect(observer.count == 5)
    }

    /// Nothing moved, so nothing is announced — a pane that re-rendered here
    /// would be relaying out Graphviz for an identical graph.
    @Test func anEditToIdenticalTextAnnouncesNothing() throws {
        let (session, observer) = try watched()
        try session.textEdited(vgl: base)
        #expect(observer.count == 0)
    }

    /// Sealing a typing burst changes the *next* undo step, not the document.
    @Test func endingTextEditingAnnouncesNothing() throws {
        let (session, observer) = try watched()
        session.textEditingEnded()
        #expect(observer.count == 0)
    }

    /// A failed parse leaves the document where it was, so there is nothing to
    /// tell — the panes keep showing what they already show.
    @Test func aRejectedEditAnnouncesNothing() throws {
        let (session, observer) = try watched()
        #expect(throws: VError.self) { try session.textEdited(vgl: "this is not VGL") }
        #expect(observer.count == 0)
    }

    /// An undo at the oldest state moves the cursor nowhere.
    @Test func anUndoWithNowhereToGoAnnouncesNothing() throws {
        let (session, observer) = try watched()
        #expect(try session.undo() == nil)
        #expect(observer.count == 0)
    }
}
