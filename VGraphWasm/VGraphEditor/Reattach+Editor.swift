//
//  Reattach+Editor.swift
//  VGraphEditor
//
//  Dragging one end of an edge onto another node. See ADR-0021.
//
//  A third meaning on the same press-and-drag, told apart by what was *grabbed*
//  rather than by where it was dropped — which is what `connect` (ADR-0012) and
//  `move` (ADR-0019) both use. The handle is chrome the renderer stamps, so the
//  grab is a hit test all of its own: an [[Edge end]] has no id, naming the pair
//  (edge, end) through two data attributes instead.
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// `elementId(under:)` finds the edge here too; `EditorCore.grab` decides which
/// wins.
func edgeEndUnder(_ target: JSValue) -> (edge: String, end: VEdgeEnd)? {
    guard let el = target.object?.closest?(".\(SVGElementId.edgeEndClass)").object,
        let edge = el.getAttribute?(SVGElementId.edgeEndEdgeAttribute).string,
        let side = el.getAttribute?(SVGElementId.edgeEndSideAttribute).string,
        let end = SVGElementId.edgeEnd(fromSide: side),
        !edge.isEmpty
    else { return nil }
    return (edge, end)
}

// MARK: - Feedback

/// The edge currently in the user's hand, dimmed so the ghost line reads as
/// *replacing* it rather than adding a second edge beside it.
///
/// Painted inside the SVG, as ADR-0019's drop-target wash is: safe because a
/// render cancels the drag, so the class cannot outlive what it points at.
nonisolated(unsafe) var reattachingEdgeId: String = ""

func paintReattaching(_ edgeId: String) {
    guard edgeId != reattachingEdgeId else { return }
    clearReattaching()
    guard !edgeId.isEmpty else { return }
    _ = JSObject.global.document.getElementById(SVGElementId.edge(edgeId))
        .object?.classList.object?.add?("vg-reattaching".jsValue)
    reattachingEdgeId = edgeId
}

func clearReattaching() {
    guard let preview = element(DOMId.preview),
        let painted = preview.querySelectorAll?(".vg-reattaching").object,
        let count = painted.length.number
    else {
        reattachingEdgeId = ""
        return
    }
    for index in 0..<Int(count) {
        _ = painted[index].object?.classList.object?.remove?("vg-reattaching".jsValue)
    }
    reattachingEdgeId = ""
}

// MARK: - The drop

/// `performGesture` for a reattach: the edge and the end come from the handle
/// grabbed, the landing node from the release, and ⌥ from the key at release.
func performReattach(
    edge: String, end: VEdgeEnd, to target: String, allowingBreak: Bool,
    atX x: Double, atY y: Double
) {
    dismissMenu()
    editorModel.menuAt = VPoint(x: x, y: y)

    guard let session = sessionSyncedToText() else { return }
    let (step, opened) = EditorCore.beginReattach(
        edge: edge, end: end, to: target, allowingBreak: allowingBreak, in: session)
    conversation = opened
    apply(step)
}
