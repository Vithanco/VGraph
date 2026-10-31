//
//  Selection+Editor.swift
//  VGraphEditor
//
//  Gathering several elements in the diagram, and drawing what is gathered.
//  See ADR-0018.
//
//  The state lives here; the rules live in `EditorCore.Selection`, which a
//  Swift test can import. What is left in this file is the browser: hit tests,
//  client coordinates and class stamping.
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

// MARK: - State

/// What the user has gathered. Non-reactive: nothing in the ElementaryUI tree
/// reads it, because the highlight is painted onto the SVG — which ElementaryUI
/// does not own — and the toolbar reads the derived `editorModel.groupable`.
nonisolated(unsafe) var selection = Selection()

// MARK: - Changing what is selected

func selectionChanged() {
    paintSelection()
    editorModel.groupable =
        graphSession.map {
            $0.groupingTarget(for: selection.effective(in: $0)) != nil
        } ?? false
}

func clearSelection() {
    guard !selection.isEmpty else { return }
    selection = selection.cleared()
    selectionChanged()
}

/// Blank canvas and edges both count as a miss. The [[Root group]] is a menu
/// target, never something to select; an edge would enter the selection and
/// vanish from the [[Effective selection]] a moment later, which left a
/// right-click on one with no menu at all.
func clickSelect(_ id: String, extending: Bool) {
    if id.isEmpty || !isSelectable(id) {
        if !extending { clearSelection() }
        return
    }
    selection = extending ? selection.toggling(id) : selection.replacing(with: id)
    selectionChanged()
}

/// Nodes and groups — the two things a group can be made of. An edge's group is
/// derived from its endpoints (ADR-0017), leaving a set command nothing to do.
func isSelectable(_ id: String) -> Bool {
    guard let session = graphSession else { return false }
    return EditorCore.isSelectable(id, in: session)
}

// MARK: - The rubber band

/// An unfolded group is deliberately not a target: its rect encloses its whole
/// interior, so testing it would select the boundary the moment a drag began
/// inside one — which is where dragging is most needed. It arrives by promotion
/// instead (ADR-0018).
func bandCaught(_ band: VRect) -> [String] {
    guard let session = graphSession,
        let preview = element(DOMId.preview),
        let list = preview.querySelectorAll?(SVGElementId.contextMenuSelector).object,
        let count = list.length.number
    else { return [] }

    // Bounds as *drawn*, which is the contract `BandCandidate` states and the
    // reason this measuring is not the domain's to do.
    //
    // `catchable` is asked before measuring rather than left to `bandCatch`:
    // `getBoundingClientRect` forces layout, and a large diagram should not pay
    // for it on elements that could never be caught.
    var candidates: [BandCandidate] = []
    for index in 0..<Int(count) {
        guard let element = list[index].object,
            let domId = element.id.string,
            let id = SVGElementId.originId(fromDomId: domId),
            EditorCore.catchable(id, in: session),
            let rect = element.getBoundingClientRect?().object,
            let left = rect.left.number, let right = rect.right.number,
            let top = rect.top.number, let bottom = rect.bottom.number
        else { continue }
        candidates.append(
            BandCandidate(
                id: id,
                bounds: VRect(
                    origin: VPoint(x: left, y: top),
                    size: VSize(width: right - left, height: bottom - top))))
    }

    return EditorCore.bandCatch(band, over: candidates, in: session)
}

func groupFromToolbar() {
    guard editorModel.groupable else { return }
    dismissMenu()
    menuFromSelection = true
    performSelectionCommand(.addGroup)
}

// MARK: - Commands about the whole set

/// One [[Snapshot]] whatever the size of the set — the alternative, an adapter
/// looping over a single-element command, would leave the user pressing ⌘Z once
/// per node.
func performSelectionCommand(_ commandId: VCommandID) {
    guard let session = sessionSyncedToText() else { return }
    let members = selection.effective(in: session)

    if commandId == .delete {
        runNamed { s throws(VError) in try s.delete(all: members) }
        selection = selection.cleared()
        selectionChanged()
        return
    }

    // Which of the two grouping commands this is comes from the same query the
    // menu titled the row with, so the row and what runs cannot disagree.
    guard let target = session.groupingTarget(for: members) else {
        dismissMenu()
        return
    }
    var created: String? = nil
    runNamed { s throws(VError) in
        created =
            target.detached == 0
            ? try s.addGroup(containing: members)
            : try s.addGroup(moving: members)
    }
    guard let group = created else { return }

    // Create, select, name — `addNode`'s path unchanged (ADR-0016). The inline
    // edit opens *after* the render, which is ADR-0009's ordering rule.
    selection = Selection([group])
    selectionChanged()
    beginInlineEdit(elementId: group, kind: .group)
}

// MARK: - Drawing it

/// Inside the SVG, re-applied after every render. Not an exception to ADR-0009
/// but its narrower reading: that rule protects chrome holding *uncommitted
/// state*, and this holds none — the state is `selection`, and a render only
/// means deriving the class list again. An overlay outside would have to chase
/// scroll, resize and relayout, which is the stale-overlay bug class ADR-0009
/// eliminated.
func paintSelection() {
    guard let preview = element(DOMId.preview) else { return }

    if let stale = preview.querySelectorAll?(".vg-selected").object,
        let count = stale.length.number
    {
        for index in 0..<Int(count) {
            _ = stale[index].object?.classList.object?.remove?("vg-selected".jsValue)
        }
    }

    guard let session = graphSession, !selection.isEmpty else { return }
    var painted = selection.effective(in: session)
    // The renderer draws no element carrying the root's id (ADR-0016), so a
    // selection naming it would paint nothing at all. Unreachable by gesture,
    // since promotion stops below the root and a click on canvas clears.
    if painted.count == 1 && painted[0] == session.rootGroupId() {
        painted = selection.pruned(in: session).ids
    }

    for id in painted {
        _ = drawnElement(for: id)?.classList.object?.add?("vg-selected".jsValue)
    }
}
