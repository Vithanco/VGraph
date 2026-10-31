//
//  Selection.swift
//  EditorCore
//
//  What the user has gathered in the diagram, so that the next command has its
//  arguments. Adapter state: the document never hears about it, and neither
//  does the graph. See ADR-0018.
//

import App
import VGraph

/// The elements a [[Rubber band]] or a ⇧-click has gathered.
///
/// Held here rather than on `GraphSession` for one reason above the others: a
/// selection must never become an undo step, and a session that is never told
/// cannot record it. Held here rather than loose in the editor for another —
/// every rule about it is then a unit test instead of a browser one.
///
/// `ids` is what the user touched, literally; what a command receives is
/// `effective(in:)`.
public struct Selection: Sendable, Equatable {
    public let ids: [String]

    public init(_ ids: [String] = []) {
        self.ids = ids
    }

    public var isEmpty: Bool { ids.isEmpty }

    public func replacing(with id: String) -> Selection {
        Selection([id])
    }

    /// Invertible by construction, which is what stops promotion from being a
    /// one-way door.
    public func toggling(_ id: String) -> Selection {
        if ids.contains(id) {
            var kept: [String] = []
            for existing in ids where existing != id { kept.append(existing) }
            return Selection(kept)
        }
        return Selection(ids + [id])
    }

    public func adding(_ others: [String]) -> Selection {
        var result = ids
        for id in others where !result.contains(id) { result.append(id) }
        return Selection(result)
    }

    public func cleared() -> Selection {
        Selection()
    }

    /// Called lazily rather than on every change: a parse failure is
    /// non-destructive, so the session always answers against a valid graph, and a
    /// node does not flicker out of the selection while its name is half-typed.
    public func pruned(in session: some ForEditAGraphVisually) -> Selection {
        var kept: [String] = []
        for id in ids where session.kind(of: id) != nil { kept.append(id) }
        return Selection(kept)
    }

    /// The [[Effective selection]]: what a command receives, and what the diagram
    /// highlights, since anything else would misreport the outcome.
    ///
    /// Derived, never stored — written back into `ids` instead, a ⇧-click that
    /// promoted to a group would have nothing left to remove on the way out.
    public func effective(in session: some ForEditAGraphVisually) -> [String] {
        session.outermostElements(of: ids)
    }

    /// Whether this element — or any group holding it — is already selected. What
    /// a right-click tests before replacing the selection (ADR-0018).
    ///
    /// Answered without any ancestry query on the port: adding a covered element
    /// cannot change what the set collapses to, and adding an uncovered one
    /// always can. The canonical form answers a question about a tree the pane is
    /// not allowed to walk.
    public func covers(_ id: String, in session: some ForEditAGraphVisually) -> Bool {
        let current = effective(in: session)
        guard !current.isEmpty else { return false }
        if current.contains(id) { return true }
        return session.outermostElements(of: ids + [id]) == current
    }
}
