//
//  Keyboard+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// `preventDefault()` on a match so the textarea's native undo doesn't also
/// fire.
func handleKeyDown(_ event: RawKeyEvent) {
    guard !handleGestureKey(event) else { return }
    let shortcut = EditorCore.historyShortcut(
        key: event.key, command: event.metaKey || event.ctrlKey, shift: event.shiftKey)
    guard let shortcut else { return }
    event.preventDefault()
    switch shortcut {
    case .undo: performUndo()
    case .redo: performRedo()
    }
}

/// Merging this into `handleKeyDown` undoes twice — see `⌘Z still undoes once`.
func handleKeyUp(_ event: RawKeyEvent) {
    _ = handleGestureKey(event)
}
