//
//  Gesture.swift
//  EditorCore
//
//  One press carries three commands — connect (ADR-0012), move (ADR-0019) and
//  reattach (ADR-0021) — told apart by what was grabbed and where it landed.
//  The hit tests stay in the browser, where `closest` gets z-order right; what
//  they found arrives here as ids.
//

import App
import VGraph

public enum Grab: Sendable, Equatable {
    case element(String)
    case edgeEnd(edge: String, end: VEdgeEnd)
}

/// Asking the port what may be grabbed keeps "a folded group renders as a node
/// but resolves to `.group`" out of the browser.
public func grab(
    edgeEnd: (edge: String, end: VEdgeEnd)?, groupLabel: String, element: String,
    in session: some ForEditAGraphVisually
) -> Grab? {
    if let edgeEnd { return .edgeEnd(edge: edgeEnd.edge, end: edgeEnd.end) }
    if !groupLabel.isEmpty { return .element(groupLabel) }
    guard !element.isEmpty, session.connectSources().contains(element) else { return nil }
    return .element(element)
}

/// Not checked for legality here: a drop never supplies judgement, the command
/// does (CONTEXT.md [[Gesture]]).
public enum Drop: Sendable, Equatable {
    case connect(from: String, to: String)
    case move(source: String, into: String)
    case reattach(edge: String, end: VEdgeEnd, to: String)
}

public func drop(
    _ grabbed: Grab, on target: String, moveDestination: String,
    in session: some ForEditAGraphVisually
) -> Drop? {
    switch grabbed {
    case .edgeEnd(let edge, let end):
        guard !target.isEmpty, session.kind(of: target) == .node else { return nil }
        return .reattach(edge: edge, end: end, to: target)
    case .element(let source):
        if !moveDestination.isEmpty { return .move(source: source, into: moveDestination) }
        guard !target.isEmpty, target != source else { return nil }
        return .connect(from: source, to: target)
    }
}

public func cargo(
    grabbing source: String, holding selection: Selection, in session: some ForEditAGraphVisually
) -> [String] {
    guard selection.covers(source, in: session) else { return [source] }
    return selection.effective(in: session)
}

// MARK: - The press, from pointerdown to release

/// Adapter state, like [[Selection]]: the document never hears of it.
public struct GestureState: Sendable, Equatable {
    public internal(set) var press: Press
    public internal(set) var hold: Hold

    public init() {
        press = .idle
        hold = Hold()
    }
}

public enum Press: Sendable, Equatable {
    case idle
    case drag(Drag)
    case band(Band)
}

public struct Drag: Sendable, Equatable {
    public let grab: Grab
    public let start: VPoint
    public internal(set) var last: VPoint
    /// Where the line starts; measured when the drag crosses the threshold.
    public internal(set) var anchor: VPoint?
    public internal(set) var alt: Bool
    public internal(set) var hover = ""
    public internal(set) var moveDestination = ""
    var legalTargets: LegalTargets? = nil

    public var crossedThreshold: Bool { anchor != nil }
}

/// What the port called legal under one ⌥ state, so a pointer move need not ask
/// again.
struct LegalTargets: Sendable, Equatable {
    let alt: Bool
    let ids: [String]
}

public struct Band: Sendable, Equatable {
    public let additive: Bool
    public let start: VPoint
    public internal(set) var last: VPoint
    public internal(set) var crossedThreshold = false

    public var rect: VRect {
        VRect(
            origin: VPoint(x: min(start.x, last.x), y: min(start.y, last.y)),
            size: VSize(width: abs(last.x - start.x), height: abs(last.y - start.y)))
    }
}

/// The long press that stands in for a right-click on touch (ADR-0018).
public struct Hold: Sendable, Equatable {
    public internal(set) var armed = false
    public internal(set) var start = VPoint.zero
    /// The menu has opened, so the release still to come is not a click.
    public internal(set) var swallowsRelease = false

    public init() {}

    init(armed: Bool, start: VPoint) {
        self.armed = armed
        self.start = start
    }
}

public struct Hit: Sendable, Equatable {
    public let element: String
    /// The [[Root group]] over blank canvas; `""` off the diagram or over
    /// anything but a group.
    public let moveDestination: String
    public let overDiagram: Bool

    public init(element: String, moveDestination: String, overDiagram: Bool) {
        self.element = element
        self.moveDestination = moveDestination
        self.overDiagram = overDiagram
    }
}

public enum GestureEvent: Sendable, Equatable {
    /// `holdable`: touch or pen, on a host that lends a clock.
    case press(
        at: VPoint, button: Int, isPrimary: Bool, grab: Grab?, shift: Bool, alt: Bool, holdable: Bool)
    case move(to: VPoint, buttonsHeld: Bool, alt: Bool)
    case release(at: VPoint, alt: Bool, shift: Bool)
    /// A key going down or up; `alt` is ⌥'s state after it.
    case key(String, alt: Bool)
    case holdElapsed
    case heldMenuOpened
    case redrawn
    /// `pointercancel`: a touch promoted to a scroll, or a system gesture.
    case lost
}

