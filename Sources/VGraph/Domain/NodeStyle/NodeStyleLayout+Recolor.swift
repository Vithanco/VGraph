// A `presetLayout` notation bakes its colours into a `NodeStyleLayout` at install
// time, leaving no constructor to call again with a different fill. Walking the
// built tree is the only way to honour a per-node colour.

extension NodeStyleLayout {

    /// `clear` reports `nil` rather than a colour: a C4 boundary's transparency is
    /// deliberate, and giving it a fill would paint over the notation's intent.
    public var backgroundFill: SemanticColor? {
        switch self {
        case .background(let background, _):
            switch background {
            case .appearance(_, let color), .solid(_, let color), .pill(let color): return color
            case .clear: return nil
            }
        case .padded(_, let inner), .sized(_, let inner): return inner.backgroundFill
        case .overlay(let base, _): return base.backgroundFill
        default: return nil
        }
    }

    /// Substitutes by value rather than by position, because a C4 card draws its
    /// border in the same colour as its fill — replacing only the background would
    /// leave the old colour ringing the new one.
    ///
    /// Text is left alone while it still reads: C4 sets its light cards in
    /// `#111111`, which a blanket repaint to black would flatten away.
    public func recolored(to newFill: SemanticColor, fontColor: SemanticColor? = nil) -> NodeStyleLayout {
        guard let oldFill = backgroundFill else { return self }
        return substituting(oldFill: oldFill, newFill: newFill, fontColor: fontColor)
    }

    private func substituting(
        oldFill: SemanticColor, newFill: SemanticColor, fontColor: SemanticColor?
    ) -> NodeStyleLayout {
        func fill(_ color: SemanticColor) -> SemanticColor {
            color == oldFill ? newFill : color
        }
        func text(_ color: SemanticColor) -> SemanticColor {
            if let fontColor { return fontColor }
            return color.isLight == newFill.isLight ? newFill.bwContrastColor : color
        }
        func recurse(_ layout: NodeStyleLayout) -> NodeStyleLayout {
            layout.substituting(oldFill: oldFill, newFill: newFill, fontColor: fontColor)
        }

        switch self {
        case .empty, .icon:
            return self

        case .categoryHeader(let t, let font, let backgroundColor, let textColor):
            return .categoryHeader(
                text: t, font: font, backgroundColor: fill(backgroundColor), textColor: text(textColor))

        case .frame(let cornerRadius, let borderWidth, let borderColor):
            return .frame(cornerRadius: cornerRadius, borderWidth: borderWidth, borderColor: fill(borderColor))

        case .circleBorder(let borderWidth, let borderColor):
            return .circleBorder(borderWidth: borderWidth, borderColor: fill(borderColor))

        case .nodeText(let color):
            return .nodeText(color: text(color))

        case .italicNodeText(let color):
            return .italicNodeText(color: text(color))

        case .padded(let insets, let inner):
            return .padded(insets, recurse(inner))

        case .background(let background, let inner):
            return .background(background.recolored(fill: fill), recurse(inner))

        case .sized(let multiplier, let inner):
            return .sized(multiplier: multiplier, recurse(inner))

        case .vertical(let layouts, let spacing):
            return .vertical(layouts.map { recurse($0) }, spacing: spacing)

        case .horizontal(let layouts, let spacing):
            return .horizontal(layouts.map { recurse($0) }, spacing: spacing)

        case .overlay(let base, let overlay):
            return .overlay(base: recurse(base), overlay: recurse(overlay))

        case .accentBar(let width, let color):
            return .accentBar(width: width, color: fill(color))

        case .typeLabel(let t, let font, let color):
            return .typeLabel(text: t, font: font, color: text(color))

        case .typeBadge(let icon, let typeLabel, let color):
            return .typeBadge(icon: icon, typeLabel: typeLabel, color: fill(color))

        case .dashedFrame(let cornerRadius, let borderWidth, let borderColor, let dashPattern):
            return .dashedFrame(
                cornerRadius: cornerRadius, borderWidth: borderWidth,
                borderColor: fill(borderColor), dashPattern: dashPattern)

        case .subtitleText(let t, let color):
            return .subtitleText(text: t, color: text(color))

        case .pillBadge(let t, let pillFill, let textColor):
            return .pillBadge(text: t, fill: fill(pillFill), textColor: text(textColor))

        case .stackedShadow(let cornerRadius, let borderWidth, let shadowFill, let border, let dash):
            return .stackedShadow(
                cornerRadius: cornerRadius, borderWidth: borderWidth,
                fill: fill(shadowFill), border: fill(border), dash: dash)

        case .circleContent(let content, let font, let color):
            return .circleContent(content, font: font, color: text(color))
        }
    }
}

extension NodeBackground {
    fileprivate func recolored(fill: (SemanticColor) -> SemanticColor) -> NodeBackground {
        switch self {
        case .appearance(let shape, let color): return .appearance(shape: shape, color: fill(color))
        case .solid(let shape, let color): return .solid(shape: shape, color: fill(color))
        case .clear(let shape): return .clear(shape: shape)
        case .pill(let color): return .pill(color: fill(color))
        }
    }
}
