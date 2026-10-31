//
//  ForManageADocument.swift
//  VGraph
//
//  Driving port: what the outside may do to the document as a whole. Declared
//  in the core and re-exported by App under its plain name, exactly as a driven
//  port is — see docs/hexagonal-architecture.md.
//

/// What the **toolbar** may do: the document as a whole, rather than either view
/// of it — load one, get its text out, move its [[History]].
///
/// The toolbar is an actor and not plumbing: the [[File menu]] and the undo
/// buttons are neither pane, and giving them a port is what stops history being
/// declared twice. Undo lives here because the stack is one, spanning
/// [[VCommand]]s and text edits alike (ADR-0006) — a ⌘Z in the text pane can
/// undo a [[Gesture]] made in the diagram, so a pane-local undo would
/// misdescribe what the stack contains. A pane wanting ⌘Z holds this port
/// alongside its own.
public protocol VForManageADocument {
    /// Load a **new document**, resetting history: undo can no longer cross back
    /// into what was open before. Contrast `ForEditVGL.textEdited(vgl:)`.
    func replaceDocument(vgl: String) throws(VError)

    /// The OriginGraph serialised back to VGL — what "Save VGL" writes.
    func exportVGL() throws(VError) -> String

    /// The VGL a rendered artefact carries, or `nil` if it carries none — what
    /// opening a [[Diagram as document]] reads before `replaceDocument(vgl:)`.
    ///
    /// Here and not on the diagram pane's port: the pane draws, and the toolbar
    /// is what opens things. The renderer that chose how to carry the text is
    /// the only thing that knows where to look, so this relays the question
    /// rather than answering it.
    func sourceVGL(from rendered: String) -> String?

    /// True when there is an earlier state to return to.
    var canUndo: Bool { get }
    /// True when a previously-undone state can be reapplied.
    var canRedo: Bool { get }

    /// Step back one state, returning the restored VGL (`nil` at the oldest).
    @discardableResult
    func undo() throws(VError) -> String?

    /// The inverse of `undo`. `nil` if already at the newest state.
    @discardableResult
    func redo() throws(VError) -> String?
}
