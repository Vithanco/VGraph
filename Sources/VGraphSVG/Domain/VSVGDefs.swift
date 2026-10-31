import VGraph

public enum VSVGDefs {
    public static func render(icons: [String: IconArtwork], includeWatermark: Bool, darkMode: Bool) -> VSVGNode {
        let styles: [VSVGNode] = [
            VSVGBuilder.style(css: SVGBuilder.dmSansFontImportCSS()),
            VSVGBuilder.style(css: SVGBuilder.hoverStylesCSS()),
        ]

        if icons.isEmpty && !includeWatermark {
            return .fragment(styles)
        }

        var definitions: [VSVGNode] = []
        // Names that share an artwork share its path: the first name draws it and the
        // rest are symbols that only point at that one, so a path is written once.
        var firstNameWith: [IconArtwork: String] = [:]
        for name in icons.keys.sorted() {
            let artwork = icons[name]!
            if let first = firstNameWith[artwork] {
                definitions.append(IconRenderer.renderAlias(name: name, of: first, artwork: artwork))
            } else {
                firstNameWith[artwork] = name
                definitions.append(IconRenderer.renderDefinition(name: name, artwork: artwork))
            }
        }
        if includeWatermark {
            definitions.append(WatermarkRenderer.renderDefinition(darkMode: darkMode))
        }

        return .fragment(styles + [.element(.defs, [], definitions)])
    }
}
