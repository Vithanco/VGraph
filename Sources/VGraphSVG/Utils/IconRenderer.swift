import VGraph

public struct IconRenderer {

    /// Shared so the `<symbol>` and the `<use href="#…">` cannot drift apart.
    static func symbolId(_ name: String) -> String { "icon-" + name }

    /// Keyed by the name the document asked for even when the artwork is
    /// `IconArtwork.missing`, because the `<use>` was written from that name.
    public static func renderDefinition(name: String, artwork: IconArtwork) -> VSVGNode {
        .element(
            .symbol,
            [
                VSVGAttribute("id", symbolId(name)),
                VSVGAttribute("viewBox", artwork.viewBox),
            ],
            [.element(.path, [VSVGAttribute("d", artwork.path)])])
    }

    /// A name whose artwork another name has already drawn: the same box, pointing at it.
    public static func renderAlias(name: String, of original: String, artwork: IconArtwork) -> VSVGNode {
        .element(
            .symbol,
            [
                VSVGAttribute("id", symbolId(name)),
                VSVGAttribute("viewBox", artwork.viewBox),
            ],
            [
                .element(
                    .use,
                    [
                        VSVGAttribute("href", "#" + symbolId(original)),
                        VSVGAttribute("x", "\(artwork.minX)"), VSVGAttribute("y", "\(artwork.minY)"),
                        VSVGAttribute("width", "\(artwork.width)"),
                        VSVGAttribute("height", "\(artwork.height)"),
                    ])
            ])
    }

    /// Square on purpose: the `<symbol>` carries the artwork's viewBox, so SVG's
    /// default `xMidYMid meet` does the scaling and centring — which is what lets
    /// a node be drawn from an icon's *name*, with no artwork to resolve here.
    public static func renderWithReference(
        name: String, color: VColor, size: Double, centerX: Double, centerY: Double
    ) -> VSVGNode {
        // Raw interpolation, not `SVGBuilder.format`: the trailing `.0` is pinned.
        .element(
            .use,
            [
                VSVGAttribute("href", "#" + symbolId(name)),
                VSVGAttribute("x", "\(centerX - size / 2)"), VSVGAttribute("y", "\(centerY - size / 2)"),
                VSVGAttribute("width", "\(size)"), VSVGAttribute("height", "\(size)"),
                VSVGAttribute("fill", color.hexString),
            ])
    }
}
