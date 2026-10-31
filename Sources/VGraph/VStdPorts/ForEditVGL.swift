//
//  ForEditVGL.swift
//  VGraph
//
//  Driving port: what the outside may do to a document's text. Declared in the
//  core and re-exported by App under its plain name, exactly as a driven port
//  is — see docs/hexagonal-architecture.md.
//

/// What the **text pane** may do: put VGL in, and colour it. That it offers no
/// way to render, command or undo is the point of there being three ports, and
/// is checked by `ArchitectureTest.drivingPortSurfacesAreDisjoint`.
///
/// Both methods are written from the pane's side of the boundary — it reports
/// what happened to its text and never names the [[Text-edit run]], which is the
/// session's machinery for turning those reports into undo steps.
public protocol VForEditVGL {
    /// The pane's text is now `vgl`. A continuous burst of these collapses into
    /// a single undo step until `textEditingEnded()`.
    ///
    /// Throws on a parse failure, which is ordinary mid-edit and not a veto: the
    /// document stays where it was, the pane keeps showing what the user typed,
    /// and the last good graph stays on screen (see [[Live preview]]).
    func textEdited(vgl: String) throws(VError)

    /// The burst is over — in the WASM editor, focus left the textarea. The next
    /// `textEdited(vgl:)` starts a fresh undo step instead of amending the last.
    ///
    /// Only blur needs to say this: a [[VCommand]], a document load and an
    /// undo/redo all end a burst on their own.
    func textEditingEnded()

    /// Highlight HTML for the pane's overlay. Takes the source rather than
    /// reading the document, because the per-keystroke pass runs on text that
    /// has not reached `textEdited(vgl:)` yet — and may not parse.
    func highlightHTML(_ input: String, semantic: Bool, diagnostics: QualityReport?) -> String
}
