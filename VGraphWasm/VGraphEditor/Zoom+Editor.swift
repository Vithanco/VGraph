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
import VGraphSVG

/// Padding of `#vg-editor-preview`; it does not scale with the SVG.
private let previewInset = 8.0

/// For a zoom change, which has to take effect before the scroll that keeps
/// the focal point is worked out. A redraw needs none of this: the drawing's
/// own view styles its `<svg>` (`Drawing`), from the same `zoomStyle`.
func applyZoom() {
    guard let preview = element(DOMId.preview),
        let svg = preview.querySelector?("svg").object,
        let natural = naturalSize()
    else { return }
    _ = svg.setAttribute?("style", zoomStyle(editorModel.zoom, natural: natural))
}

/// Run `measure` with the drawing in the frame it is easing *to*.
///
/// A redraw eases the frame over `glideSeconds`, so what is measured meanwhile
/// is on its way somewhere else — and an overlay placed by it would be left
/// behind. The frame is put back before returning, in the same task, so nothing
/// in between is ever painted.
func measuringAtRest(_ measure: () -> Void) {
    guard let svg = element(DOMId.preview)?.querySelector?("svg").object,
        let drawing = editorModel.drawing,
        case .element(.svg, let attributes, _) = drawing,
        let natural = naturalSize()
    else {
        measure()
        return
    }
    let rest =
        attributes.filter { $0.name == "viewBox" || $0.name == "width" || $0.name == "height" }
        + [VSVGAttribute("style", zoomStyle(editorModel.zoom, natural: natural))]
    let inFlight = rest.map { svg.getAttribute?($0.name).string }
    for attribute in rest {
        _ = svg.setAttribute?(attribute.name, attribute.value)
    }
    measure()
    for (attribute, value) in zip(rest, inFlight) {
        if let value {
            _ = svg.setAttribute?(attribute.name, value)
        } else {
            _ = svg.removeAttribute?(attribute.name)
        }
    }
}

/// Of the drawing being shown, read from the model rather than the DOM, whose
/// `viewBox` may still be easing towards it.
private func naturalSize() -> VSize? {
    guard let drawing = editorModel.drawing, let frame = mountedFrame(of: drawing),
        frame.width > 0, frame.height > 0
    else { return nil }
    return frame.size
}

private func paneSize(_ preview: JSObject) -> VSize {
    VSize(
        width: (preview.clientWidth.number ?? 0) - 2 * previewInset,
        height: (preview.clientHeight.number ?? 0) - 2 * previewInset)
}

func zoomStep(_ direction: ZoomDirection) {
    guard let preview = element(DOMId.preview), let natural = naturalSize() else { return }
    let pane = paneSize(preview)
    setZoom(
        zoomStepped(editorModel.zoom, direction, content: natural, available: pane),
        keeping: VPoint(
            x: (preview.clientWidth.number ?? 0) / 2, y: (preview.clientHeight.number ?? 0) / 2))
}

func handleWheel(_ event: RawWheelEvent) {
    guard event.zooms,
        let preview = element(DOMId.preview),
        let natural = naturalSize(),
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
    guard let preview = element(DOMId.preview), let natural = naturalSize() else {
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
