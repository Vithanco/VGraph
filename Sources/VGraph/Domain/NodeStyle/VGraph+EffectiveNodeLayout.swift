// The layout a node type resolves to, without running the display pipeline.

extension VGraph {
    /// The `NodeStyleLayout` this node type renders with.
    ///
    /// Exists because the display pipeline has *not* run on the OriginGraph a
    /// [[VCommand]] sees: `assembleNodeStyles` stores the same value later, and
    /// delegates here so the derivation lives in one place.
    public func effectiveNodeLayout(for nodeType: NodeType) -> NodeStyleLayout? {
        effectiveNodeLayout(for: nodeType, background: nil, fontColor: nil)
    }

    /// Constructed styles are rebuilt rather than recoloured, so the override lands
    /// where the style's author put the colour — for `withCategory` the category
    /// bar, not the white body behind it.
    public func effectiveNodeLayout(
        for nodeType: NodeType, background: VColor?, fontColor: VColor?
    ) -> NodeStyleLayout? {
        let ns: NodeStyle = (try? get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle)) ?? .bareText
        let bg: VColor = background ?? backgroundColor(of: nodeType)
        let text: SemanticColor? = fontColor.map { SemanticColor.literal($0) }

        switch ns {
        case .presetLayout:
            let baked = try? get(nodeType: nodeType, attribute: Attributes.Node.style)
            guard background != nil || fontColor != nil else { return baked }
            return baked?.recolored(to: .literal(bg), fontColor: text)

        case .iconWithText:
            return .iconWithText(backgroundColor: .literal(bg), icon: icon(of: nodeType))

        case .simpleRoundedText:
            return .simpleRoundedText(color: .literal(bg))

        case .simpleRoundedBox:
            return .simpleRoundedBox(color: .literal(bg))

        case .withCategory:
            return .withCategory(category: categoryText(of: nodeType), categoryColor: .literal(bg))

        case .withCategoryAndIcon:
            return .withCategoryAndIcon(
                category: categoryText(of: nodeType),
                categoryColor: .literal(bg),
                icon: icon(of: nodeType))

        case .iconOnly:
            return .iconOnly(icon: icon(of: nodeType))

        case .circle:
            return .circle(color: .literal(bg))

        case .bareText:
            return .bareText

        case .hidden:
            return .hidden
        }
    }

    /// Reads *own* attributes: `get(node:)` inherits the type's value, which would
    /// report every node as overridden.
    public func effectiveNodeLayout(for node: Node) -> NodeStyleLayout? {
        guard let nodeType = try? nodeType(for: node) else { return nil }
        let own = getOwnAttributes(node: node)
        // `fromString`, not `hexString`: the store keeps what the author wrote, and
        // that may be a colour name.
        let background: VColor? = own[Attributes.Node.backgroundColor.id].flatMap { try? VColor.fromString($0) }
        let fontColor: VColor? = own[Attributes.Node.fontColor.id].flatMap { try? VColor.fromString($0) }
        guard background != nil || fontColor != nil else {
            return effectiveNodeLayout(for: nodeType)
        }
        return effectiveNodeLayout(for: nodeType, background: background, fontColor: fontColor)
    }

    /// Whether this node type renders the user's own text. Nothing to type means
    /// no inline editor is offered.
    public func hasUserText(nodeType: NodeType) -> Bool {
        effectiveNodeLayout(for: nodeType)?.hasUserText ?? false
    }

    private func icon(of nodeType: NodeType) -> IconInfo {
        (try? get(nodeType: nodeType, attribute: Attributes.Node.iconInfo)) ?? Attributes.Node.iconInfo.defaultValue
    }

    private func backgroundColor(of nodeType: NodeType) -> VColor {
        (try? get(nodeType: nodeType, attribute: Attributes.Node.backgroundColor))
            ?? Attributes.Node.backgroundColor.defaultValue
    }

    private func categoryText(of nodeType: NodeType) -> String {
        if let cat = try? get(nodeType: nodeType, attribute: Attributes.Node.category), !cat.isEmpty {
            return cat
        }
        return nodeType.id
    }
}
