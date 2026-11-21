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
    let text = event.text
    var pasted: [String] = []
    runNamed { s throws(VError) in pasted = try s.paste(fragment: text, into: selection.pasteDestination(in: s)) }
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
