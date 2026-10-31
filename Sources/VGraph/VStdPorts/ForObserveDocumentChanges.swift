//
//  VForObserveDocumentChanges.swift
//  VGraph
//
//  Outbound port: how a GraphSession says its document moved.
//  Rationale: docs/adr/0013-driving-ports-and-named-commands.md.
//

/// Told that the document reached a new state, so the views over it can catch
/// up. The **Observer** to a [[GraphSession]]'s subject, and the one direction a
/// driving port cannot carry: a change made through one port has to reach the
/// components holding the other two.
///
/// Payload-free on purpose. The three readers want different things — the text
/// pane `exportVGL()`, the diagram `render(darkMode:)`, the toolbar
/// `canUndo`/`canRedo` — so anything carried would serve one of three. Each
/// pulls what it needs from the port it already holds; nothing caches, so
/// nothing can go stale.
///
/// **One observer, not a list.** `[any VForObserveDocumentChanges]` would hold a
/// port as an existential, which no port ever is. Telling several components is the
/// implementing adapter's job: it knows them concretely, which is what makes it
/// an adapter rather than a registry.
public protocol VForObserveDocumentChanges {
    /// The document is at a new state, and nothing more — see above on the
    /// missing payload. Called once the session has settled, so reading back
    /// through a driving port from here sees the new state.
    ///
    /// *When* it fires is pinned down by `DrivingPortsTest`: once per settled
    /// change, and not for an edit that parses to what was already there.
    func documentChanged()
}
