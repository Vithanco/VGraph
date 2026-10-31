//
//  RightClick.swift
//  EditorCore
//
//  What a right-click settles before a menu appears. Resolving the click to an
//  element is the browser's job — `closest` walks up from the exact shape under
//  the cursor and gets z-order and overlap right. What that walk *means* is
//  decided here.
//

import App
import VGraph

public struct RightClick: Sendable, Equatable {
    /// The [[Root group]] where the click missed everything — blank canvas is a
    /// menu target even though the renderer draws no element for it.
    public let target: String
    /// Returned rather than mutated: a right-click can change the [[Selection]],
    /// and applying that is the caller's.
    public let selection: Selection
    public let items: [MenuItem]
    /// False on the blank-canvas and edge paths, which address one element. The
    /// caller needs it because two commands mean something different when the
    /// menu came from a set (ADR-0018).
    public let fromSelection: Bool

    public init(target: String, selection: Selection, items: [MenuItem], fromSelection: Bool) {
        self.target = target
        self.selection = selection
        self.items = items
        self.fromSelection = fromSelection
    }
}

/// `hit` is `nil` where the click landed on blank canvas.
///
/// `nil` back means there is nothing to show, and the caller should leave the
/// browser's own menu alone rather than opening an empty one.
public func rightClick(
    on hit: String?, holding selection: Selection,
    in session: some ForEditAGraphVisually, notationBreak: VNotationBreak = .forbidden
) -> RightClick? {
    let target = hit ?? session.rootGroupId()

    // Blank canvas (the [[Root group]]) and edges both take the single-element
    // path and clear what was gathered, leaving no doubt about what the menu
    // acts on. Neither can be part of a [[Selection]].
    guard let hit, isSelectable(hit, in: session) else {
        let items = menu(for: target, in: session, notationBreak: notationBreak)
        guard !items.isEmpty else { return nil }
        return RightClick(
            target: target, selection: selection.cleared(), items: items, fromSelection: false)
    }

    // One rule for the rest: make sure the pointed element is covered, then
    // always build from the [[Effective selection]]. *Covered*, not *a member* —
    // a node inside a fully promoted group is already spoken for, and replacing
    // the selection with the bare node would undo the promotion (ADR-0018).
    let gathered =
        selection.covers(hit, in: session) ? selection : selection.replacing(with: hit)
    let items = menu(forSelection: gathered, in: session, notationBreak: notationBreak)
    guard !items.isEmpty else { return nil }
    return RightClick(
        target: target, selection: gathered, items: items, fromSelection: true)
}

/// An [[Edge bundle]] is not an element of the OriginGraph — it draws several —
/// so it has no menu of its own: it offers to unfold each folded group it runs
/// into, and nothing else (ADR-0027). `nil` when none of them is folded any more.
public func rightClickOnBundle(
    unfolding groupIds: [String], holding selection: Selection, in session: some ForEditAGraphVisually
) -> RightClick? {
    var items: [MenuItem] = []
    for id in groupIds where session.isFolded(id) {
        let availability = availability(of: .toggleFolding, on: id, in: session)
        items.append(
            MenuItem(
                id: .toggleFolding, title: "Unfold “\(session.label(of: id) ?? id)”",
                availability: availability, enabled: availability.isEnabled(under: .forbidden), target: id))
    }
    guard let first = items.first?.target else { return nil }
    return RightClick(target: first, selection: selection.cleared(), items: items, fromSelection: false)
}

/// What may join a [[Selection]]: nodes and groups, the two things a group can
/// be made of. An edge's group is derived from its endpoints (ADR-0017), so a
/// set command has nothing to do with one — and an unknown id names nothing.
public func isSelectable(_ id: String, in session: some ForEditAGraphVisually) -> Bool {
    guard let kind = session.kind(of: id) else { return false }
    return kind != .edge
}
