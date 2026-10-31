//
//  ContextMenu+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// Right-click on the SVG preview. If no commands apply (or the click missed a
/// graph element) the browser's native menu is left alone — which is why the
/// `preventDefault()` lives out here and not in ``openMenu``, whose other
/// caller is a timer with no live event to suppress.
func handleContextMenu(_ event: RawPointerEvent) {
    guard
        openMenu(
            target: event.target, x: event.clientX, y: event.clientY,
            allowingBreak: event.altKey ? .permitted : .forbidden)
    else { return }
    event.preventDefault()
}

func openMenu(target: JSValue, x: Double, y: Double, allowingBreak allowed: VNotationBreak) -> Bool {
    guard let targetObj = target.object, let session = graphSession else { return false }
    // Walk up from the exact SVG shape under the cursor to its wrapping
    // node/edge/group <g>. `closest` reaches through <path>/<text>/<rect>,
    // and gets z-order and overlap right — which is why the hit test stays
    // here while what the hit *means* does not.
    //
    // A miss is passed on as `nil` rather than resolved here: blank canvas
    // is the [[Root group]] only for the menu, and `elementId(under:)`'s
    // other three callers are drag handlers, where blank space really does
    // mean nothing (ADR-0016).
    let hit: String? =
        targetObj.closest?(SVGElementId.contextMenuSelector).object
        .flatMap { $0.id.string }
        .flatMap { SVGElementId.originId(fromDomId: $0) }

    // An [[Edge bundle]] names no OriginGraph element, only the folded groups it
    // runs into (ADR-0027).
    let unfolds: [String]? =
        targetObj.closest?(".\(SVGElementId.edgeBundleClass)").object
        .flatMap { $0.getAttribute?(SVGElementId.unfoldsAttribute).string }
        .map { $0.split(separator: " ").map { String($0) } }

    let decision =
        if let unfolds {
            EditorCore.rightClickOnBundle(unfolding: unfolds, holding: selection, in: session)
        } else {
            EditorCore.rightClick(on: hit, holding: selection, in: session, notationBreak: allowed)
        }
    guard let decided = decision else { return false }  // no commands → leave the browser's own menu

    if decided.selection != selection {
        selection = decided.selection
        selectionChanged()
    }
    menuFromSelection = decided.fromSelection

    // A fresh right-click abandons any conversation still on screen: the new
    // target is what the user means now.
    dismissMenu()
    menuItems = decided.items
    editorModel.menuTargetId = decided.target
    editorModel.menuAt = VPoint(x: x, y: y)
    editorModel.menuVisible = true
    return true
}

/// Inline style for the menu container — only the dynamic viewport position;
/// appearance lives in the `.vg-ctx-menu` CSS class (theme-aware).
///
/// Opened at the pointer, then lifted by exactly as much as it would overflow
/// the window's bottom: a percentage in `translateY` is the menu's own height,
/// which only the browser knows. Without it a right-click low on the canvas
/// left the last rows out of reach.
func contextMenuPositionStyle() -> String {
    let top = Int(editorModel.menuAt.y)
    return "left:\(Int(editorModel.menuAt.x))px;top:\(top)px;"
        + "transform:translateY(min(0px, calc(100vh - \(top)px - 100% - 8px)));"
}
