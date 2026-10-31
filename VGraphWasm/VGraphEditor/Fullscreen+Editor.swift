//
//  Fullscreen+Editor.swift
//  VGraphEditor
//
//  An editor on a page is only as big as its iframe. Fullscreen needs the
//  host's permission (a same-origin iframe has it by default); without it the
//  way out is a window of its own, with the document in the link as "Copy link"
//  carries it.
//

import JavaScriptKit

private var embedded: Bool {
    let global = JSObject.global
    guard let top = global.top.object, let window = global.window.object else { return false }
    return top != window
}

private var fullscreenAllowed: Bool {
    JSObject.global.document.fullscreenEnabled.boolean ?? false
}

/// A standalone page with no fullscreen has nothing to enlarge.
let canEnlarge = embedded || fullscreenAllowed

func enlarge() {
    guard let document = JSObject.global.document.object else { return }
    if document.fullscreenElement.object != nil {
        _ = document.exitFullscreen?()
    } else if fullscreenAllowed {
        _ = document.documentElement.object?.requestFullscreen?()
    } else if let link = shareLink() {
        _ = JSObject.global.open.function?(link, "_blank")
    }
}
