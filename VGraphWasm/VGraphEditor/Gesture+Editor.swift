//
//  Gesture+Editor.swift
//  VGraphEditor
//
//  The press, in the browser: hit tests, measuring and painting. What the press
//  *is* — and which of connect, move, reattach, band, click or menu it becomes —
//  is `EditorCore.GestureState`'s to say.
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

// MARK: - State

/// Non-reactive: a gesture draws only into the childless overlay and onto the
/// SVG, neither of which ElementaryUI owns.
nonisolated(unsafe) var gesture = GestureState()

nonisolated(unsafe) var holdTimer: JSValue = .undefined

let holdDelayMs: Double = 500

// MARK: - Events in

func handlePress(_ event: RawPointerEvent) {
    let grabbed = graphSession.flatMap { session in
        EditorCore.grab(
            edgeEnd: edgeEndUnder(event.target), groupLabel: groupLabelUnder(event.target),
            element: elementId(under: event.target), in: session)
    }
    // Named-export timer, not a `JSClosure` (see the header of `Editor.swift`).
    // A host that never binds it simply has no long press, as `scheduleRender`
    // degrades to rendering immediately.
    let holdable = event.pointerType != "mouse" && JSObject.global.__vgraphLongPress.function != nil
    send(
        .press(
            at: point(of: event), button: event.button, isPrimary: event.isPrimary, grab: grabbed,
            shift: event.shiftKey, alt: event.altKey, holdable: holdable),
        from: event)
}

func handlePointerMove(_ event: RawPointerEvent) {
    send(.move(to: point(of: event), buttonsHeld: event.buttons != 0, alt: event.altKey), from: event)
}

func handleRelease(_ event: RawPointerEvent) {
    send(.release(at: point(of: event), alt: event.altKey, shift: event.shiftKey), from: event)
}

func abandonGesture() {
    send(.lost)
}

func handleGestureKey(_ event: RawKeyEvent) -> Bool {
    send(.key(event.key, alt: event.altKey))
}

func holdElapsed() {
    holdTimer = .undefined
    send(.holdElapsed)
}

func gestureRedrawn() {
    send(.redrawn)
}

@discardableResult
private func send(_ event: GestureEvent, from pointer: RawPointerEvent? = nil) -> Bool {
    guard let session = graphSession else { return false }
    let target = pointer?.target ?? .undefined
    let step = gesture.handling(
        event, holding: selection, in: session,
        hit: { hit(under: target) }, anchor: { anchor(of: $0) })
    gesture = step.state
    for effect in step.effects { enact(effect, pointer: pointer) }
    return step.consumed
}

// MARK: - Effects out

private func enact(_ effect: GestureEffect, pointer: RawPointerEvent?) {
    switch effect {
    case .claimPointer:
        // Suppresses the browser's own text selection over the SVG — and the
        // focus change with it, hence `focusEditor`: a keydown on `body` never
        // bubbles *into* the tree, so Escape and ⌥ would be lost.
        pointer?.preventDefault()
        focusEditor()
    case .releaseCapture:
        if let pointer { releaseImplicitCapture(pointer) }
    case .startHoldTimer:
        let global = JSObject.global
        holdTimer = global.setTimeout?(global.__vgraphLongPress, holdDelayMs) ?? .undefined
    case .stopHoldTimer:
        _ = JSObject.global.clearTimeout?(holdTimer)
        holdTimer = .undefined
    case .drawLine(let from, let to, let legal):
        element(DOMId.dragOverlay)?.innerHTML = lineSVG(from: from, to: to, legal: legal).jsValue
    case .drawBand(let rect):
        element(DOMId.dragOverlay)?.innerHTML = bandSVG(rect).jsValue
    case .clearOverlay:
        element(DOMId.dragOverlay)?.innerHTML = "".jsValue
    case .washDropTarget(let group):
        paintDropTarget(group)
    case .clearDropTarget:
        clearDropTarget()
    case .dimEdge(let edge):
        paintReattaching(edge)
    case .undimEdge:
        clearReattaching()
    case .run(let decided, let allowingBreak, let at):
        switch decided {
        case .connect(let from, let to):
            performGesture(source: from, target: to, allowingBreak: allowingBreak, atX: at.x, atY: at.y)
        case .move(let source, let into):
            performMove(source: source, destination: into, allowingBreak: allowingBreak)
        case .reattach(let edge, let end, let to):
            performReattach(edge: edge, end: end, to: to, allowingBreak: allowingBreak, atX: at.x, atY: at.y)
        }
    case .click(let id, let extending):
        clickSelect(id, extending: extending)
    case .catchBand(let rect, let additive):
        let caught = bandCaught(rect)
        selection = additive ? selection.adding(caught) : Selection(caught)
        selectionChanged()
    case .clearSelection:
        clearSelection()
    case .openMenu(let at):
        // Re-hit-tested rather than trusting the element pressed: the debounced
        // render can have replaced the preview during the hold.
        let target = JSObject.global.document.elementFromPoint(at.x, at.y)
        guard isOverDiagram(target) else { return }
        // ⌥ is what permits a notation break, and a finger has no ⌥ (ADR-0018).
        if openMenu(target: target, x: at.x, y: at.y, allowingBreak: .forbidden) {
            send(.heldMenuOpened)
        }
    }
}

