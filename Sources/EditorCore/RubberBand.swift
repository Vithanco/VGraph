//
//  RubberBand.swift
//  EditorCore
//
//  Bounds arrive already measured, and there is no `enclosed(by:)` on the port,
//  because a band catches what the user *sees*. A folded group's proxy node
//  carries shadow layers at +5 and +10 px that `NodeStyleLayout` sizes as
//  `VSize.zero` on purpose, so its drawn box is 10px larger than its laid-out
//  one — and folded groups are exactly what `catchable` singles out. Answering
//  from layout geometry would answer a different question, wrongly, for
//  precisely those elements.
//

import App
import VGraph

/// Bounds **as drawn**, in whatever coordinate space the caller measured them —
/// the band must be in the same one, and nothing here cares which.
public struct BandCandidate: Sendable, Equatable {
    public let id: String
    public let bounds: VRect

    public init(id: String, bounds: VRect) {
        self.id = id
        self.bounds = bounds
    }
}

/// In the order they were offered.
public func bandCatch(
    _ band: VRect, over candidates: [BandCandidate], in session: some ForEditAGraphVisually
) -> [String] {
    var caught: [String] = []
    for candidate in candidates
    where catchable(candidate.id, in: session) && encloses(band, candidate.bounds) {
        caught.append(candidate.id)
    }
    return caught
}

/// Only what is drawn as a single box: a node, or a folded group — which is one
/// thing at this zoom, [[Fold state]] deciding as ADR-0003 says.
///
/// An open boundary's interior belongs to the band and has to stay there, or
/// band-selecting inside one becomes impossible; the boundary itself arrives by
/// promotion instead (ADR-0018). An edge is not selectable at all (ADR-0017).
public func catchable(_ id: String, in session: some ForEditAGraphVisually) -> Bool {
    switch session.kind(of: id) {
    case .node: return true
    case .group: return session.isFolded(id)
    default: return false
    }
}

/// Nothing in a diagram is impossible to enclose, so forgiveness would only buy
/// accidental selection (ADR-0018).
private func encloses(_ band: VRect, _ bounds: VRect) -> Bool {
    bounds.x >= band.x && bounds.y >= band.y
        && bounds.x + bounds.width <= band.x + band.width
        && bounds.y + bounds.height <= band.y + band.height
}
