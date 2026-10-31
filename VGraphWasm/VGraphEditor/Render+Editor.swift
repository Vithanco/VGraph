//
//  Render+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

// MARK: - Diagnostics box

func renderDiagnostics(messages: [MessageWithSeverity], hardError: String?) {
    element(DOMId.diagnostics)?.innerHTML =
        EditorCore.diagnosticsHTML(messages, hardError: hardError).jsValue
}

// MARK: - Render loop

/// Render the session's current OriginGraph and inject the SVG into the
/// preview, surfacing the quality report in the diagnostics box. Does **not**
/// reparse — it renders whatever the session already holds (after a command,
/// or the loaded text). On a thrown (layout/render) error the last successful
/// SVG is left untouched — the box shows the failure (non-destructive).
func performRender() {
    // A render replaces the whole SVG, so any open inline editor is about to
    // lose the element it is anchored to. Close it and discard (ADR-0009) —
    // this is what removes the entire stale-overlay class of bug. A drag goes
    // the same way and for the same reason (ADR-0012).
    endInlineEdit()
    gestureRedrawn()
    // Tint the (non-ElementaryUI) preview background to match the theme so
    // the dark-palette SVG is legible.
    if let style = element(DOMId.preview)?.style.object {
        style.background = SemanticColor.page.resolve(darkMode: editorModel.darkMode).hexString.jsValue
    }
    guard let session = graphSession else { return }
    // Before the render, so a render that fails still shows the right view.
    refreshViews()
    do {
        let result = try session.render(darkMode: editorModel.darkMode)
        element(DOMId.preview)?.innerHTML = result.svg.jsValue
        lastRenderedSVG = result.svg
        // Before the halo: that measures the drawn boxes, so they must already
        // be at their final size.
        applyZoom()
        paintDetailsMarkers()
        // The SVG was just replaced, taking the halo with it. Re-derived
        // rather than preserved — having nothing to preserve is what lets it
        // live inside the SVG at all (ADR-0009 as amended, ADR-0018).
        selectionChanged()
        let report = result.qualityReport
        renderDiagnostics(messages: report.messages, hardError: nil)
        editorModel.status =
            report.isClean
            ? "Rendered OK"
            : "Rendered — \(report.errors.count) error(s), \(report.warnings.count) warning(s)"
        // Also re-injects after a non-text re-render (e.g. dark toggle).
        repaintHighlight(semantic: true, report: report)
        // Every change, whether typed or commanded, passes through here, so the
        // draft is never behind what is shown — the shown view included.
        saveDraft()
    } catch {
        // Typed throws: `error` is a VError. Keep the previous preview and
        // surface the failure in the diagnostics box.
        renderDiagnostics(messages: [], hardError: "\(error)")
        editorModel.status = "Render failed"
        repaintHighlight(semantic: true)  // marks the offending token
    }
}

/// Shared body of the two text→graph paths. On a parse failure `mutate` throws
/// before assigning, so the previous graph and preview stay intact and the
/// diagnostics box reports the failure.
private func mutateThenRender(_ mutate: (VGraphWasmSession) throws(VError) -> Void) {
    guard let session = graphSession else { return }
    do {
        try mutate(session)
        performRender()
        refreshHistoryFlags()
    } catch {
        renderDiagnostics(messages: [], hardError: "\(error)")
        editorModel.status = "Render failed"
        repaintHighlight(semantic: true)
    }
    // Both paths, because a document that does not parse *yet* is mid-thought —
    // and mid-thought is exactly what a reload should not eat. `mutate` throws
    // before the render on a parse failure, so hanging this off the render
    // would have saved everything except the state worth saving.
    saveDraft()
}

/// The text-edit path: fold `editorModel.vgl` into the current typing burst (a
/// coalesced undo step), not a document reset. See `textEdited(vgl:)`.
func reloadAndRender() {
    mutateThenRender { session throws(VError) in try session.textEdited(vgl: editorModel.vgl) }
}

/// Load `editorModel.vgl` as a **new document**, resetting undo history (host
/// push / example pick — see `replaceDocument(vgl:)`).
func loadDocumentAndRender() {
    mutateThenRender { session throws(VError) in try session.replaceDocument(vgl: editorModel.vgl) }
}

func refreshHistoryFlags() {
    editorModel.canUndo = graphSession?.canUndo ?? false
    editorModel.canRedo = graphSession?.canRedo ?? false
}

