//
//  DOM.swift
//  VGraphEditor
//

import JavaScriptKit
import VGraph

/// The browser tests select by the same strings.
enum DOMId {
    static let preview = "vg-editor-preview"
    static let diagnostics = "vg-editor-diagnostics"
    static let diagnosticsHead = "vg-editor-diagnostics-head"
    static let dragOverlay = "vg-drag-overlay"
    static let source = "vg-vgl-input"
    static let sourceWrap = "vg-vgl-input-wrap"
    static let highlight = "vg-vgl-highlight"
    static let status = "vg-editor-status"
    static let controls = "vg-editor-controls"
    static let examples = "vg-examples"
    static let displayButton = "vg-display-button"
    static let displayPanel = "vg-display-panel"
    static let sourceToggle = "vg-source-toggle"
    static let enlarge = "vg-fullscreen"
    static let undo = "vg-undo"
    static let redo = "vg-redo"
    static let viewMenuButton = "vg-view-menu"
    static let viewMenuPanel = "vg-view-menu-panel"
    static let fileMenuButton = "vg-file-menu"
    static let fileMenuPanel = "vg-file-menu-panel"
    static let fileInput = "vg-file-input"
    static let promptInput = "vg-ctx-input"
    static let inlineEdit = "vg-inline-edit"
    static let stylesheet = "vg-editor-style"
}

/// Looked up on demand rather than cached: the tree is created by the
/// ElementaryUI mount, so a value stashed at boot could predate it.
/// `getElementById` is cheap.
func element(_ id: String) -> JSObject? {
    JSObject.global.document.getElementById(id).object
}

/// Measured rather than hard-coded, so the panel stays under its button when the
/// bar reflows. No need to close the context menu first: its dismiss layer
/// covers the viewport, so the click that closes it never reaches the button.
func toggledMenu(_ current: VPoint?, under buttonId: String) -> VPoint? {
    guard current == nil else { return nil }
    guard let rect = element(buttonId)?.getBoundingClientRect?().object,
        let left = rect.left.number, let bottom = rect.bottom.number
    else { return .zero }
    return VPoint(x: left, y: bottom + 4)
}

func toggledRightAlignedMenu(_ current: VPoint?, under buttonId: String) -> VPoint? {
    guard current == nil else { return nil }
    guard let rect = element(buttonId)?.getBoundingClientRect?().object,
        let right = rect.right.number, let bottom = rect.bottom.number
    else { return .zero }
    return VPoint(x: right, y: bottom + 4)
}

func dropdownPositionStyle(_ at: VPoint?) -> String {
    let at = at ?? .zero
    return "left:\(Int(at.x))px;top:\(Int(at.y))px;"
}

/// Anchored by its right edge: a panel under the bar's last button would
/// otherwise run off the window.
func rightAlignedPositionStyle(_ at: VPoint?) -> String {
    let at = at ?? .zero
    let width = JSObject.global.innerWidth.number ?? 0
    return "right:\(Int(max(0, width - at.x)))px;top:\(Int(at.y))px;"
}
