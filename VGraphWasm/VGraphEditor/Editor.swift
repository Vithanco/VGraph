// VGraphEditor — minimal ElementaryUI-based interactive VGL editor.
//
// This target owns the editor UI. It is wasi-only (ElementaryUI + JavaScriptKit
// are wasi-conditioned in Package.swift). The VGraphWasm executable's @JS
// wrappers call the public functions in this file; everything else lives in a
// sibling file per feature.
//
// Design notes:
//   * ElementaryUI manages the whole tree, but the SVG preview, the highlight
//     layer, the textarea and the diagnostics box are all kept childless in
//     ElementaryUI terms and filled with `innerHTML` via JavaScriptKit. That
//     sidesteps ElementaryUI's lack of a raw-HTML view and keeps the reconciler
//     off the caret and the injected markup.
//   * Shared state lives in a module-global `@Reactive` model so `setEditorVGL`
//     can push VGL in from the host and the view re-renders reactively.
//
// IMPORTANT — no JavaScriptKit `JSClosure`:
//   All interactivity goes through ElementaryUI's own event/lifecycle system
//   (`.onInput`, `.onClick`, `.onAppear`), which is implemented on top of
//   BridgeJS/BrowserInterop closures. JavaScriptKit's `JSClosure` cannot be
//   *invoked* in this embedded build: its `swjs_call_host_function` /
//   `swjs_free_host_function` entry points are `@_expose(wasm, ...)` inside the
//   JavaScriptKit dependency, and a dependency library's `@_expose` exports get
//   dead-stripped by the linker (only the root executable target's survive).
//   Creating a `JSClosure` succeeds but calling it from JS is a no-op, so
//   `addEventListener`/`setTimeout` callbacks written *in Swift* as `JSClosure`
//   never fire. Non-closure JavaScriptKit calls (property get/set, method calls
//   like `getElementById`, `innerHTML`, calling a named global JS function) work
//   fine and are used for SVG injection, value seeding, and `scheduleRender`.
//   Only the JS→Swift *closure* path is broken; JS→Swift *named exports* and
//   Swift→JS *named calls* both work, which is what `scheduleRender` and
//   `armLongPress` are built on — both borrow the host's clock through a global
//   the host binds to a `@JS` export.
//
// Input is Pointer Events, not mouse events, so a finger and a pen drive the same
// gestures a mouse does (ADR-0018). What touch still cannot reach is listed there.

import App
import EditorCore
import ElementaryUI
import JavaScriptKit
import Reactivity
import VGraph
import VGraphSVG

// MARK: - Public entry points (called from the executable's @JS wrappers)

/// Build the editor DOM under `elementId` and mount the ElementaryUI app.
public func mountEditor(elementId: String) {
    let document = JSObject.global.document

    guard let root = document.getElementById(elementId).object else {
        return
    }

    // Build the live session over the initial VGL. It owns the OriginGraph
    // (source of truth); commands mutate it in place, text edits reparse it.
    graphSession = try? app.makeSession(vgl: editorModel.vgl)

    // Inject the editor stylesheet once, into <head> — out of the
    // ElementaryUI-managed tree so the reconciler never touches it.
    if element(DOMId.stylesheet) == nil,
        let style = document.createElement("style").object
    {
        style.id = DOMId.stylesheet.jsValue
        style.textContent = editorStyleCSS.jsValue
        _ = document.head.object?.appendChild?(style)
    }

    // Mount at the root, not just the controls column: that is what puts the
    // SVG preview inside the managed tree, where its `.onContextMenu` fires
    // (a Swift-authored addEventListener never would; see the header of `Editor.swift`).
    root.innerHTML = "".jsValue
    _ = Application(EditorView()).mount(
        in: DOMElementSelector(stringLiteral: "#\(elementId)"))

    // Embedding contract: `?vgl=<encoded VGL>` seeds the editor, and `#vgl=`
    // does the same from the fragment (what "Copy link" mints). Read here rather
    // than in host glue so every embedding host honours it.
    let search = JSObject.global.location.search.string ?? ""
    let params = JSObject.global.URLSearchParams.function?.new(search)
    let urlVGL = params?.get?("vgl").string ?? hashVGL()
    // `?src=` is fetched by the host after mount. The document is not here yet,
    // but it is spoken for — so no draft may take the screen in the meantime.
    let awaitsFetch = !((params?.get?("src").string ?? "").isEmpty)

    // Read before `setEditorVGL`, whose render writes the draft back.
    let draftView = draftStore?.readView?().string ?? ""
    let opening = EditorCore.documentToOpen(
        urlDocument: urlVGL, urlAwaitsFetch: awaitsFetch,
        draft: storedDraft(), fallback: defaultVGL)

    if opening.vgl != editorModel.vgl {
        setEditorVGL(text: opening.vgl)
    }
    if opening.restoredDraft {
        if let store = draftStore, let name = store.readName?().string, !name.isEmpty {
            documentBaseName = name
        }
        draftWasRestored = true
        pendingDraftView = draftView
    }
}

/// Push VGL into the editor from the host (initial content / updates).
public func setEditorVGL(text: String) {
    showVGL(text)
    loadDocumentAndRender()  // host-pushed text → new document, fresh history
}

/// The debounced text-edit render, invoked by the host timer (see
/// `scheduleRender`) via the executable's `editorRenderNow` @JS wrapper.
/// Reparses the current textarea VGL into the OriginGraph, then renders.
public func editorRenderNow() {
    reloadAndRender()
}

/// The long-press timer, invoked by the host the same way (see `armLongPress`)
/// via the executable's `editorLongPressFired` @JS wrapper.
public func editorLongPressFired() {
    holdElapsed()
}

/// Load a document the *host* fetched — the `?src=` path. The same
/// decision a picked file gets, minus the `<input>`: what the bytes are read as
/// is `EditorCore`'s to say, and asking it here is what keeps a `.vithanco.svg`
/// arriving by URL indistinguishable from one arriving by the file picker.
///
/// Reports whether the document loaded, so a host that fetched it from another
/// site can name that origin without overwriting a refusal.
@discardableResult
public func openEditorDocument(text: String, named name: String) -> Bool {
    // Without a session there is nothing to ask what the file carries, and
    // `opened` would then read a diagram VGraph itself wrote as "not ours".
    // `makeSession` is `try?` at mount, so this is reachable: better to report
    // the editor's state than to blame the user's file.
    guard let session = graphSession else {
        editorModel.status = "Cannot open \(name) — the editor has no document loaded"
        return false
    }
    // Asked of the port rather than of `SVGBuilder` — see `sourceVGL(from:)`.
    switch EditorCore.opened(text, named: name, embeddedVGL: session.sourceVGL(from: text)) {
    case .refused(let why):
        editorModel.status = why
        return false
    case .vgl(let vgl):
        documentBaseName = EditorCore.documentName(fromFile: name)
        setEditorVGL(text: vgl)
        return true
    }
}

/// Let the host say what only it can see — a fetch that 404'd, a source it
/// refused — in the line the user already reads for trouble. Call it *after*
/// `openEditorDocument`: loading a document ends by reporting its own render.
public func setEditorStatus(text: String) {
    editorModel.status = text
}
