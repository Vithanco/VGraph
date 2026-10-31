public indirect enum NodeStyleLayout: VProtocol, AttributeType {
    case categoryHeader(text: String, font: VFont, backgroundColor: SemanticColor, textColor: SemanticColor)
    case frame(cornerRadius: Double, borderWidth: Double, borderColor: SemanticColor)
    case circleBorder(borderWidth: Double, borderColor: SemanticColor)
    case icon(IconInfo)
    case nodeText(color: SemanticColor)
    case empty
    case padded(VEdgeInsets, NodeStyleLayout)
    case background(NodeBackground, NodeStyleLayout)
    case sized(multiplier: Double, NodeStyleLayout)
    case vertical([NodeStyleLayout], spacing: Double)
    case horizontal([NodeStyleLayout], spacing: Double)
    case overlay(base: NodeStyleLayout, overlay: NodeStyleLayout)
    /// A 4px left accent bar — overlaid on top of the background, full height of its bounds.
    case accentBar(width: Double, color: SemanticColor)
    /// A small left-aligned type label row, uppercase — used in the accent strip design.
    case typeLabel(text: String, font: VFont, color: SemanticColor)
    /// A node type badge: an icon on a coloured circle, then the type name. The icon is a name,
    /// resolved like any other icon, and is drawn in the `badgeIcon` colour.
    case typeBadge(icon: String, typeLabel: String, color: SemanticColor)
    /// Like `frame` but with a dashed border stroke. dashPattern is an SVG stroke-dasharray value, e.g. "5,3".
    case dashedFrame(cornerRadius: Double, borderWidth: Double, borderColor: SemanticColor, dashPattern: String)
    /// Node content text rendered in italic — used for annotation/warning meta-nodes.
    case italicNodeText(color: SemanticColor)
    /// Fixed italic subtitle below the main label — text content is baked in at build time.
    case subtitleText(text: String, color: SemanticColor)
    /// A pill-shaped badge (22×16 px) with centred bold white text — used for count indicators.
    case pillBadge(text: String, fill: SemanticColor, textColor: SemanticColor)
    /// Dashed rounded rect with 2 offset shadow copies behind (+5 px, +10 px at reduced opacity).
    case stackedShadow(cornerRadius: Double, borderWidth: Double, fill: SemanticColor, border: SemanticColor, dash: String)
    /// An icon or plain text centred in a circle. Unlike `typeLabel`, text is neither uppercased
    /// nor letter-spaced nor faded: here it is the content, not a label describing it.
    case circleContent(CircleContent, font: VFont, color: SemanticColor)

    /// Whether this layout renders the *user's* text anywhere in its tree.
    ///
    /// Only `nodeText`/`italicNodeText` qualify: `typeLabel`, `categoryHeader`,
    /// `subtitleText` and `pillBadge` carry literal text belonging to the style,
    /// which the user does not author and cannot edit.
    public var hasUserText: Bool {
        walk { layout in
            switch layout {
            case .nodeText, .italicNodeText: return true
            default: return nil
            }
        } ?? false
    }

    // MARK: - Generic Walker

    public func walk<T>(_ visitor: (NodeStyleLayout) -> T?) -> T? {
        if let result = visitor(self) {
            return result
        }

        switch self {
        case .categoryHeader, .frame, .circleBorder, .icon, .nodeText, .empty,
            .accentBar, .typeLabel, .typeBadge, .dashedFrame, .italicNodeText,
            .subtitleText, .pillBadge, .stackedShadow, .circleContent:
            return nil

        case .padded(_, let inner),
            .background(_, let inner),
            .sized(_, let inner):
            return inner.walk(visitor)

        case .vertical(let layouts, _),
            .horizontal(let layouts, _):
            for layout in layouts {
                if let result = layout.walk(visitor) {
                    return result
                }
            }
            return nil

        case .overlay(let base, let overlay):
            if let result = base.walk(visitor) {
                return result
            }
            return overlay.walk(visitor)
        }
    }

    public func walkAll<T>(_ visitor: (NodeStyleLayout) -> T?) -> [T] {
        var results: [T] = []
        walkAllCollecting(visitor, into: &results)
        return results
    }

    private func walkAllCollecting<T>(_ visitor: (NodeStyleLayout) -> T?, into results: inout [T]) {
        if let result = visitor(self) {
            results.append(result)
        }

        switch self {
        case .categoryHeader, .frame, .circleBorder, .icon, .nodeText, .empty,
            .accentBar, .typeLabel, .typeBadge, .dashedFrame, .italicNodeText,
            .subtitleText, .pillBadge, .stackedShadow, .circleContent:
            break

        case .padded(_, let inner),
            .background(_, let inner),
            .sized(_, let inner):
            inner.walkAllCollecting(visitor, into: &results)

        case .vertical(let layouts, _),
            .horizontal(let layouts, _):
            for layout in layouts {
                layout.walkAllCollecting(visitor, into: &results)
            }

        case .overlay(let base, let overlay):
            base.walkAllCollecting(visitor, into: &results)
            overlay.walkAllCollecting(visitor, into: &results)
        }
    }

    // MARK: - Icon Extraction

    public func extractIcons() -> Set<String> {
        let iconNames: [String] = walkAll { layout in
            switch layout {
            case .icon(let iconInfo): return iconInfo.iconName
            case .typeBadge(let icon, _, _): return icon
            case .circleContent(.icon(let name), _, _): return name
            default: return nil
            }
        }
        return Set(iconNames)
    }

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "NodeStyleLayout"
    }

    public static func fromString(_ string: String) throws(VError) -> NodeStyleLayout {
        var parser = Parser(string: string)
        return try parser.parseLayout()
    }

    public var asString: String {
        switch self {
        case .categoryHeader(let text, let font, let bgColor, let textColor):
            return "cat{\(text)|\(font.asString)|\(bgColor.asString)|\(textColor.asString)}"
        case .frame(let cornerRadius, let borderWidth, let borderColor):
            return "fr{\(cornerRadius)|\(borderWidth)|\(borderColor.asString)}"
        case .circleBorder(let borderWidth, let borderColor):
            return "cb{\(borderWidth)|\(borderColor.asString)}"
        case .icon(let iconInfo):
            return "ic{\(iconInfo.asString)}"
        case .nodeText(let color):
            return "txt{\(color.asString)}"
        case .empty:
            return "empty"
        case .padded(let insets, let layout):
            return "pad{\(insets.asString)|\(layout.asString)}"
        case .background(let bg, let layout):
            return "bg{\(bg.asString)|\(layout.asString)}"
        case .sized(let multiplier, let layout):
            return "sz{\(multiplier)|\(layout.asString)}"
        case .vertical(let layouts, let spacing):
            let layoutStrings = layouts.map { $0.asString }.joined(separator: ",")
            return "v{\(spacing)|\(layoutStrings)}"
        case .horizontal(let layouts, let spacing):
            let layoutStrings = layouts.map { $0.asString }.joined(separator: ",")
            return "h{\(spacing)|\(layoutStrings)}"
        case .overlay(let base, let overlay):
            return "o{\(base.asString)|\(overlay.asString)}"
        case .accentBar(let width, let color):
            return "abar{\(width)|\(color.asString)}"
        case .typeLabel(let text, let font, let color):
            return "tlbl{\(text)|\(font.asString)|\(color.asString)}"
        case .typeBadge(let icon, let typeLabel, let color):
            return "tbdg{\(icon)|\(typeLabel)|\(color.asString)}"
        case .dashedFrame(let cornerRadius, let borderWidth, let borderColor, let dashPattern):
            return "dfr{\(cornerRadius)|\(borderWidth)|\(borderColor.asString)|\(dashPattern)}"
        case .italicNodeText(let color):
            return "itxt{\(color.asString)}"
        case .subtitleText(let text, let color):
            return "stxt{\(text)|\(color.asString)}"
        case .pillBadge(let text, let fill, let textColor):
            return "pill{\(text)|\(fill.asString)|\(textColor.asString)}"
        case .stackedShadow(let cr, let bw, let fill, let border, let dash):
            return "stshdw{\(cr)|\(bw)|\(fill.asString)|\(border.asString)|\(dash)}"
        case .circleContent(let content, let font, let color):
            return "ccont{\(content.asString)|\(font.asString)|\(color.asString)}"
        }
    }

    // MARK: - Parser

    private struct Parser {
        var string: String
        var index: String.Index

        init(string: String) {
            self.string = string
            self.index = string.startIndex
        }

        mutating func parseLayout() throws(VError) -> NodeStyleLayout {
            skipWhitespace()

            if peek(count: 5) == "empty" {
                advance(count: 5)
                return .empty
            }

            if peek(count: 4) == "cat{" {
                return try parseCategoryHeader()
            }

            if peek(count: 3) == "fr{" {
                return try parseFrame()
            }

            if peek(count: 3) == "cb{" {
                return try parseCircleBorder()
            }

            if peek(count: 3) == "ic{" {
                return try parseIcon()
            }

            if peek(count: 4) == "txt{" {
                return try parseNodeText()
            }

            if peek(count: 4) == "pad{" {
                return try parsePadded()
            }

            if peek(count: 3) == "bg{" {
                return try parseBackground()
            }

            if peek(count: 3) == "sz{" {
                return try parseSized()
            }

            if peek(count: 2) == "v{" {
                return try parseVertical()
            }

            if peek(count: 2) == "h{" {
                return try parseHorizontal()
            }

            if peek(count: 2) == "o{" {
                return try parseOverlay()
            }

            if peek(count: 5) == "abar{" {
                return try parseAccentBar()
            }

            if peek(count: 5) == "tlbl{" {
                return try parseTypeLabel()
            }

            if peek(count: 5) == "tbdg{" {
                return try parseTypeBadge()
            }

            if peek(count: 4) == "dfr{" {
                return try parseDashedFrame()
            }

            if peek(count: 5) == "itxt{" {
                return try parseItalicNodeText()
            }

            if peek(count: 5) == "stxt{" {
                return try parseSubtitleText()
            }

            if peek(count: 5) == "pill{" {
                return try parsePillBadge()
            }

            if peek(count: 7) == "stshdw{" {
                return try parseStackedShadow()
            }

            if peek(count: 6) == "ccont{" {
                return try parseCircleContent()
            }

            throw VError.conversionError(from: string, to: "NodeStyleLayout")
        }

        mutating func parseCategoryHeader() throws(VError) -> NodeStyleLayout {
            advance(count: 4)
            let text = try readUntil("|")
            advance(count: 1)
            let fontStr = try readUntil("|")
            advance(count: 1)
            let bgColorStr = try readUntil("|")
            advance(count: 1)
            let textColorStr = try readUntil("}")
            advance(count: 1)
            let font = try VFont.fromString(fontStr)
            let bgColor = try SemanticColor.fromString(bgColorStr)
            let textColor = try SemanticColor.fromString(textColorStr)
            return .categoryHeader(text: text, font: font, backgroundColor: bgColor, textColor: textColor)
        }

        mutating func parseFrame() throws(VError) -> NodeStyleLayout {
            advance(count: 3)
            let cornerRadiusStr = try readUntil("|")
            advance(count: 1)
            let borderWidthStr = try readUntil("|")
            advance(count: 1)
            let borderColorStr = try readUntil("}")
            advance(count: 1)
            guard let cornerRadius = Double(cornerRadiusStr),
                let borderWidth = Double(borderWidthStr)
            else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            let borderColor = try SemanticColor.fromString(borderColorStr)
            return .frame(cornerRadius: cornerRadius, borderWidth: borderWidth, borderColor: borderColor)
        }

        mutating func parseCircleBorder() throws(VError) -> NodeStyleLayout {
            advance(count: 3)
            let borderWidthStr = try readUntil("|")
            advance(count: 1)
            let borderColorStr = try readUntil("}")
            advance(count: 1)
            guard let borderWidth = Double(borderWidthStr) else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            let borderColor = try SemanticColor.fromString(borderColorStr)
            return .circleBorder(borderWidth: borderWidth, borderColor: borderColor)
        }

        mutating func parseIcon() throws(VError) -> NodeStyleLayout {
            advance(count: 3)
            let content = try readUntil("}")
            advance(count: 1)
            let icon = try IconInfo.fromString(content)
            return .icon(icon)
        }

        mutating func parseNodeText() throws(VError) -> NodeStyleLayout {
            advance(count: 4)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let color = try SemanticColor.fromString(colorStr)
            return .nodeText(color: color)
        }

        mutating func parsePadded() throws(VError) -> NodeStyleLayout {
            advance(count: 4)
            let insetsStr = try readUntil("|")
            advance(count: 1)
            let insets = try VEdgeInsets.fromString(insetsStr)
            let layout = try parseLayout()
            expect("}")
            return .padded(insets, layout)
        }

        mutating func parseBackground() throws(VError) -> NodeStyleLayout {
            advance(count: 3)
            let bgStr = try readUntil("|")
            advance(count: 1)
            let background = try NodeBackground.fromString(bgStr)
            let layout = try parseLayout()
            expect("}")
            return .background(background, layout)
        }

        mutating func parseSized() throws(VError) -> NodeStyleLayout {
            advance(count: 3)
            let multiplierStr = try readUntil("|")
            advance(count: 1)
            guard let multiplier = Double(multiplierStr) else {
                throw VError.conversionError(from: multiplierStr, to: "Double")
            }
            let layout = try parseLayout()
            expect("}")
            return .sized(multiplier: multiplier, layout)
        }

        mutating func parseVertical() throws(VError) -> NodeStyleLayout {
            advance(count: 2)
            let spacingStr = try readUntil("|")
            advance(count: 1)
            guard let spacing = Double(spacingStr) else {
                throw VError.conversionError(from: spacingStr, to: "Double")
            }
            let layouts = try parseLayoutList()
            expect("}")
            return .vertical(layouts, spacing: spacing)
        }

        mutating func parseHorizontal() throws(VError) -> NodeStyleLayout {
            advance(count: 2)
            let spacingStr = try readUntil("|")
            advance(count: 1)
            guard let spacing = Double(spacingStr) else {
                throw VError.conversionError(from: spacingStr, to: "Double")
            }
            let layouts = try parseLayoutList()
            expect("}")
            return .horizontal(layouts, spacing: spacing)
        }

        mutating func parseOverlay() throws(VError) -> NodeStyleLayout {
            advance(count: 2)
            let base = try parseLayout()
            expect("|")
            let overlay = try parseLayout()
            expect("}")
            return .overlay(base: base, overlay: overlay)
        }

        mutating func parseLayoutList() throws(VError) -> [NodeStyleLayout] {
            var layouts: [NodeStyleLayout] = []
            while peek() != "}" && !isAtEnd {
                let layout = try parseLayout()
                layouts.append(layout)
                skipWhitespace()
                if peek() == "," {
                    advance(count: 1)
                    skipWhitespace()
                }
            }
            return layouts
        }

        mutating func parseAccentBar() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let widthStr = try readUntil("|")
            advance(count: 1)
            let colorStr = try readUntil("}")
            advance(count: 1)
            guard let width = Double(widthStr) else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            let color = try SemanticColor.fromString(colorStr)
            return .accentBar(width: width, color: color)
        }

        mutating func parseTypeLabel() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let text = try readUntil("|")
            advance(count: 1)
            let fontStr = try readUntil("|")
            advance(count: 1)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let font = try VFont.fromString(fontStr)
            let color = try SemanticColor.fromString(colorStr)
            return .typeLabel(text: text, font: font, color: color)
        }

        mutating func parseTypeBadge() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let icon = try readUntil("|")
            advance(count: 1)
            let label = try readUntil("|")
            advance(count: 1)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let color = try SemanticColor.fromString(colorStr)
            return .typeBadge(icon: icon, typeLabel: label, color: color)
        }

        mutating func parseDashedFrame() throws(VError) -> NodeStyleLayout {
            advance(count: 4)
            let cornerRadiusStr = try readUntil("|")
            advance(count: 1)
            let borderWidthStr = try readUntil("|")
            advance(count: 1)
            let borderColorStr = try readUntil("|")
            advance(count: 1)
            let dashPattern = try readUntil("}")
            advance(count: 1)
            guard let cornerRadius = Double(cornerRadiusStr),
                let borderWidth = Double(borderWidthStr)
            else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            let borderColor = try SemanticColor.fromString(borderColorStr)
            return .dashedFrame(cornerRadius: cornerRadius, borderWidth: borderWidth, borderColor: borderColor, dashPattern: dashPattern)
        }

        mutating func parseItalicNodeText() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let color = try SemanticColor.fromString(colorStr)
            return .italicNodeText(color: color)
        }

        mutating func parseSubtitleText() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let text = try readUntil("|")
            advance(count: 1)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let color = try SemanticColor.fromString(colorStr)
            return .subtitleText(text: text, color: color)
        }

        mutating func parsePillBadge() throws(VError) -> NodeStyleLayout {
            advance(count: 5)
            let text = try readUntil("|")
            advance(count: 1)
            let fillStr = try readUntil("|")
            advance(count: 1)
            let textColorStr = try readUntil("}")
            advance(count: 1)
            let fill = try SemanticColor.fromString(fillStr)
            let textColor = try SemanticColor.fromString(textColorStr)
            return .pillBadge(text: text, fill: fill, textColor: textColor)
        }

        mutating func parseStackedShadow() throws(VError) -> NodeStyleLayout {
            advance(count: 7)
            let crStr = try readUntil("|")
            advance(count: 1)
            let bwStr = try readUntil("|")
            advance(count: 1)
            let fillStr = try readUntil("|")
            advance(count: 1)
            let borderStr = try readUntil("|")
            advance(count: 1)
            let dash = try readUntil("}")
            advance(count: 1)
            guard let cr = Double(crStr), let bw = Double(bwStr) else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            let fill = try SemanticColor.fromString(fillStr)
            let border = try SemanticColor.fromString(borderStr)
            return .stackedShadow(cornerRadius: cr, borderWidth: bw, fill: fill, border: border, dash: dash)
        }

        mutating func parseCircleContent() throws(VError) -> NodeStyleLayout {
            advance(count: 6)
            let contentStr = try readUntil("|")
            advance(count: 1)
            let fontStr = try readUntil("|")
            advance(count: 1)
            let colorStr = try readUntil("}")
            advance(count: 1)
            let content = try CircleContent.fromString(contentStr)
            let font = try VFont.fromString(fontStr)
            let color = try SemanticColor.fromString(colorStr)
            return .circleContent(content, font: font, color: color)
        }

        mutating func readUntil(_ char: String) throws(VError) -> String {
            var result = ""
            var depth = 0
            while !isAtEnd {
                let current = peek()
                if current == "{" {
                    depth += 1
                } else if current == "}" {
                    if depth == 0 && char == "}" {
                        return result
                    }
                    depth -= 1
                } else if current == char && depth == 0 {
                    return result
                }
                result.append(current)
                advance(count: 1)
            }
            throw VError.conversionError(from: string, to: "NodeStyleLayout")
        }

        mutating func expect(_ char: String) {
            skipWhitespace()
            if peek() == char {
                advance(count: 1)
            }
        }

        func peek(count: Int = 1) -> String {
            guard index < string.endIndex else { return "" }
            let endIdx = string.index(index, offsetBy: count, limitedBy: string.endIndex) ?? string.endIndex
            return String(string[index..<endIdx])
        }

        mutating func advance(count: Int) {
            for _ in 0..<count where index < string.endIndex {
                index = string.index(after: index)
            }
        }

        mutating func skipWhitespace() {
            while index < string.endIndex && string[index].isWhitespace {
                index = string.index(after: index)
            }
        }

        var isAtEnd: Bool {
            return index >= string.endIndex
        }
    }
}

/// What fills a node's centred circle: an icon, or plain text such as "= 3".
public enum CircleContent: VProtocol {
    case icon(String)
    case text(String)

    var asString: String {
        switch self {
        case .icon(let name): return "icon:" + name
        case .text(let text): return "text:" + text
        }
    }

    static func fromString(_ string: String) throws(VError) -> CircleContent {
        if string.hasPrefix("icon:") { return .icon(String(string.dropFirst(5))) }
        if string.hasPrefix("text:") { return .text(String(string.dropFirst(5))) }
        throw VError.conversionError(from: string, to: "CircleContent")
    }
}