private func lineSVG(from: VPoint, to: VPoint, legal: Bool) -> String {
    let cssClass = legal ? "vg-drag-line vg-drag-legal" : "vg-drag-line vg-drag-illegal"
    return "<svg width=\"100%\" height=\"100%\" style=\"display:block;\">"
        + "<line class=\"\(cssClass)\""
        + " x1=\"\(Int(from.x))\" y1=\"\(Int(from.y))\""
        + " x2=\"\(Int(to.x))\" y2=\"\(Int(to.y))\" /></svg>"
}

private func bandSVG(_ rect: VRect) -> String {
    "<svg width=\"100%\" height=\"100%\" style=\"display:block;\">"
        + "<rect class=\"vg-band\" x=\"\(Int(rect.x))\" y=\"\(Int(rect.y))\""
        + " width=\"\(Int(rect.width))\" height=\"\(Int(rect.height))\" /></svg>"
}

// MARK: - Hit tests

private func point(of event: RawPointerEvent) -> VPoint {
    VPoint(x: event.clientX, y: event.clientY)
}

private func hit(under target: JSValue) -> Hit {
    Hit(
        element: elementId(under: target), moveDestination: moveDestination(under: target),
        overDiagram: isOverDiagram(target))
}

/// The OriginGraph id under `target`, or "" for a miss — the walk
/// `handleContextMenu` does.
func elementId(under target: JSValue) -> String {
    guard let targetObj = target.object,
        let el = targetObj.closest?(SVGElementId.contextMenuSelector).object,
        let domId = el.id.string,
        let id = SVGElementId.originId(fromDomId: domId)
    else { return "" }
    return id
}

/// `pointerup` is bound on the editor **root**, so a drag ending outside the
/// preview still tidies up. That makes every release in the editor arrive
/// here — including the one on the toolbar's own Group button, which would
/// otherwise read as a click on empty canvas and clear the selection out from
/// under the command it was about to run.
func isOverDiagram(_ target: JSValue) -> Bool {
    target.object?.closest?("#\(DOMId.preview)").object != nil
}

/// A touch pointer gets *implicit* pointer capture to its `pointerdown`
/// target, which would pin `event.target` to the pressed element for the rest
/// of the gesture — and `event.target` is the entire hit test
/// (``elementId(under:)``), so every drag would think it was still over where
/// it started. Releasing it makes touch retarget exactly as a mouse does.
///
/// Asked before released: `releasePointerCapture` throws for a pointer this
/// element does not hold, which a mouse never has.
private func releaseImplicitCapture(_ event: RawPointerEvent) {
    guard let element = event.target.object,
        element.hasPointerCapture?(event.pointerId).boolean == true
    else { return }
    _ = element.releasePointerCapture?(event.pointerId)
}

/// The drawn element for an OriginGraph id. The kind alone decides the prefix,
/// folded groups included: their box is stamped as the group (ADR-0027).
func drawnElement(for id: String) -> JSObject? {
    guard let kind = graphSession?.kind(of: id) else { return nil }
    return JSObject.global.document.getElementById(SVGElementId.domId(kind: kind, elementId: id)).object
}

// MARK: - Measuring

/// Where the ghost line starts: the centre of what was grabbed — or, for a
/// reattach, of the end that *stays*, since the line previews the edge that
/// would result. That end's own handle is in the same `<g>` and carries its
/// position, so nothing has to ask the domain which node the far end is on. It
/// is absent only when that end sits on a folded group, where the edge's box
/// centre stands in.
private func anchor(of grabbed: Grab) -> VPoint? {
    switch grabbed {
    case .element(let id):
        return centre(of: drawnElement(for: id))
    case .edgeEnd(let edge, let end):
        let far = SVGElementId.edgeEndSide(end == .from ? .to : .from)
        let selector =
            ".\(SVGElementId.edgeEndClass)"
            + "[\(SVGElementId.edgeEndEdgeAttribute)=\"\(edge)\"]"
            + "[\(SVGElementId.edgeEndSideAttribute)=\"\(far)\"]"
        return centre(
            of: JSObject.global.document.querySelector(selector).object
                ?? JSObject.global.document.getElementById(SVGElementId.edge(edge)).object)
    }
}

private func centre(of element: JSObject?) -> VPoint? {
    guard let rect = element?.getBoundingClientRect?().object,
        let left = rect.left.number, let top = rect.top.number,
        let width = rect.width.number, let height = rect.height.number
    else { return nil }
    return VPoint(x: left + width / 2, y: top + height / 2)
}

// MARK: - The drop

/// `performCommand` for a gesture: the elements come from the drag, and ⌥ at
/// release is the notation break.
func performGesture(
    source: String, target: String, allowingBreak: Bool, atX x: Double, atY y: Double
) {
    dismissMenu()
    editorModel.menuAt = VPoint(x: x, y: y)

    guard let session = sessionSyncedToText() else { return }
    let (step, opened) = EditorCore.beginConnect(
        from: source, to: target, allowingBreak: allowingBreak, in: session)
    conversation = opened
    apply(step)
}
