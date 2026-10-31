//
//  Views.swift
//  EditorCore
//
//  What the view picker and the View menu show. Pure functions over the port,
//  as Menu.swift is.
//

import App
import VGraph

public struct ViewOption: Sendable, Equatable {
    /// `nil` is the default view.
    public let name: String?
    public let title: String
    public let isSelected: Bool

    public init(name: String?, title: String, isSelected: Bool) {
        self.name = name
        self.title = title
        self.isSelected = isSelected
    }
}

/// "Default view" first, then each view by label, or by name where it has none.
public func viewOptions(in session: some ForEditAGraphVisually) -> [ViewOption] {
    let shown = session.activeView()
    var result = [ViewOption(name: nil, title: "Default view", isSelected: shown == nil)]
    for view in session.views() {
        result.append(
            ViewOption(name: view.name, title: view.label ?? view.name, isSelected: shown == view.name))
    }
    return result
}

/// The default view is the model: there is nothing of its own to duplicate,
/// rename or delete, so those rows are greyed there.
public func viewMenu(in session: some ForEditAGraphVisually) -> [MenuItem] {
    let inView = session.activeView() != nil
    let own: VAvailability = inView ? .available : .notApplicable
    return [
        MenuItem(id: .newView, title: "New view…", availability: .available, enabled: true),
        MenuItem(id: .duplicateView, title: "Duplicate view…", availability: own, enabled: inView),
        MenuItem(id: .renameView, title: "Rename view…", availability: own, enabled: inView),
        MenuItem(id: .deleteView, title: "Delete view", availability: own, enabled: inView),
    ]
}

public func shownView(in options: [ViewOption]) -> (name: String, title: String) {
    for option in options where option.isSelected {
        guard let name = option.name else { return ("", "") }
        return (name, option.title)
    }
    return ("", "")
}

public func statusLine(_ status: String, viewTitle: String) -> String {
    viewTitle.isEmpty ? status : "\(status) — View: \(viewTitle)"
}