/// Carried out in order.
public enum GestureEffect: Sendable, Equatable {
    /// Suppress the browser's text selection over the SVG, and keep focus where
    /// a keydown still reaches the editor.
    case claimPointer
    /// Undo the implicit capture a touch takes on its `pointerdown` target.
    case releaseCapture
    case startHoldTimer
    case stopHoldTimer
    case drawLine(from: VPoint, to: VPoint, legal: Bool)
    case drawBand(VRect)
    case clearOverlay
    /// `""` for a refused destination: silence means no (ADR-0019).
    case washDropTarget(String)
    case clearDropTarget
    case dimEdge(String)
    case undimEdge
    case run(Drop, allowingBreak: Bool, at: VPoint)
    case click(String, extending: Bool)
    case catchBand(VRect, additive: Bool)
    case clearSelection
    case openMenu(at: VPoint)
}

public struct GestureStep: Sendable, Equatable {
    public let state: GestureState
    public let effects: [GestureEffect]
    /// A consumed key is not undo's or the browser's.
    public let consumed: Bool
}

extension GestureState {
    /// `hit` and `anchor` are the browser's measurements, asked only when the
    /// gesture needs them: hit-testing every pointer move over the editor, or
    /// forcing layout for an anchor on every press, would be paid for nothing.
    public func handling(
        _ event: GestureEvent, holding selection: Selection, in session: some ForEditAGraphVisually,
        hit: () -> Hit, anchor: (Grab) -> VPoint?
    ) -> GestureStep {
        var step = PendingStep(from: self)
        switch event {
        case .press(let point, let button, let isPrimary, let grabbed, let shift, let alt, let holdable):
            guard button == mainButton, isPrimary else { break }
            step.press(grabbed, at: point, shift: shift, alt: alt, holdable: holdable)
        case .move(let point, let buttonsHeld, let alt):
            step.move(
                to: point, buttonsHeld: buttonsHeld, alt: alt, holding: selection, in: session, hit: hit,
                anchor: anchor)
        case .release(let point, let alt, let shift):
            step.release(at: point, alt: alt, shift: shift, in: session, hit: hit)
        case .key(let key, let alt):
            step.key(key, alt: alt, holding: selection, in: session)
        case .holdElapsed:
            step.openHeldMenu()
        case .heldMenuOpened:
            step.state.hold.swallowsRelease = true
        case .redrawn:
            step.endPress()
        case .lost:
            step.disarmHold()
            step.endPress()
        }
        return GestureStep(state: step.state, effects: step.effects, consumed: step.consumed)
    }
}

/// The DOM's `button` for the main (usually left) button.
private let mainButton = 0

/// One event's step while it is being worked out; `handling` stays a pure
/// function of the state it was given.
private struct PendingStep {
    var state: GestureState
    var effects: [GestureEffect] = []
    var consumed = false

    init(from state: GestureState) {
        self.state = state
    }

    mutating func press(_ grabbed: Grab?, at point: VPoint, shift: Bool, alt: Bool, holdable: Bool) {
        effects += clearAllFeedback
        effects += [.releaseCapture, .stopHoldTimer]
        state.hold = Hold(armed: holdable, start: point)
        if holdable { effects.append(.startHoldTimer) }
        effects.append(.claimPointer)
        if let grabbed, !shift {
            state.press = .drag(Drag(grab: grabbed, start: point, last: point, anchor: nil, alt: alt))
        } else {
            state.press = .band(Band(additive: shift, start: point, last: point))
        }
    }

    mutating func move(
        to point: VPoint, buttonsHeld: Bool, alt: Bool, holding selection: Selection,
        in session: some ForEditAGraphVisually, hit: () -> Hit, anchor: (Grab) -> VPoint?
    ) {
        if state.hold.armed, isBeyondThreshold(point, from: state.hold.start) { disarmHold() }
        switch state.press {
        case .idle:
            return
        case .band(let band):
            guard buttonsHeld else { return endPress() }
            stretch(band, to: point)
        case .drag(let drag):
            guard buttonsHeld else { return endPress() }
            pull(drag, to: point, alt: alt, holding: selection, in: session, hit: hit, anchor: anchor)
        }
    }

    mutating func release(
        at point: VPoint, alt: Bool, shift: Bool, in session: some ForEditAGraphVisually, hit: () -> Hit
    ) {
        disarmHold()
        guard !state.hold.swallowsRelease else {
            state.hold.swallowsRelease = false
            return
        }
        let released = state.press
        endPress()
        switch released {
        case .band(let band) where band.crossedThreshold:
            effects.append(.catchBand(band.rect, additive: band.additive))
        case .drag(let drag) where drag.crossedThreshold:
            let under = hit()
            guard
                let decided = drop(
                    drag.grab, on: under.element, moveDestination: under.moveDestination, in: session)
            else { return }
            effects.append(.run(decided, allowingBreak: alt, at: point))
        default:
            let under = hit()
            if under.overDiagram { effects.append(.click(under.element, extending: shift)) }
        }
    }

