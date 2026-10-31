//
//  Views+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

// MARK: - Views

extension ViewOption {
    /// Stable across a relabel of another view, so only the changed row rebuilds.
    var key: String { (name ?? "") + "|" + title }
}

/// What the picker offers, mirrored from the session by `refreshViews`.
nonisolated(unsafe) var viewPickerOptions: [ViewOption] = []

/// The view a restored draft was showing, applied once the document is in.
nonisolated(unsafe) var pendingDraftView = ""

/// Mirror the session's views into the model, so the view button and the status
/// line follow it. Called by every render, which is every way the views can change.
func refreshViews() {
    guard let session = graphSession else { return }
    viewPickerOptions = EditorCore.viewOptions(in: session)
    let shown = EditorCore.shownView(in: viewPickerOptions)
    editorModel.shownView = shown.name
    editorModel.shownViewTitle = shown.title
}

/// Switching is navigation: the text is folded in first, as every command that
/// reads the graph does, and nothing is written to the document.
func viewPicked(_ name: String) {
    guard let session = sessionSyncedToText() else { return }
    try? session.selectView(name.isEmpty ? nil : name)
    performRender()
}

/// The View menu's rows, read when the menu is drawn.
func viewMenuRows() -> [MenuItem] {
    guard let session = graphSession else { return [] }
    return EditorCore.viewMenu(in: session)
}

/// Applied after the first load of a restored draft; a view the document no
/// longer has is dropped without a word.
func restoreDraftView() {
    guard !pendingDraftView.isEmpty else { return }
    let name = pendingDraftView
    pendingDraftView = ""
    guard let session = graphSession, (try? session.selectView(name)) != nil else { return }
    performRender()
}

func toggleViewMenu() {
    editorModel.viewMenuAt = toggledMenu(editorModel.viewMenuAt, under: DOMId.viewMenuButton)
}

/// A View menu row opens its question where the menu was. The target is the
/// view the row is about; "New view" and "Duplicate view" have none of their
/// own to name.
func performViewCommand(_ command: VCommandID) {
    editorModel.menuAt = editorModel.viewMenuAt ?? .zero
    editorModel.viewMenuAt = nil
    let target = editorModel.shownView.isEmpty ? "view" : editorModel.shownView
    openConversation(command, on: target, forcingChoice: false)
}
