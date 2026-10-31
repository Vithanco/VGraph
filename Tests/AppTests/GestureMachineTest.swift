//
//  GestureMachineTest.swift
//  VGraph
//
//  The press that becomes a connect, a move, a reattach, a rubber band, a click
//  or — held still on touch — a menu (ADR-0012, ADR-0018, ADR-0019, ADR-0021).
//  Which of them is live, and what each pointer event does to it, used to be
//  loose globals in the editor kept apart by call order. Here it is one value,
//  so "only one gesture at a time" is a fact of its type.
//
//  The browser still answers what is under the pointer and where an element is
//  drawn; the tests stand in for it with `hit` and `anchor`.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct GestureMachineTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A";
                  }
                  node r: Relation "leads to";
                  node b: Concept "B";
                  edge a -> r;
                }
                """)
    }

    private func p(_ x: Double, _ y: Double) -> VPoint { VPoint(x: x, y: y) }

    private let anchor = VPoint(x: 5, y: 5)

    /// Runs one event the way the editor does, with the browser stood in for.
    private func run(
        _ state: GestureState, _ event: GestureEvent, in s: TestSession,
        holding selection: Selection = Selection(),
        hit: Hit = Hit(element: "", moveDestination: "", overDiagram: true),
        anchor: VPoint? = VPoint(x: 5, y: 5)
    ) -> GestureStep {
        state.handling(event, holding: selection, in: s, hit: { hit }, anchor: { _ in anchor })
    }

    private func press(
        _ grab: Grab?, at point: VPoint = VPoint(x: 0, y: 0), shift: Bool = false, alt: Bool = false,
        holdable: Bool = false
    ) -> GestureEvent {
        .press(at: point, button: 0, isPrimary: true, grab: grab, shift: shift, alt: alt, holdable: holdable)
    }

    private func move(_ point: VPoint, alt: Bool = false) -> GestureEvent {
        .move(to: point, buttonsHeld: true, alt: alt)
    }

    private func release(_ point: VPoint, alt: Bool = false, shift: Bool = false) -> GestureEvent {
        .release(at: point, alt: alt, shift: shift)
    }

    /// Pressed on `source` and dragged clear of the threshold.
    private func dragging(_ source: String, _ s: TestSession, over hit: Hit) -> GestureStep {
        let pressed = run(GestureState(), press(.element(source)), in: s).state
        return run(pressed, move(p(40, 0)), in: s, hit: hit)
    }

    // MARK: - Pressing

    @Test func aPressOnSomethingDraggableArmsADrag() throws {
        let step = run(GestureState(), press(.element("a")), in: try session())
        guard case .drag(let drag) = step.state.press else {
            Issue.record("expected a drag, got \(step.state.press)")
            return
        }
        #expect(drag.grab == .element("a"))
        #expect(drag.anchor == nil)
        #expect(step.effects.contains(.claimPointer))
    }

    /// Everything a drag does not claim is a band — and ⇧ takes precedence even
    /// over a node, so a band can start in a diagram with no free space.
    @Test func blankCanvasOrShiftArmsABand() throws {
        let s = try session()
        guard case .band(let blank) = run(GestureState(), press(nil), in: s).state.press else {
            Issue.record("expected a band")
            return
        }
        #expect(!blank.additive)
        guard case .band(let shifted) = run(GestureState(), press(.element("a"), shift: true), in: s).state.press
        else {
            Issue.record("expected a band")
            return
        }
        #expect(shifted.additive)
    }

    /// A second finger must not arm a competing gesture on top of the first,
    /// and a right button is the context menu's.
    @Test func onlyThePrimaryLeftPressArmsAnything() throws {
        let s = try session()
        let secondFinger = GestureEvent.press(
            at: p(0, 0), button: 0, isPrimary: false, grab: .element("a"), shift: false, alt: false,
            holdable: true)
        let rightButton = GestureEvent.press(
            at: p(0, 0), button: 2, isPrimary: true, grab: .element("a"), shift: false, alt: false,
            holdable: false)
        for event in [secondFinger, rightButton] {
            let step = run(GestureState(), event, in: s)
            #expect(step.state == GestureState())
            #expect(step.effects.isEmpty)
        }
    }

    // MARK: - Dragging

    /// ADR-0012's 4px of jitter tolerance: a press that has not travelled is
    /// not a drag, and draws nothing.
    @Test func underTheThresholdNothingIsDrawn() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a")), in: s).state
        let step = run(pressed, move(p(3, 0)), in: s)
        #expect(step.effects.isEmpty)
        guard case .drag(let drag) = step.state.press else {
            Issue.record("the press was lost")
            return
        }
        #expect(drag.anchor == nil)
    }

    /// Concept to Relation is what the notation joins; Concept to Concept is
    /// not.
    @Test func pastTheThresholdTheLineShowsWhetherTheDropIsLegal() throws {
        let s = try session()
        let overRelation = dragging("b", s, over: Hit(element: "r", moveDestination: "", overDiagram: true))
        #expect(overRelation.effects.contains(.drawLine(from: anchor, to: p(40, 0), legal: true)))

        let overConcept = dragging("b", s, over: Hit(element: "a", moveDestination: "", overDiagram: true))
        #expect(overConcept.effects.contains(.drawLine(from: anchor, to: p(40, 0), legal: false)))
    }

    /// A source that has left the DOM has nowhere to draw a line from.
    @Test func aSourceThatCannotBeMeasuredCancelsTheDrag() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a")), in: s).state
        let step = run(pressed, move(p(40, 0)), in: s, anchor: nil)
        #expect(step.state.press == .idle)
        #expect(
            !step.effects.contains {
                guard case .drawLine = $0 else { return false }
                return true
            })
    }

    /// Over a group the drop would be a move, so the group is washed instead —
    /// never both, since a green "you may connect" line over a boundary the
    /// drop would move *into* would be a lie (ADR-0019).
    @Test func overAGroupTheDestinationIsWashedInstead() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("r")), in: s).state
        let step = run(pressed, move(p(40, 0)), in: s, hit: Hit(element: "g1", moveDestination: "g1", overDiagram: true))
        #expect(step.effects.contains(.washDropTarget("g1")))
        #expect(step.effects.contains(.clearOverlay))
        #expect(
            !step.effects.contains {
                guard case .drawLine = $0 else { return false }
                return true
            })
    }

    /// ⌥ pressed or released with the pointer still is the one change no
    /// pointer move reports. It permits a notation break, so the same hover
    /// becomes legal.
    @Test func altAloneRepaintsTheLine() throws {
        let s = try session()
        let dragging = dragging("a", s, over: Hit(element: "b", moveDestination: "", overDiagram: true)).state
        let step = run(dragging, .key("Alt", alt: true), in: s)
        #expect(step.consumed)
        #expect(step.effects.contains(.drawLine(from: anchor, to: p(40, 0), legal: true)))
    }

    /// Legality is remembered per ⌥ state, so letting go of ⌥ must not leave
    /// the permissive answer behind.
    @Test func releasingAltRestoresTheStrictLine() throws {
        let s = try session()
        let dragging = dragging("a", s, over: Hit(element: "b", moveDestination: "", overDiagram: true)).state
        let permitted = run(dragging, .key("Alt", alt: true), in: s).state
        let step = run(permitted, .key("Alt", alt: false), in: s)
        #expect(step.effects.contains(.drawLine(from: anchor, to: p(40, 0), legal: false)))
    }

    /// Before the threshold there is no line to repaint, but ⌥ is still the
    /// drag's and must reach the drop.
    @Test func altBeforeTheThresholdDrawsNothingButIsKept() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a")), in: s).state
        let step = run(pressed, .key("Alt", alt: true), in: s)
        #expect(step.consumed)
        #expect(step.effects.isEmpty)
        guard case .drag(let drag) = step.state.press else {
            Issue.record("the press was lost")
            return
        }
        #expect(drag.alt)
    }

    /// The pointer came up somewhere this editor never saw.
    @Test func aMoveWithNoButtonHeldCancels() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a")), in: s).state
        let step = run(pressed, .move(to: p(40, 0), buttonsHeld: false, alt: false), in: s)
        #expect(step.state.press == .idle)
        #expect(step.effects.contains(.clearOverlay))
    }

    @Test func grabbingAnEdgeEndDimsItsEdge() throws {
        let s = try session()
        let edge = try #require(s.origin.edges.first).id.id
        let pressed = run(GestureState(), press(.edgeEnd(edge: edge, end: .to)), in: s).state
        let step = run(pressed, move(p(40, 0)), in: s, hit: Hit(element: "b", moveDestination: "", overDiagram: true))
        #expect(step.effects.contains(.dimEdge(edge)))
    }

    /// An edge end cannot join a group (ADR-0017), so dragging one over a group
    /// draws the line rather than washing the group.
    @Test func anEdgeEndIsNeverOfferedAMove() throws {
        let s = try session()
        let edge = try #require(s.origin.edges.first).id.id
        let pressed = run(GestureState(), press(.edgeEnd(edge: edge, end: .to)), in: s).state
        let step = run(
            pressed, move(p(40, 0)), in: s, hit: Hit(element: "g1", moveDestination: "g1", overDiagram: true))
        #expect(
            !step.effects.contains {
                guard case .washDropTarget = $0 else { return false }
                return true
            })
        #expect(
            step.effects.contains {
                guard case .drawLine = $0 else { return false }
                return true
            })
    }

    // MARK: - Releasing

    @Test func aDragReleasedOverANodeRunsTheDrop() throws {
        let s = try session()
        let over = Hit(element: "r", moveDestination: "", overDiagram: true)
        let dragging = dragging("a", s, over: over).state
        let step = run(dragging, release(p(40, 0), alt: true), in: s, hit: over)
        #expect(step.effects.contains(.run(.connect(from: "a", to: "r"), allowingBreak: true, at: p(40, 0))))
        #expect(step.state.press == .idle)
    }

    /// A stationary press-and-release is a click, whatever was pressed.
    @Test func aPressThatNeverMovedIsAClick() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a")), in: s).state
        let step = run(
            pressed, release(p(1, 0), shift: true), in: s,
            hit: Hit(element: "a", moveDestination: "", overDiagram: true))
        #expect(step.effects.contains(.click("a", extending: true)))
    }

    /// `pointerup` is bound on the editor root, so every release arrives —
    /// including the one on the toolbar's own Group button, which must not
    /// clear the selection it is about to group.
    @Test func aReleaseOffTheDiagramIsNoClick() throws {
        let step = run(
            GestureState(), release(p(0, 0)), in: try session(),
            hit: Hit(element: "", moveDestination: "", overDiagram: false))
        #expect(
            !step.effects.contains {
                guard case .click = $0 else { return false }
                return true
            })
    }

    @Test func aBandThatMovedCatchesWhatItEncloses() throws {
        let s = try session()
        let pressed = run(GestureState(), press(nil, at: p(10, 10), shift: true), in: s).state
        let banding = run(pressed, move(p(4, 30)), in: s)
        let rect = VRect(origin: p(4, 10), size: VSize(width: 6, height: 20))
        #expect(banding.effects.contains(.drawBand(rect)))
        let step = run(banding.state, release(p(4, 30)), in: s)
        #expect(step.effects.contains(.catchBand(rect, additive: true)))
        #expect(
            !step.effects.contains {
                guard case .click = $0 else { return false }
                return true
            })
    }

    @Test func aBandThatNeverMovedIsAClick() throws {
        let s = try session()
        let pressed = run(GestureState(), press(nil), in: s).state
        let step = run(pressed, release(p(1, 1)), in: s, hit: Hit(element: "", moveDestination: "", overDiagram: true))
        #expect(step.effects.contains(.click("", extending: false)))
    }

    // MARK: - Escape

    @Test func escapeCancelsADragOrABand() throws {
        let s = try session()
        for grab in [Grab.element("a"), nil] {
            let pressed = run(GestureState(), press(grab), in: s).state
            let step = run(pressed, .key("Escape", alt: false), in: s)
            #expect(step.consumed)
            #expect(step.state.press == .idle)
        }
    }

    /// With nothing in flight, Escape is the keyboard half of "click blank
    /// canvas" (ADR-0018) — and with nothing selected either, it is not ours.
    @Test func escapeWithNothingInFlightClearsTheSelection() throws {
        let s = try session()
        let held = run(GestureState(), .key("Escape", alt: false), in: s, holding: Selection(["a"]))
        #expect(held.consumed)
        #expect(held.effects == [.clearSelection])
        #expect(!run(GestureState(), .key("Escape", alt: false), in: s).consumed)
    }

    // MARK: - Holding

    /// Touch and pen only: a mouse has the button, and holding it still would
    /// then mean two things.
    @Test func onlyAHoldablePressStartsTheClock() throws {
        let s = try session()
        #expect(run(GestureState(), press(.element("a"), holdable: true), in: s).effects.contains(.startHoldTimer))
        #expect(!run(GestureState(), press(.element("a")), in: s).effects.contains(.startHoldTimer))
    }

    @Test func aPressThatTravelsIsNoLongerAHold() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a"), holdable: true), in: s).state
        let step = run(pressed, move(p(5, 0)), in: s)
        #expect(step.effects.contains(.stopHoldTimer))
        #expect(!step.state.hold.armed)
    }

    /// The press has become the menu, so neither gesture it also armed may run
    /// — and the release still to come must not fall through to a click, which
    /// would collapse the selection the menu was built from.
    @Test func aHoldOpensTheMenuAndSwallowsItsRelease() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a"), at: p(7, 8), holdable: true), in: s).state
        let fired = run(pressed, .holdElapsed, in: s)
        #expect(fired.state.press == .idle)
        #expect(fired.effects.last == .openMenu(at: p(7, 8)))

        let opened = run(fired.state, .heldMenuOpened, in: s).state
        let swallowed = run(opened, release(p(7, 8)), in: s, hit: Hit(element: "a", moveDestination: "", overDiagram: true))
        #expect(
            !swallowed.effects.contains {
                guard case .click = $0 else { return false }
                return true
            })

        let next = run(swallowed.state, release(p(7, 8)), in: s, hit: Hit(element: "a", moveDestination: "", overDiagram: true))
        #expect(next.effects.contains(.click("a", extending: false)))
    }

    /// A render replaces the SVG under a drag and cancels it — but a hold
    /// re-hit-tests when it fires, so it survives the debounced render that can
    /// land during it.
    @Test func aRedrawCancelsTheDragButNotTheHold() throws {
        let s = try session()
        let pressed = run(GestureState(), press(.element("a"), holdable: true), in: s).state
        let redrawn = run(pressed, .redrawn, in: s).state
        #expect(redrawn.press == .idle)
        #expect(redrawn.hold.armed)

        let lost = run(pressed, .lost, in: s)
        #expect(!lost.state.hold.armed)
        #expect(lost.effects.contains(.stopHoldTimer))
    }

    // MARK: - Cargo

    /// ADR-0018's right-click rule, reused: the grabbed element carries the
    /// [[Effective selection]] when the selection covers it, and only itself
    /// otherwise.
    @Test func aDragCarriesTheSelectionThatCoversIt() throws {
        let s = try session()
        let both = Selection(["r", "b"])
        #expect(EditorCore.cargo(grabbing: "r", holding: both, in: s) == both.effective(in: s))
        #expect(both.effective(in: s).count == 2)
        #expect(EditorCore.cargo(grabbing: "r", holding: Selection(["b"]), in: s) == ["r"])
    }
}
