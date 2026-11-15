import App
import EditorCore
import JavaScriptKit
import VGraphSVG

/// Style guide §13.
private let chipHeight = 16.0
private let chipPadding = 6.0
private let chipInset = 6.0
/// DM Sans 10/700 runs about 6 px a character for `+` and digits; measuring in
/// the DOM would cost a layout per marker for a pixel of slack.
private let charWidth = 6.0

/// Into the live SVG after each patch, like the selection halo, and never into
/// `lastRenderedSVG`: a saved SVG stays a plain picture of the model.
func paintDetailsMarkers() {
    guard let session = graphSession,
        let preview = element(DOMId.preview),
        let list = preview.querySelectorAll?(".\(SVGElementId.foldedGroupClass)").object,
        let count = list.length.number
    else { return }
    // The boxes outlive a render now, so last render's markers are still in them.
    if let stale = preview.querySelectorAll?(".vg-details-marker").object,
        let staleCount = stale.length.number
    {
        for index in 0..<Int(staleCount) {
            _ = stale[index].object?.remove?()
        }
    }
    for index in 0..<Int(count) {
        guard let drawn = list[index].object,
            let domId = drawn.id.string,
            let id = SVGElementId.originId(fromDomId: domId),
            let text = EditorCore.detailsMarker(id, in: session),
            // Into the group that carries the box's position, and measured in
            // its coordinates: the box may be gliding to a new place, and a
            // marker beside it instead would be left where the glide began.
            let box = drawn.querySelector?(":scope > g").object,
            let bounds = box.getBBox?().object,
            let x = bounds.x.number, let y = bounds.y.number,
            let width = bounds.width.number, let height = bounds.height.number
        else { continue }
        let chipWidth = chipPadding * 2 + charWidth * Double(text.count)
        _ = box.insertAdjacentHTML?(
            "beforeend",
            detailsMarkerSVG(
                text, x: x + width - chipWidth - chipInset, y: y + height - chipHeight - chipInset,
                width: chipWidth))
    }
}

/// A count chip in the folded-group badge's language: how many details unfolding reveals.
private func detailsMarkerSVG(_ text: String, x: Double, y: Double, width: Double) -> String {
    let radius = chipHeight / 2
    return "<g class=\"vg-details-marker\">"
        + "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(chipHeight)\" rx=\"\(radius)\"/>"
        + "<text x=\"\(x + width / 2)\" y=\"\(y + radius)\" text-anchor=\"middle\" dominant-baseline=\"central\">"
        + text + "</text>"
        + "</g>"
}
