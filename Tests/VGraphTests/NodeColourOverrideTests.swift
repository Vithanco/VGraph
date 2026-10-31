import Testing

@testable import VGraph

@Suite("Per-node colour override")
struct NodeColourOverrideTests {

    private let green = SemanticColor.literal(lightHex: "#b6e6bd")

    // MARK: - recolored, on a preset (C4) card

    private func c4Card() -> NodeStyleLayout {
        NodeStyleLayout.c4Element(
            stereotype: "Container", fill: Notations.C4.containerFill, textColor: Notations.C4.onDark)
    }

    @Test("the fill is replaced")
    func replacesFill() {
        let recoloured = c4Card().recolored(to: green)
        #expect(recoloured.backgroundFill == green)
    }

    @Test("the border, drawn in the fill colour, is replaced too")
    func replacesBorderDrawnInFillColour() {
        let before = collectColors(c4Card())
        #expect(before.contains(Notations.C4.containerFill))

        let after = collectColors(c4Card().recolored(to: green))
        #expect(!after.contains(Notations.C4.containerFill))
    }

    @Test("white-on-blue text becomes dark on a light fill")
    func repaintsTextForContrast() {
        #expect(Notations.C4.onDark.isLight)
        #expect(green.isLight)

        let colors = collectColors(c4Card().recolored(to: green))
        #expect(!colors.contains(Notations.C4.onDark))
        #expect(colors.contains { !$0.isLight })
    }

    /// `#111111` is C4's own choice for light cards, and still reads on one.
    @Test("text that still reads is kept, not flattened")
    func keepsLegibleText() {
        let lightCard = NodeStyleLayout.c4Element(
            stereotype: "Component", fill: Notations.C4.componentFill, textColor: Notations.C4.onLight)
        let colors = collectColors(lightCard.recolored(to: green))
        #expect(colors.contains(Notations.C4.onLight))
    }

    @Test("an explicit fontColor wins over the contrast rule")
    func explicitFontColorWins() {
        let brand = SemanticColor.literal(lightHex: "#332211")
        let colors = collectColors(c4Card().recolored(to: green, fontColor: brand))
        #expect(colors.contains(brand))
        #expect(!colors.contains(green.bwContrastColor))
    }

    /// The reason recolouring beats redeclaring the type in a `vnotation`.
    @Test("shape and stereotype survive recolouring")
    func preservesShapeAndStereotype() {
        let cylinder = NodeStyleLayout.c4Element(
            stereotype: "Container: Database", fill: Notations.C4.containerFill,
            textColor: Notations.C4.onDark, shape: .cylinder)
        let recoloured = cylinder.recolored(to: green)
        #expect(shapes(of: recoloured) == shapes(of: cylinder))
        #expect(typeLabels(of: recoloured) == ["«Container: Database»"])
    }

    @Test("a clear background is left alone")
    func leavesClearBackgroundAlone() {
        let clear = NodeStyleLayout.background(.clear(shape: .box), .nodeText(color: Notations.C4.onLight))
        #expect(clear.backgroundFill == nil)
        #expect(clear.recolored(to: green) == clear)
    }

    // MARK: - the constructed styles are rebuilt, not walked

    /// The outermost background is the white body, so a positional rule would
    /// recolour the wrong half.
    @Test("withCategory override lands on the bar, not the body")
    func withCategoryOverridesTheBar() throws {
        var graph = VGraph()
        let type = NodeType(string: "Tagged")
        graph = try graph.add(nodeType: type)
        graph = try graph.set(nodeType: type, attribute: Attributes.Node.nodeStyle.attribute(.withCategory))
        graph = try graph.set(
            nodeType: type,
            attribute: Attributes.Node.backgroundColor.attribute(VColor(hexString: "#884499")!))

        let overridden = graph.effectiveNodeLayout(
            for: type, background: VColor(hexString: "#b6e6bd")!, fontColor: nil)
        #expect(overridden?.backgroundFill?.lightHex.lowercased() == "#ffffff")
        let hexes = collectColors(overridden!).map { $0.lightHex.lowercased() }
        #expect(hexes.contains { $0.hasPrefix("#b6e6bd") })
        #expect(!hexes.contains { $0.hasPrefix("#884499") })
    }