func performUndo() {
    guard let session = graphSession, let vgl = try? session.undo() else { return }
    syncSurface(to: vgl)
}

func performRedo() {
    guard let session = graphSession, let vgl = try? session.redo() else { return }
    syncSurface(to: vgl)
}

/// Renders nothing.
func showVGL(_ vgl: String) {
    editorModel.vgl = vgl
    setTextareaValue(vgl)
    repaintHighlight(semantic: false)
    autosizeTextarea()
}

/// For VGL the session already holds.
func syncSurface(to vgl: String) {
    showVGL(vgl)
    performRender()
    refreshHistoryFlags()
}

/// Debounce a render: coalesce a burst of keystrokes into one render 400 ms
/// after typing stops.
///
/// The debounce lives here in Swift; only the *time source* is host side. We
/// can't hand `setTimeout` a Swift `JSClosure` (it would never fire; see the
/// header of `Editor.swift`), so the timer invokes a *named JS function* instead: the host
/// stashes the `editorRenderNow` export as `window.__vgraphRenderNow` once at
/// boot, and `setTimeout` calls that wrapper directly. Without the hook (a
/// bare standalone page) the fallback renders synchronously.
func scheduleRender() {
    let global = JSObject.global
    guard global.__vgraphRenderNow.function != nil else {
        reloadAndRender()
        return
    }
    cancelScheduledRender()
    renderTimerHandle = global.setTimeout?(global.__vgraphRenderNow, 400) ?? .undefined
}

/// Drop any pending debounced render. `clearTimeout(undefined)` is a no-op,
/// so this is safe before the first `scheduleRender`.
func cancelScheduledRender() {
    _ = JSObject.global.clearTimeout?(renderTimerHandle)
    renderTimerHandle = .undefined
}

/// Write `text` into the textarea's live `.value` (a plain DOM property set,
/// no closure involved). Cancels the debounce: every caller renders explicitly
/// right after, so a queued one is stale — and it would close any open inline
/// editor when it fired (ADR-0009).
func setTextareaValue(_ text: String) {
    if let textarea = element(DOMId.source) {
        textarea.value = text.jsValue
    }
    cancelScheduledRender()
}

// MARK: - Syntax highlighting overlay

/// Repaint the `#vg-vgl-highlight` overlay. `semantic:false` is the instant
/// per-keystroke pass; `semantic:true` + `report` adds diagnostic markers.
func repaintHighlight(semantic: Bool, report: QualityReport? = nil) {
    let html = app.highlightHTML(editorModel.vgl, semantic: semantic, diagnostics: report)
    if let hl = element(DOMId.highlight) {
        hl.innerHTML = html.jsValue
    }
}

/// Grow the textarea to its content height so the wrapper is the *single*
/// scroller for both layers — keeps them aligned with no scroll listener.
func autosizeTextarea() {
    guard let ta = element(DOMId.source),
        let style = ta.style.object
    else { return }
    style.height = "auto".jsValue
    if let sh = ta.scrollHeight.number {
        style.height = "\(Int(sh))px".jsValue
    }
}

func updateHoverTitle(x: Double, y: Double) {
    let document = JSObject.global.document
    guard let textarea = element(DOMId.source) else { return }
    var title = ""
    // Call methods on JSValues (non-optional in JavaScriptKit), not JSObjects.
    let highlight = document.getElementById(DOMId.highlight)
    if highlight.object != nil {
        let markers = highlight.querySelectorAll(".vg-diag-error, .vg-diag-warn")
        if let count = markers.length.number {
            var i = 0
            while i < Int(count) {
                let node = markers.item(i)
                let rect = node.getBoundingClientRect()
                if let left = rect.left.number, let right = rect.right.number,
                    let top = rect.top.number, let bottom = rect.bottom.number,
                    x >= left, x <= right, y >= top, y <= bottom,
                    let hovered = node.getAttribute("title").string
                {
                    title = hovered
                    break
                }
                i += 1
            }
        }
    }
    textarea.title = title.jsValue
}

/// Focus the textarea after a command so the root keydown handler receives the
/// next Cmd-Z: a right-click otherwise leaves focus on `body`, whose keydown
/// does not bubble into the editor subtree.
func focusEditor() {
    _ = element(DOMId.source)?.focus?()
}
