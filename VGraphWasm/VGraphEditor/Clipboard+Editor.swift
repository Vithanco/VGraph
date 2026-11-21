//
//  Clipboard+Editor.swift
//  VGraphEditor
//
//  Copy and paste as VGL. `EditorCore` decides who answers; this file
//  only reads focus and moves text between the clipboard and the session.
//

import App
import EditorCore
import JavaScriptKit
import VGraph

func handleCopy(_ event: RawClipboardEvent) {
    guard EditorCore.graphAnswers(.copy, focus: focus(), hasSelection: !selection.isEmpty),
        let text = selectionFragment()
    else { return }
    event.setText(text)
    event.preventDefault()
}

/// A refusal changes nothing and says nothing, as for every named command.
func handlePaste(_ event: RawClipboardEvent) {
    guard EditorCore.graphAnswers(.paste, focus: focus(), hasSelection: !selection.isEmpty) else { return }
    event.preventDefault()
    paste(event.text) { selection.pasteDestination(in: $0) }
}

/// Where the menu's Paste lands while the host reads the clipboard.
nonisolated(unsafe) private var pendingPaste: String? = nil

/// The host reads, because this build cannot await `readText`'s promise; its
/// answer comes back through `editorClipboardRead`.
func pasteFromMenu(into destination: String) {
    dismissMenu()
    pendingPaste = destination
    _ = JSObject.global.__vgraphReadClipboard.function?()
}

/// The host's answer to `__vgraphReadClipboard`, via the executable's
/// `editorClipboardRead` @JS wrapper.
public func editorClipboardRead(text: String) {
    guard let destination = pendingPaste else { return }
    pendingPaste = nil
    paste(text) { _ in destination }
}

private func paste(_ text: String, into destination: (VGraphWasmSession) -> String?) {
    var pasted: [String] = []
    runNamed { s throws(VError) in pasted = try s.paste(fragment: text, into: destination(s)) }
    guard !pasted.isEmpty else { return }
    selection = Selection(pasted)
    selectionChanged()
}

/// The menu has no `copy` event to answer, so it writes through the async API.
func copySelectionFromMenu() {
    dismissMenu()
    guard let text = selectionFragment() else { return }
    writeToClipboard(text, status: "Copied as VGL")
    focusEditor()
}

private func selectionFragment() -> String? {
    guard let session = sessionSyncedToText() else { return nil }
    return try? session.vglFragment(of: selection.effective(in: session))
}

private func focus() -> EditorFocus {
    JSObject.global.document.activeElement.object?.id.string == DOMId.preview ? .diagram : .text
}
