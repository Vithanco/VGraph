//
//  Zoom.swift
//  EditorCore
//
//  View state only. ADR-0003 makes the C4 *level* a fold state; this is the
//  separate question of how large that level is drawn.
//

import VGraph

public enum Zoom: Sendable, Equatable {
    case fit
    case fixed(Double)
}

extension Zoom {
    /// "Auto" rather than a number: fit follows the pane, so any figure shown
    /// would be stale after the next resize.
    public var label: String {
        switch self {
        case .fit: return "Auto"
        case .fixed(let scale): return zoomLabel(scale)
        }
    }
}

public enum ZoomDirection: Sendable {
    case `in`
    case out
}

public let zoomRange: ClosedRange<Double> = 0.1...4

private let zoomLadder: [Double] = [0.1, 0.25, 0.33, 0.5, 0.67, 0.75, 0.9, 1, 1.25, 1.5, 2, 3, 4]

public func zoomScale(_ zoom: Zoom, content: VSize, available: VSize) -> Double {
    switch zoom {
    case .fixed(let scale):
        return clamped(scale)
    case .fit:
        guard content.width > 0, content.height > 0, available.width > 0, available.height > 0
        else { return 1 }
        return clamped(min(1, available.width / content.width, available.height / content.height))
    }
}

public func zoomStepped(
    _ zoom: Zoom, _ direction: ZoomDirection, content: VSize, available: VSize
) -> Zoom {
    let shown = zoomScale(zoom, content: content, available: available)
    switch direction {
    case .in:
        return .fixed(zoomLadder.first { $0 > shown * 1.001 } ?? zoomRange.upperBound)
    case .out:
        return .fixed(zoomLadder.last { $0 < shown / 1.001 } ?? zoomRange.lowerBound)
    }
}

/// A trackpad pinch is many small wheel events and a mouse wheel a few big
/// ones, hence proportional and capped.
public func zoomWheeled(
    _ zoom: Zoom, deltaY: Double, content: VSize, available: VSize
) -> Zoom {
    let shown = zoomScale(zoom, content: content, available: available)
    let capped = max(-50, min(50, deltaY))
    return .fixed(clamped(shown * (1 - capped * 0.005)))
}

public func zoomLabel(_ scale: Double) -> String {
    "\(Int((scale * 100).rounded()))%"
}

/// `inset` is the container's padding, which does not scale with the content.
public func zoomedScroll(
    _ scroll: VPoint, keeping focal: VPoint, from old: Double, to new: Double, inset: Double
) -> VPoint {
    func axis(_ scroll: Double, _ focal: Double) -> Double {
        max(0, (scroll + focal - inset) / old * new + inset - focal)
    }
    return VPoint(x: axis(scroll.x, focal.x), y: axis(scroll.y, focal.y))
}

private func clamped(_ scale: Double) -> Double {
    max(zoomRange.lowerBound, min(zoomRange.upperBound, scale))
}
