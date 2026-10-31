// Outbound port: where a GraphSession's version history lives.
// Rationale and the git mapping: docs/adr/0007-document-versions-port.md.

/// Identifies one recorded version. Monotonic and never reused, including by
/// versions a divergence abandons.
public struct VersionRef: Hashable, Sendable {
    public let number: Int

    public init(number: Int) {
        self.number = number
    }
}

/// Where a [[GraphSession]]'s document history is stored: versions are VGL
/// strings, each with at most one parent.
///
/// Linear at the API level while the data model stays DAG-shaped, so an adapter
/// may keep more than this exposes — after an undo a stack drops the abandoned
/// descendants where git may branch and keep them, and both satisfy this port.
///
/// A generic parameter on `GraphSession`, never `any VForStoreDocumentVersions`
/// — every port is, by choice (docs/hexagonal-architecture.md).
public protocol VForStoreDocumentVersions {
    /// Start a fresh history rooted at `vgl`, discarding any previous document.
    mutating func reset(vgl: String) throws(VError)

    /// Record `vgl` as a new child of `current`, which moves to it.
    /// Maps to `git commit`.
    @discardableResult
    mutating func record(vgl: String) throws(VError) -> VersionRef

    /// Replace `current`'s content in place, keeping its identity and parent —
    /// how a typing burst collapses into one step. Maps to `git commit --amend`.
    mutating func amend(vgl: String) throws(VError)

    var current: VersionRef { get }

    /// `nil` once the adapter no longer holds `ref` (e.g. dropped past a
    /// bounded adapter's depth cap).
    func vgl(of ref: VersionRef) -> String?

    func parent(of ref: VersionRef) -> VersionRef?
    func children(of ref: VersionRef) -> [VersionRef]

    var canUndo: Bool { get }
    var canRedo: Bool { get }

    /// Move `current` to its parent. `nil` (and no move) at the root.
    @discardableResult
    mutating func undo() throws(VError) -> VersionRef?

    /// The inverse of `undo`. `nil` (and no move) at the newest version.
    @discardableResult
    mutating func redo() throws(VError) -> VersionRef?
}