    // MARK: - helpers

    private func collectColors(_ layout: NodeStyleLayout) -> [SemanticColor] {
        switch layout {
        case .empty, .icon: return []
        case .categoryHeader(_, _, let bg, let text): return [bg, text]
        case .frame(_, _, let c), .circleBorder(_, let c), .accentBar(_, let c): return [c]
        case .nodeText(let c), .italicNodeText(let c), .typeLabel(_, _, let c),
            .typeBadge(_, _, let c), .subtitleText(_, let c), .circleContent(_, _, let c):
            return [c]
        case .dashedFrame(_, _, let c, _): return [c]
        case .pillBadge(_, let f, let t): return [f, t]
        case .stackedShadow(_, _, let f, let b, _): return [f, b]
        case .padded(_, let inner), .sized(_, let inner): return collectColors(inner)
        case .background(let bg, let inner):
            let own: [SemanticColor]
            switch bg {
            case .appearance(_, let c), .solid(_, let c), .pill(let c): own = [c]
            case .clear: own = []
            }
            return own + collectColors(inner)
        case .vertical(let ls, _), .horizontal(let ls, _): return ls.flatMap { collectColors($0) }
        case .overlay(let base, let overlay): return collectColors(base) + collectColors(overlay)
        }
    }

    private func shapes(of layout: NodeStyleLayout) -> [NodeShape] {
        switch layout {
        case .background(let bg, let inner): return [bg.shape] + shapes(of: inner)
        case .padded(_, let inner), .sized(_, let inner): return shapes(of: inner)
        case .vertical(let ls, _), .horizontal(let ls, _): return ls.flatMap { shapes(of: $0) }
        case .overlay(let base, let overlay): return shapes(of: base) + shapes(of: overlay)
        default: return []
        }
    }

    private func typeLabels(of layout: NodeStyleLayout) -> [String] {
        switch layout {
        case .typeLabel(let text, _, _): return [text]
        case .padded(_, let inner), .sized(_, let inner), .background(_, let inner):
            return typeLabels(of: inner)
        case .vertical(let ls, _), .horizontal(let ls, _): return ls.flatMap { typeLabels(of: $0) }
        case .overlay(let base, let overlay): return typeLabels(of: base) + typeLabels(of: overlay)
        default: return []
        }
    }
}

@Suite("SVG colour keywords")
struct SVGColorKeywordTests {

    @Test("every keyword resolves")
    func allKeywordsResolve() {
        #expect(VColor.svgColorKeywords.count == 147)
        for (name, hex) in VColor.svgColorKeywords {
            #expect(VColor(named: name) != nil, "\(name) should resolve")
            #expect(VColor(named: name) == VColor(hexString: hex), "\(name) should equal \(hex)")
        }
    }

    @Test("names are case-insensitive")
    func caseInsensitive() {
        #expect(VColor(named: "CornflowerBlue") == VColor(named: "cornflowerblue"))
    }

    /// Graphviz accepts these, so the parser is where its palette would creep back in.
    @Test("X11-only names do not resolve")
    func x11OnlyNamesRejected() {
        for name in ["chartreuse3", "gray50", "grey17", "dodgerblue4"] {
            #expect(VColor(named: name) == nil, "\(name) is X11-only and should not resolve")
        }
    }

    /// The reason names are never derived back from a colour.
    @Test("the standard contains exact duplicates")
    func duplicatesExist() {
        #expect(VColor(named: "grey") == VColor(named: "gray"))
        #expect(VColor(named: "aqua") == VColor(named: "cyan"))
        #expect(VColor(named: "magenta") == VColor(named: "fuchsia"))
    }

    @Test("hex still parses, and wins")
    func hexStillParses() throws {
        #expect(try VColor.fromString("#b6e6bd") == VColor(hexString: "#b6e6bd"))
        #expect(try VColor.fromString("red") == VColor(hexString: "#ff0000"))
        #expect(throws: VError.self) { try VColor.fromString("not-a-colour") }
    }
}
