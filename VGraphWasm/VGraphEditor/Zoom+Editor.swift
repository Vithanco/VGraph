//
//  Zoom+Editor.swift
//  VGraphEditor
//
//  Fit is left to CSS rather than computed: an SVG with a viewBox and auto
//  size, capped by the pane and by its natural size, already fits and keeps
//  fitting as the window, the splitter or focus mode change it. Only a fixed
//  zoom needs a pixel size.
//

import EditorCore
import JavaScriptKit
import VGraph

/// Padding of `#vg-editor-preview`; it does not scale with the SVG.
private let previewInset = 8.0

func applyZoom() {
    guard let preview = element(DOMId.preview),
        let svg = preview.querySelector?("svg").object,
        let style = svg.style.object,
        let natural = naturalSize(of: svg)
    else { return }
    _ = svg.setAttribute?("preserveAspectRatio", "xMinYMin meet")
    switch editorModel.zoom {
    case .fit:
        style.width = "auto".jsValue
        style.height = "auto".jsValue
        style.maxWidth = "min(100%, \(natural.width)px)".jsValue
        style.maxHeight = "min(100%, \(natural.height)px)".jsValue
    case .fixed:
        let scale = zoomScale(editorModel.zoom, content: natural, available: .zero)
        style.width = "\(natural.width * scale)px".jsValue
        style.height = "\(natural.height * scale)px".jsValue
        style.maxWidth = "none".jsValue
        style.maxHeight = "none".jsValue
    }
}

/// The renderer sets width and height to the viewBox's, so they are the
/// natural size.
private func naturalSize(of svg: JSObject) -> VSize? {
    guard let box = svg.viewBox.object?.baseVal.object,
        let width = box.width.number, let height = box.height.number,
        width > 0, height > 0
    else { return nil }
    return VSize(width: width, height: height)
}

private func paneSize(_ preview: JSObject) -> VSize {
    VSize(
        width: (preview.clientWidth.number ?? 0) - 2 * previewInset,
        height: (preview.clientHeight.number ?? 0) - 2 * previewInset)
}

func zoomStep(_ direction: ZoomDirection) {
    guard let preview = element(DOMId.preview),
        let svg = preview.querySelector?("svg").object,
        let natural = naturalSize(of: svg)
    else { return }
    let pane = paneSize(preview)
    setZoom(
        zoomStepped(editorModel.zoom, direction, content: natural, available: pane),
        keeping: VPoint(
            x: (preview.clientWidth.number ?? 0) / 2, y: (preview.clientHeight.number ?? 0) / 2))
}

func handleWheel(_ event: RawWheelEvent) {
    guard event.zooms,
        let preview = element(DOMId.preview),
        let svg = preview.querySelector?("svg").object,
        let natural = naturalSize(of: svg),
        let rect = preview.getBoundingClientRect?().object,
        let left = rect.left.number, let top = rect.top.number
    else { return }
    event.preventDefault()
    let focal = VPoint(
        x: event.clientX - left - (preview.clientLeft.number ?? 0),
        y: event.clientY - top - (preview.clientTop.number ?? 0))
    setZoom(
        zoomWheeled(
            editorModel.zoom, deltaY: event.deltaY, content: natural, available: paneSize(preview)),
        keeping: focal)
}

func setZoom(_ zoom: Zoom, keeping focal: VPoint? = nil) {
    guard let preview = element(DOMId.preview),
        let svg = preview.querySelector?("svg").object,
        let natural = naturalSize(of: svg)
    else {
        editorModel.zoom = zoom
        return
    }
    let pane = paneSize(preview)
    let before = zoomScale(editorModel.zoom, content: natural, available: pane)
    let after = zoomScale(zoom, content: natural, available: pane)
    editorModel.zoom = zoom
    applyZoom()
    guard let focal else { return }
    let scroll = zoomedScroll(
        VPoint(x: preview.scrollLeft.number ?? 0, y: preview.scrollTop.number ?? 0),
        keeping: focal, from: before, to: after, inset: previewInset)
    preview.scrollLeft = scroll.x.jsValue
    preview.scrollTop = scroll.y.jsValue
}

func toggleDisplayPanel() {
    editorModel.displayMenuAt = toggledRightAlignedMenu(editorModel.displayMenuAt, under: DOMId.displayButton)
}
