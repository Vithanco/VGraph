//
//  Keyboard.swift
//  EditorCore
//

public enum HistoryShortcut: Sendable, Equatable {
    case undo
    case redo
}

/// `command` is ⌘ or Ctrl.
public func historyShortcut(key: String, command: Bool, shift: Bool) -> HistoryShortcut? {
    guard command else { return nil }
    switch key.lowercased() {
    case "z": return shift ? .redo : .undo
    case "y": return .redo
    default: return nil
    }
}
