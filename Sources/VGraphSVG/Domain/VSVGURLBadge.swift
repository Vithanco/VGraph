// Geometry note for anyone tidying below: `d` interpolates `Double` directly
// rather than going through `SVGBuilder.format`, and the snapshots record that.

import VGraph

enum VSVGURLBadge {

    /// Half the chip's side.
    private static let radius = 7.0

    /// The badge for `url`, or `.empty` when there is nothing safe to link to.
    ///
    /// Sanitised again on the way out: the commands check what they store, but
    /// `[url: "javascript:alert(1)"]` can be typed straight into the VGL and never
    /// passes through them.
    static func render(url: String?, centerX: Double, centerY: Double, darkMode: Bool) -> VSVGNode {
        guard let url, let safe = VURL.safe(url) else { return .empty }

        let chip = VSVGBuilder.rect(
            x: centerX - radius, y: centerY - radius,
            width: radius * 2, height: radius * 2,
            rx: radius * 0.6,
            style: VShapeStyle(fill: SemanticColor.linkBadgeFill.resolve(darkMode: darkMode)))

        return .element(
            .a,
            [
                VSVGAttribute("class", URLBadgeRenderer.cssClass),
                VSVGAttribute("href", safe),
                VSVGAttribute("target", "_blank"),
                VSVGAttribute("rel", "noopener noreferrer"),
            ],
            [
                .element(.title, [], [.text(safe)]),
                chip,
                glyph(centerX: centerX, centerY: centerY),
            ])
    }

    /// A chain link — two hooks facing each other across a bar — rather than the
    /// "opens in a new tab" arrow. The badge marks *that the element has a link*,
    /// which is the chain's meaning; and a lone diagonal stroke stops declaring
    /// which way it points at this size, where a symmetric glyph cannot be
    /// misread.
    private static func glyph(centerX: Double, centerY: Double) -> VSVGNode {
        // Chord = 2 × radius, so each hook is an exact semicircle: no large-arc
        // flag, only a sweep, one bulging each way.
        let hook = radius * 0.3
        let inner = radius * 0.34
        let left =
            "M \(centerX - inner) \(centerY - hook) A \(hook) \(hook) 0 0 0 \(centerX - inner) \(centerY + hook)"
        let right =
            "M \(centerX + inner) \(centerY - hook) A \(hook) \(hook) 0 0 1 \(centerX + inner) \(centerY + hook)"
        let bar = "M \(centerX - inner - 0.2) \(centerY) L \(centerX + inner + 0.2) \(centerY)"
        return .element(
            .path,
            [
                VSVGAttribute("d", "\(left) \(right) \(bar)"),
                VSVGAttribute("fill", "none"),
                VSVGAttribute("stroke", "#ffffff"),
                VSVGAttribute("stroke-width", "1.3"),
                VSVGAttribute("stroke-linecap", "round"),
            ])
    }
}
