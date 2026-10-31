//
//  Document+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

// MARK: - File menu

/// Trigger a browser download of `text`, entirely from Swift — it needs no
/// `JSClosure`, so no host helper. Uses a `data:` URL rather than
/// `Blob`/`URL.createObjectURL` to lean only on the idioms this file already
/// exercises.
func downloadText(_ text: String, as filename: String, mime: String) {
    let global = JSObject.global
    // encodeURIComponent keeps `#`, `&`, `+` etc. intact inside the data URL.
    guard let encoded = global.encodeURIComponent?(text.jsValue).string else { return }
    let href = "data:\(mime);charset=utf-8," + encoded
    guard let anchor = global.document.createElement("a").object else { return }
    anchor.href = href.jsValue
    anchor.download = filename.jsValue
    _ = global.document.body.object?.appendChild?(anchor)
    _ = anchor.click?()
    _ = anchor.remove?()
}

// MARK: - Draft and share link

/// The browser's per-site notepad on *this* device, reached through the host
/// page rather than directly: `localStorage` throws outright where site data is
/// switched off, and this build cannot catch a JS exception. A host without the
/// object gets no autosave, which is why every call checks.
var draftStore: JSObject? { JSObject.global.__vgraphDraft.object }

/// Called after every render, so the draft is never more than a debounce behind
/// what is on screen. Cheap: a few KB of text into a synchronous store.
func saveDraft() {
    guard let store = draftStore else { return }
    _ = store.write?(
        editorModel.vgl.jsValue, documentBaseName.jsValue, editorModel.shownView.jsValue)
}

func storedDraft() -> String? {
    guard let store = draftStore, let text = store.read?().string, !text.isEmpty else {
        return nil
    }
    return text
}

/// A link that carries the diagram itself, for a document that exists nowhere
/// else — the case `?src=` cannot serve, because there is no file to point at.
///
/// The VGL goes in the *fragment*, after `#`, which the browser keeps to itself:
/// it is never sent to the server, so it escapes the ~8KB request-line cap that
/// makes `?vgl=` unable to carry a larger diagram at all, and it stays out of
/// access logs on the way.
func shareLink() -> String? {
    let global = JSObject.global
    guard let encoded = global.encodeURIComponent?(editorModel.vgl.jsValue).string else { return nil }
    let origin = global.location.origin.string ?? ""
    let path = global.location.pathname.string ?? ""
    return origin + path + "#vgl=" + encoded
}

func copyShareLink() {
    guard let link = shareLink() else { return }

    // `writeText` hands back a promise this build cannot await, so a refusal —
    // no permission, no secure context — is invisible to us. Saying "copied"
    // when it was not is the one failure here, and it costs the user a retry.
    _ = JSObject.global.navigator.clipboard.object?.writeText?(link.jsValue)
    editorModel.status = "Link copied — the diagram travels inside it"
}

/// VGL the URL carried after `#`. `URLSearchParams` parses the fragment's body
/// exactly as it parses a query, so `#vgl=…` needs no second decoder.
func hashVGL() -> String? {
    guard let hash = JSObject.global.location.hash.string, hash.count > 1 else { return nil }
    let body = String(hash.dropFirst())
    guard let params = JSObject.global.URLSearchParams.function?.new(body),
        let vgl = params.get?("vgl").string, !vgl.isEmpty
    else { return nil }
    return vgl
}

/// `.vithanco.svg` rather than `.svg` because every render carries its VGL in
/// the SVG's `<metadata>` (see `GraphSession.render`): the double extension
/// says "document, not picture" while staying an ordinary SVG to every other
/// tool.
func saveSVG() {
    guard !lastRenderedSVG.isEmpty else { return }
    downloadText(lastRenderedSVG, as: documentBaseName + ".vithanco.svg", mime: "image/svg+xml")
}

/// The *textarea's* VGL, not the re-exported graph — what the user sees is
/// what lands in the file.
func saveVGL() {
    downloadText(editorModel.vgl, as: documentBaseName + ".vgl", mime: "text/plain")
}

/// Must be called straight from the menu item's click handler, so the click
/// on the hidden input still rides the user gesture — a picker opened later
/// is blocked by the browser, and no test can catch that (Playwright's
/// `setInputFiles` never opens one).
func openFile() {
    _ = element(DOMId.fileInput)?.click?()
}

func handleFilePicked() {
    guard let input = element(DOMId.fileInput),
        let file = input.files.item(0).object
    else { return }
    let name = file.name.string ?? ""
    // Clear the input so re-picking the *same* file fires `change` again.
    // Untestable here: `setInputFiles` assigns the files outright, so the
    // harness fires `change` whether or not this line is there.
    input.value = "".jsValue

    guard let text = readFileText(file) else {
        editorModel.status = "Could not read \(name)"
        return
    }
    openEditorDocument(text: text, named: name)
}

/// Read a `File` **synchronously**, via a blob URL and a synchronous
/// `XMLHttpRequest`.
///
/// The obvious readers — `FileReader`, `file.text()` — both hand their result
/// back through a *callback*, and a Swift `JSClosure` cannot be invoked in
/// this embedded build (see the header of `Editor.swift`). Rather than reintroduce host
/// glue for the one asynchronous step in the editor, this leans on the only
/// file-read API that returns its value inline. Synchronous XHR is deprecated
/// for network requests; against a `blob:` URL it touches no network and
/// blocks only for the memcpy.
private func readFileText(_ file: JSObject) -> String? {
    let global = JSObject.global
    let url = global.URL.createObjectURL(file.jsValue)
    defer { _ = global.URL.revokeObjectURL(url) }
    guard let constructor = global.XMLHttpRequest.function else { return nil }
    let request = constructor.new()
    _ = request.open?("GET".jsValue, url, false.jsValue)  // false → synchronous
    _ = request.send?()
    return request.responseText.string
}

func toggleFileMenu() {
    editorModel.fileMenuAt = toggledMenu(editorModel.fileMenuAt, under: DOMId.fileMenuButton)
}