    mutating func key(
        _ key: String, alt: Bool, holding selection: Selection, in session: some ForEditAGraphVisually
    ) {
        switch state.press {
        case .idle:
            guard key == "Escape", !selection.isEmpty else { return }
            effects.append(.clearSelection)
            consumed = true
        case .band:
            guard key == "Escape" else { return }
            endPress()
            consumed = true
        case .drag(var drag):
            if key == "Escape" {
                endPress()
                consumed = true
            } else if key == "Alt" {
                consumed = true
                guard alt != drag.alt else { return }
                drag.alt = alt
                repaint(drag, holding: selection, in: session)
            }
        }
    }

    mutating func openHeldMenu() {
        guard state.hold.armed else { return }
        state.hold.armed = false
        endPress()
        effects.append(.openMenu(at: state.hold.start))
    }

    mutating func disarmHold() {
        state.hold.armed = false
        effects.append(.stopHoldTimer)
    }

    /// Every way out of a press clears everything, whatever was painted: it is
    /// cheap, and nothing can be left behind.
    mutating func endPress() {
        state.press = .idle
        effects += clearAllFeedback
    }

    private mutating func stretch(_ band: Band, to point: VPoint) {
        var band = band
        band.last = point
        if !band.crossedThreshold { band.crossedThreshold = isBeyondThreshold(point, from: band.start) }
        state.press = .band(band)
        if band.crossedThreshold { effects.append(.drawBand(band.rect)) }
    }

    private mutating func pull(
        _ drag: Drag, to point: VPoint, alt: Bool, holding selection: Selection,
        in session: some ForEditAGraphVisually, hit: () -> Hit, anchor: (Grab) -> VPoint?
    ) {
        var drag = drag
        drag.last = point
        drag.alt = alt
        if !drag.crossedThreshold {
            guard isBeyondThreshold(point, from: drag.start) else {
                state.press = .drag(drag)
                return
            }
            guard let measured = anchor(drag.grab) else { return endPress() }
            drag.anchor = measured
            if case .edgeEnd(let edge, _) = drag.grab { effects.append(.dimEdge(edge)) }
        }
        repaint(drag.hovering(over: hit()), holding: selection, in: session)
    }

    private mutating func repaint(
        _ drag: Drag, holding selection: Selection, in session: some ForEditAGraphVisually
    ) {
        var drag = drag
        if drag.crossedThreshold { drag.legalTargets = legalTargets(of: drag, in: session) }
        effects += feedback(for: drag, holding: selection, in: session)
        state.press = .drag(drag)
    }
}

extension Drag {
    /// An element is never its own target, and only an element moves: an edge
    /// end cannot join a group (ADR-0017).
    fileprivate func hovering(over under: Hit) -> Drag {
        var drag = self
        switch grab {
        case .edgeEnd:
            drag.hover = under.element
            drag.moveDestination = ""
        case .element(let source):
            drag.hover = under.element == source ? "" : under.element
            drag.moveDestination = under.moveDestination
        }
        return drag
    }
}

private func feedback(
    for drag: Drag, holding selection: Selection, in session: some ForEditAGraphVisually
) -> [GestureEffect] {
    guard let anchor = drag.anchor else { return [] }
    if case .element(let source) = drag.grab, !drag.moveDestination.isEmpty {
        let carried = cargo(grabbing: source, holding: selection, in: session)
        let notationBreak: VNotationBreak = drag.alt ? .permitted : .forbidden
        let legal = session.moveDestinations(for: carried, notationBreak: notationBreak)
            .contains(drag.moveDestination)
        return [.washDropTarget(legal ? drag.moveDestination : ""), .clearOverlay]
    }
    let legal = drag.legalTargets?.ids.contains(drag.hover) ?? false
    return [.clearDropTarget, .drawLine(from: anchor, to: drag.last, legal: legal)]
}

/// The port is asked again only when ⌥ has changed since it last answered.
private func legalTargets(of drag: Drag, in session: some ForEditAGraphVisually) -> LegalTargets {
    if let remembered = drag.legalTargets, remembered.alt == drag.alt { return remembered }
    let notationBreak: VNotationBreak = drag.alt ? .permitted : .forbidden
    let ids =
        switch drag.grab {
        case .edgeEnd(let edge, let end):
            session.reattachTargets(edge: edge, end: end, notationBreak: notationBreak)
        case .element(let source): session.connectTargets(from: source, notationBreak: notationBreak)
        }
    return LegalTargets(alt: drag.alt, ids: ids)
}

/// ADR-0012's 4px of jitter tolerance; one threshold for every gesture.
private func isBeyondThreshold(_ point: VPoint, from start: VPoint) -> Bool {
    let threshold = 4.0
    let dx = point.x - start.x
    let dy = point.y - start.y
    return dx * dx + dy * dy >= threshold * threshold
}

private var clearAllFeedback: [GestureEffect] { [.undimEdge, .clearDropTarget, .clearOverlay] }
