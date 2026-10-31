//
//  SelectionMenu.swift
//  EditorCore
//
//  What the diagram pane offers on a right-click once it holds a [[Selection]].
//  See ADR-0018.
//

import App
import VGraph

/// One element reproduces `menu(for:in:)` exactly and adds the grouping row,
/// which is what lets a right-click take a single path: make sure the pointed
/// element is covered — replacing the selection with it if not, as a plain click
/// would — then always build the menu from here.
///
/// Several elements offer only what applies to a set, there being no single
/// element for the rest to be about.
public func menu(
    forSelection selection: Selection,
    in session: some ForEditAGraphVisually,
    notationBreak: VNotationBreak = .forbidden
) -> [MenuItem] {
    let members = selection.effective(in: session)
    guard !members.isEmpty else { return [] }

    var result: [MenuItem] = []
    if members.count == 1 {
        result = menu(for: members[0], in: session, notationBreak: notationBreak)
        result.append(groupingItem(for: members, in: session))
        return result
    }
    result.append(groupingItem(for: members, in: session))
    result.append(deleteItem(for: members, in: session))
    return result
}

/// The title *is* the warning: one command is one [[Snapshot]], so ⌘Z undoes the
/// whole restructuring and a confirmation dialog would be a new interaction
/// primitive bought for nothing. ⌥ stays the [[Notation break]] key — no notation
/// forbids this, so reaching for it here would be a category error.
func groupingItem(
    for members: [String], in session: some ForEditAGraphVisually
) -> MenuItem {
    guard let target = session.groupingTarget(for: members) else {
        return MenuItem(
            id: .addGroup, title: "Group", availability: .notApplicable, enabled: false)
    }
    let title =
        target.detached == 0
        ? "Group"
        : "Group (moves \(target.detached) out of their boundaries)"
    return MenuItem(id: .addGroup, title: title, availability: .available, enabled: true)
}

/// Greyed for exactly what the command refuses: the [[Root group]], which the
/// document deletes rather than the graph (ADR-0016). No gesture can produce it,
/// since a click on blank canvas clears instead of selecting.
func deleteItem(
    for members: [String], in session: some ForEditAGraphVisually
) -> MenuItem {
    var deletable = !members.isEmpty
    for member in members where member == session.rootGroupId() { deletable = false }
    return MenuItem(
        id: .delete, title: "Delete",
        availability: deletable ? .available : .notApplicable, enabled: deletable)
}
