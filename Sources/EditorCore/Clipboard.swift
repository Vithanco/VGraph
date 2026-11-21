//
//  Clipboard.swift
//  EditorCore
//
//  Who answers ⌘C and ⌘V: the graph, or the browser. Focus decides, so the
//  source pane's own copy and paste are never taken over.
//

import App
import VGraph

public enum ClipboardEvent: Sendable, Equatable {
    case copy
    case paste
}

public enum EditorFocus: Sendable, Equatable {
    case diagram
    case text
}

public func graphAnswers(_ event: ClipboardEvent, focus: EditorFocus, hasSelection: Bool) -> Bool {
    guard focus == .diagram else { return false }
    switch event {
    case .copy: return hasSelection
    case .paste: return true
    }
}

extension Selection {
    public func pasteDestination(in session: some ForEditAGraphVisually) -> String? {
        let members = effective(in: session)
        guard members.count == 1, session.kind(of: members[0]) == .group else { return nil }
        return members[0]
    }
}
