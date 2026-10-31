//
//  Move+Editor.swift
//  VGraphEditor
//
//  Dragging elements from one group into another. See ADR-0019.
//
//  There was no pointer gesture left to spend, so this one shares `connect`'s:
//  the drop target picks between them. What lives here is that decision and the
//  feedback it switches to.
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// Blank space inside the diagram is the [[Root group]], which is how "drag it
/// out" works without being its own operation (ADR-0016). A node or an edge
/// yields nothing, because the drop target picks the command and those two
/// always mean `connect`.
func moveDestination(under target: JSValue) -> String {
    guard let session = graphSession, isOverDiagram(target) else { return "" }
    let id = elementId(under: target)
    if id.isEmpty { return session.rootGroupId() }
    return session.kind(of: id) == .group ? id : ""
}

/// A group is grabbed by its label, its interior belonging to the
/// [[Rubber band]] and having to stay there — or band-selecting inside a
/// boundary becomes impossible.
func groupLabelUnder(_ target: JSValue) -> String {
    guard let session = graphSession,
        target.object?.closest?(".\(SVGElementId.groupLabelClass)").object != nil
    else { return "" }
    let id = elementId(under: target)
    return session.kind(of: id) == .group ? id : ""
}

func performMove(source: String, destination: String, allowingBreak: Bool) {
    guard let session = graphSession else { return }
    let notationBreak: VNotationBreak = allowingBreak ? .permitted : .forbidden
    let cargo = EditorCore.cargo(grabbing: source, holding: selection, in: session)
    // Asking before running is what keeps a refused drop silent rather than
    // surfacing an error for something the wash already declined to offer.
    guard session.moveDestinations(for: cargo, notationBreak: notationBreak).contains(destination) else { return }

    runNamed { s throws(VError) in try s.move(cargo, into: destination, notationBreak: notationBreak) }
    // The elements still exist and are still what the user was working with, so
    // they stay selected. Nothing was created, so nothing opens for naming.
    selectionChanged()
}

// MARK: - Feedback

/// Non-reactive for the same reason the drag line is: painted onto the SVG,
/// which ElementaryUI does not own.
nonisolated(unsafe) var dropTargetId: String = ""

/// A wash rather than an outline because `connect` is a line between two points
/// and move is about ending up inside a volume — and because the stroke palette
/// is spent: green is a legal connect drop, red an illegal one, violet the
/// [[Selection]], blue the renderer's hover.
///
/// Callers pass `""` for an illegal destination rather than a colour for it:
/// silence means no (ADR-0019), and ⌥ is how past containment (ADR-0032).
func paintDropTarget(_ groupId: String) {
    guard groupId != dropTargetId else { return }
    clearDropTarget()
    guard !groupId.isEmpty else { return }

    // The renderer draws no element carrying the root's id, so its wash goes on
    // the preview — which is the honest picture anyway, the canvas *being* the
    // root group (ADR-0016).
    if groupId == graphSession?.rootGroupId() {
        _ = element(DOMId.preview)?.classList.object?.add?("vg-drop-root".jsValue)
    } else {
        let element = JSObject.global.document.getElementById(SVGElementId.group(groupId)).object
        _ = element?.classList.object?.add?("vg-drop-target".jsValue)
    }
    dropTargetId = groupId
}

func clearDropTarget() {
    _ = element(DOMId.preview)?.classList.object?.remove?("vg-drop-root".jsValue)
    guard let preview = element(DOMId.preview),
        let painted = preview.querySelectorAll?(".vg-drop-target").object,
        let count = painted.length.number
    else {
        dropTargetId = ""
        return
    }
    for index in 0..<Int(count) {
        _ = painted[index].object?.classList.object?.remove?("vg-drop-target".jsValue)
    }
    dropTargetId = ""
}
