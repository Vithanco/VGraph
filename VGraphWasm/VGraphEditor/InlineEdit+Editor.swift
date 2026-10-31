//
//  InlineEdit+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// Double-click on the SVG preview: rename the element under the cursor, by
/// routing through `setLabel` with no answer — which changes nothing and hands
/// the target back to be edited (ADR-0009). Guards and target resolution stay
/// in the command, so a junctor or a miss is simply a no-op.
///
/// A group is editable only via its title: its boundary encloses everything
/// inside it, so anything else in the cluster must fall through.
func handleDoubleClick(_ event: RawPointerEvent) {
    guard let targetObj = event.target.object else { return }
    // The badge is a real anchor — its first click already opened the tab.
    guard targetObj.closest?(".\(URLBadgeRenderer.cssClass)").object == nil else { return }
    let insideGroupLabel = targetObj.closest?(".\(SVGElementId.groupLabelClass)").object != nil
    let selector = SVGElementId.doubleClickSelector(insideGroupLabel: insideGroupLabel)
    guard let el = targetObj.closest?(selector).object,
        let domId = el.id.string,
        let id = SVGElementId.originId(fromDomId: domId)
    else { return }

    event.preventDefault()
    renameCommand(id)
}

// MARK: - Inline editing (ADR-0009)

/// `nearest` because scrolling the diagram under a user who can already see
/// the element would be a worse bug than the one this fixes.
///
/// Computed rather than stored: a module-level `let` with a runtime
/// initialiser needs lazy initialisation under Embedded Swift.
private var scrollIntoViewOptions: JSValue {
    guard let options = JSObject.global.Object.function?.new() else { return .undefined }
    options.block = "nearest".jsValue
    options.inline = "nearest".jsValue
    options.behavior = "instant".jsValue
    return options.jsValue
}

/// Open the overlay editor over a rendered element.
///
/// Seeded from the *graph*, never the rendered text — see `label(of:)`. Edges
/// anchor on their path midpoint because an unlabelled edge, which is the
/// normal case, has no text element to measure.
func beginInlineEdit(elementId: String, kind: VElementKind) {
    guard let session = graphSession,
        let element = JSObject.global.document.getElementById(
            SVGElementId.domId(kind: kind, elementId: elementId)
        ).object
    else { return }

    // Before measuring: a node the user did not place can be outside the
    // visible pane, and an overlay positioned there is an invisible field
    // holding the focus (ADR-0016).
    _ = element.scrollIntoView?(scrollIntoViewOptions)

    let anchor: (x: Double, y: Double, width: Double)
    if kind == .edge {
        guard let midpoint = edgeMidpoint(in: element) else { return }
        anchor = (midpoint.x - 70, midpoint.y - 12, 140)
    } else {
        let box = kind == .group ? groupLabelElement(in: element) ?? element : element
        guard let rect = box.getBoundingClientRect?().object,
            let x = rect.left.number, let y = rect.top.number, let w = rect.width.number
        else { return }
        anchor = (x, y, max(w, 90))
    }

    pendingText = session.label(of: elementId) ?? ""
    editorModel.inlineEdit = InlineEditPlacement(
        targetId: elementId, x: anchor.x, y: anchor.y, width: anchor.width)
}

private func edgeMidpoint(in element: JSObject) -> (x: Double, y: Double)? {
    guard let path = element.querySelector?("path").object,
        let total = path.getTotalLength?().number,
        let point = path.getPointAtLength?(total / 2).object,
        let svg = JSObject.global.document.querySelector("#\(DOMId.preview) svg").object,
        let ctm = path.getScreenCTM?().object,
        let svgPoint = svg.createSVGPoint?().object
    else { return nil }

    // `getPointAtLength` is in SVG *user* space, which the viewBox offsets
    // (the graph's bounding box starts negative). Adding the SVG's client
    // origin is therefore not enough — `getScreenCTM` is the transform that
    // accounts for the viewBox origin and any scaling.
    svgPoint.x = point.x
    svgPoint.y = point.y
    guard let screen = svgPoint.matrixTransform?(ctm.jsValue).object,
        let sx = screen.x.number, let sy = screen.y.number
    else { return nil }
    return (sx, sy)
}

private func groupLabelElement(in element: JSObject) -> JSObject? {
    element.querySelector?(".\(SVGElementId.groupLabelClass)").object
}

/// Commit whatever is in the overlay, as an ordinary `setLabel` command so it
/// lands in history like any other change.
func commitInlineEdit() {
    let open = editorModel.inlineEdit
    let text = pendingText
    endInlineEdit()
    guard let open, let session = sessionSyncedToText() else { return }
    do {
        try session.setLabel(of: open.targetId, to: text)
    } catch {
        return
    }
    // `edit: nil` — the editor has just been closed, and reopening it on the
    // element the user finished typing into is the one thing not wanted.
    commandApplied(edit: nil, in: session)
}

/// Close the overlay without applying. Also what a re-render does: the anchor
/// element is about to be replaced, so the editor cannot outlive it (ADR-0009).
func endInlineEdit() {
    editorModel.inlineEdit = nil
    pendingText = ""
}

/// Placement for the inline editor, over the element being renamed.
func inlineEditPositionStyle(_ placement: InlineEditPlacement) -> String {
    "left:\(Int(placement.x))px;top:\(Int(placement.y))px;width:\(Int(placement.width))px;"
}
