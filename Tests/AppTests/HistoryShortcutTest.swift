//
//  HistoryShortcutTest.swift
//  VGraph
//
//  Which key chords mean undo and redo. ⌘ on a Mac and Ctrl elsewhere arrive
//  as one flag, because the editor cannot tell which platform convention the
//  user expects and both are unambiguous.
//

import EditorCore
import Testing

struct HistoryShortcutTest {
    @Test func commandZUndoes() {
        #expect(EditorCore.historyShortcut(key: "z", command: true, shift: false) == .undo)
    }

    /// The browser reports "Z" while ⇧ is held.
    @Test func commandShiftZRedoes() {
        #expect(EditorCore.historyShortcut(key: "Z", command: true, shift: true) == .redo)
        #expect(EditorCore.historyShortcut(key: "z", command: true, shift: true) == .redo)
    }

    @Test func commandYRedoes() {
        #expect(EditorCore.historyShortcut(key: "y", command: true, shift: false) == .redo)
        #expect(EditorCore.historyShortcut(key: "Y", command: true, shift: true) == .redo)
    }

    /// A bare letter is typing.
    @Test func withoutTheModifierNothingIsAShortcut() {
        #expect(EditorCore.historyShortcut(key: "z", command: false, shift: false) == nil)
        #expect(EditorCore.historyShortcut(key: "y", command: false, shift: false) == nil)
    }

    @Test func otherChordsAreLeftToTheBrowser() {
        #expect(EditorCore.historyShortcut(key: "c", command: true, shift: false) == nil)
        #expect(EditorCore.historyShortcut(key: "Escape", command: true, shift: false) == nil)
    }
}
