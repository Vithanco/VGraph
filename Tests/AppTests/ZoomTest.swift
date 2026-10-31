//
//  ZoomTest.swift
//  VGraph
//

import EditorCore
import Testing
import VGraph

struct ZoomTest {
    private let content = VSize(width: 2000, height: 1000)

    @Test func fitShrinksTheDiagramToTheTighterAxis() {
        let scale = zoomScale(.fit, content: content, available: VSize(width: 1000, height: 800))
        #expect(scale == 0.5)
    }

    @Test func fitNeverEnlargesBeyondNaturalSize() {
        let scale = zoomScale(
            .fit, content: VSize(width: 200, height: 100), available: VSize(width: 1000, height: 800))
        #expect(scale == 1)
    }

    @Test func fitStopsAtTheFloorForAHugeDiagram() {
        let scale = zoomScale(
            .fit, content: VSize(width: 100_000, height: 100_000), available: VSize(width: 500, height: 500))
        #expect(scale == zoomRange.lowerBound)
    }

    @Test func fitOfAnEmptyPreviewIsNaturalSize() {
        #expect(zoomScale(.fit, content: .zero, available: VSize(width: 800, height: 600)) == 1)
        #expect(zoomScale(.fit, content: content, available: .zero) == 1)
    }

    @Test func aFixedZoomIgnoresThePaneAndIsClamped() {
        let pane = VSize(width: 10, height: 10)
        #expect(zoomScale(.fixed(1.5), content: content, available: pane) == 1.5)
        #expect(zoomScale(.fixed(99), content: content, available: pane) == zoomRange.upperBound)
        #expect(zoomScale(.fixed(0.001), content: content, available: pane) == zoomRange.lowerBound)
    }

    @Test func steppingFromFitStartsAtTheScaleShown() {
        let pane = VSize(width: 1000, height: 800)  // fit = 0.5
        #expect(zoomStepped(.fit, .in, content: content, available: pane) == .fixed(0.67))
        #expect(zoomStepped(.fit, .out, content: content, available: pane) == .fixed(0.33))
    }

    @Test func steppingWalksTheLadderAndStopsAtTheEnds() {
        let pane = VSize(width: 1000, height: 800)
        #expect(zoomStepped(.fixed(1), .in, content: content, available: pane) == .fixed(1.25))
        #expect(zoomStepped(.fixed(1), .out, content: content, available: pane) == .fixed(0.9))
        #expect(
            zoomStepped(.fixed(zoomRange.upperBound), .in, content: content, available: pane)
                == .fixed(zoomRange.upperBound))
        #expect(
            zoomStepped(.fixed(zoomRange.lowerBound), .out, content: content, available: pane)
                == .fixed(zoomRange.lowerBound))
    }

    @Test func steppingFromBetweenRungsGoesToTheNextOne() {
        let pane = VSize(width: 1000, height: 800)
        #expect(zoomStepped(.fixed(0.8), .in, content: content, available: pane) == .fixed(0.9))
        #expect(zoomStepped(.fixed(0.8), .out, content: content, available: pane) == .fixed(0.75))
    }

    @Test func wheelUpZoomsInAndWheelDownZoomsOut() {
        let pane = VSize(width: 1000, height: 800)
        guard case .fixed(let up) = zoomWheeled(.fixed(1), deltaY: -10, content: content, available: pane),
            case .fixed(let down) = zoomWheeled(.fixed(1), deltaY: 10, content: content, available: pane)
        else {
            Issue.record("a wheel always ends in a fixed zoom")
            return
        }
        #expect(up > 1)
        #expect(down < 1)
    }

    @Test func oneHugeWheelTickMovesNoMoreThanAQuarter() {
        let pane = VSize(width: 1000, height: 800)
        guard case .fixed(let scale) = zoomWheeled(.fixed(1), deltaY: -5000, content: content, available: pane)
        else {
            Issue.record("a wheel always ends in a fixed zoom")
            return
        }
        #expect(scale <= 1.25)
    }

    @Test func theLabelIsAWholePercentage() {
        #expect(zoomLabel(1) == "100%")
        #expect(zoomLabel(0.666) == "67%")
        #expect(zoomLabel(0.1) == "10%")
    }

    @Test func fitIsLabelledAutoAndAFixedZoomByItsPercentage() {
        #expect(Zoom.fit.label == "Auto")
        #expect(Zoom.fixed(1.25).label == "125%")
    }

    @Test func zoomingKeepsThePointUnderTheCursorStill() {
        // Cursor 100px into the pane, scrolled 300px, 8px inset: that is content
        // point (300+100-8)/1 = 392. At 2x it sits at 784+8 = 792, so the scroll
        // that leaves it 100px into the pane is 692.
        let scroll = zoomedScroll(
            VPoint(x: 300, y: 0), keeping: VPoint(x: 100, y: 50), from: 1, to: 2, inset: 8)
        #expect(scroll.x == 692)
        // Vertically: (0+50-8)*2 + 8 - 50 = 42.
        #expect(scroll.y == 42)
    }

    @Test func scrollNeverGoesNegative() {
        let scroll = zoomedScroll(
            VPoint(x: 0, y: 0), keeping: VPoint(x: 400, y: 400), from: 1, to: 0.25, inset: 8)
        #expect(scroll == .zero)
    }
}
