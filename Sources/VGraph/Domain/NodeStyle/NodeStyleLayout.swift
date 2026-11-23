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

    /// The layouts directly inside this one, in drawing order.
    private var children: [NodeStyleLayout] {
        switch self {
        case .categoryHeader, .frame, .circleBorder, .icon, .nodeText, .empty,
            .accentBar, .typeLabel, .typeBadge, .dashedFrame, .italicNodeText,
            .subtitleText, .pillBadge, .stackedShadow, .circleContent:
            return []
        case .padded(_, let inner), .background(_, let inner), .sized(_, let inner):
            return [inner]
        case .vertical(let layouts, _), .horizontal(let layouts, _):
            return layouts
        case .overlay(let base, let overlay):
            return [base, overlay]
        }
    }

    /// The first answer `visitor` gives, depth first.
    public func walk<T>(_ visitor: (NodeStyleLayout) -> T?) -> T? {
        if let result = visitor(self) {
            return result
        }
        for child in children {
            if let result = child.walk(visitor) {
                return result
            }
        }
        return nil
    }

    /// Every answer `visitor` gives, depth first.
    public func walkAll<T>(_ visitor: (NodeStyleLayout) -> T?) -> [T] {
        (visitor(self).map { [$0] } ?? []) + children.flatMap { $0.walkAll(visitor) }
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
        case .categoryHeader(let text, let font, let backgroundColor, let textColor):
            return "cat{\(text)|\(font.asString)|\(backgroundColor.asString)|\(textColor.asString)}"
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
        case .background(let background, let layout):
            return "bg{\(background.asString)|\(layout.asString)}"
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
        case .stackedShadow(let cornerRadius, let borderWidth, let fill, let border, let dash):
            return "stshdw{\(cornerRadius)|\(borderWidth)|\(fill.asString)|\(border.asString)|\(dash)}"
        case .circleContent(let content, let font, let color):
            return "ccont{\(content.asString)|\(font.asString)|\(color.asString)}"
        }
    }

    // MARK: - Parser

    private struct Parser {
        let string: String
        var index: String.Index

        init(string: String) {
            self.string = string
            self.index = string.startIndex
        }

        mutating func parseLayout() throws(VError) -> NodeStyleLayout {
            skipWhitespace()
            if consume("empty") { return .empty }
            if consume("cat{") { return try parseCategoryHeader() }
            if consume("fr{") { return try parseFrame() }
            if consume("cb{") { return try parseCircleBorder() }
            if consume("ic{") { return .icon(try IconInfo.fromString(try soleField())) }
            if consume("txt{") { return .nodeText(color: try SemanticColor.fromString(try soleField())) }
            if consume("pad{") { return try parsePadded() }
            if consume("bg{") { return try parseBackground() }
            if consume("sz{") { return try parseSized() }
            if consume("v{") { return try parseVertical() }
            if consume("h{") { return try parseHorizontal() }
            if consume("o{") { return try parseOverlay() }
            if consume("abar{") { return try parseAccentBar() }
            if consume("tlbl{") { return try parseTypeLabel() }
            if consume("tbdg{") { return try parseTypeBadge() }
            if consume("dfr{") { return try parseDashedFrame() }
            if consume("itxt{") { return .italicNodeText(color: try SemanticColor.fromString(try soleField())) }
            if consume("stxt{") { return try parseSubtitleText() }
            if consume("pill{") { return try parsePillBadge() }
            if consume("stshdw{") { return try parseStackedShadow() }
            if consume("ccont{") { return try parseCircleContent() }
            throw VError.conversionError(from: string, to: "NodeStyleLayout")
        }

        mutating func parseCategoryHeader() throws(VError) -> NodeStyleLayout {
            let field = try fields(4)
            return .categoryHeader(
                text: field[0], font: try VFont.fromString(field[1]),
                backgroundColor: try SemanticColor.fromString(field[2]), textColor: try SemanticColor.fromString(field[3]))
        }

        mutating func parseFrame() throws(VError) -> NodeStyleLayout {
            let field = try fields(3)
            return .frame(
                cornerRadius: try number(field[0]), borderWidth: try number(field[1]),
                borderColor: try SemanticColor.fromString(field[2]))
        }

        mutating func parseCircleBorder() throws(VError) -> NodeStyleLayout {
            let field = try fields(2)
            return .circleBorder(borderWidth: try number(field[0]), borderColor: try SemanticColor.fromString(field[1]))
        }

        mutating func parsePadded() throws(VError) -> NodeStyleLayout {
            let insets = try VEdgeInsets.fromString(try field())
            let layout = try parseLayout()
            try expect("}")
            return .padded(insets, layout)
        }

        mutating func parseBackground() throws(VError) -> NodeStyleLayout {
            let background = try NodeBackground.fromString(try field())
            let layout = try parseLayout()
            try expect("}")
            return .background(background, layout)
        }

        mutating func parseSized() throws(VError) -> NodeStyleLayout {
            let multiplier = try number(try field())
            let layout = try parseLayout()
            try expect("}")
            return .sized(multiplier: multiplier, layout)
        }

        mutating func parseVertical() throws(VError) -> NodeStyleLayout {
            let spacing = try number(try field())
            let layouts = try parseLayoutList()
            try expect("}")
            return .vertical(layouts, spacing: spacing)
        }

        mutating func parseHorizontal() throws(VError) -> NodeStyleLayout {
            let spacing = try number(try field())
            let layouts = try parseLayoutList()
            try expect("}")
            return .horizontal(layouts, spacing: spacing)
        }

        mutating func parseOverlay() throws(VError) -> NodeStyleLayout {
            let base = try parseLayout()
            try expect("|")
            let overlay = try parseLayout()
            try expect("}")
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
            let field = try fields(2)
            return .accentBar(width: try number(field[0]), color: try SemanticColor.fromString(field[1]))
        }

        mutating func parseTypeLabel() throws(VError) -> NodeStyleLayout {
            let field = try fields(3)
            return .typeLabel(
                text: field[0], font: try VFont.fromString(field[1]), color: try SemanticColor.fromString(field[2]))
        }

        mutating func parseTypeBadge() throws(VError) -> NodeStyleLayout {
            let field = try fields(3)
            return .typeBadge(icon: field[0], typeLabel: field[1], color: try SemanticColor.fromString(field[2]))
        }

        mutating func parseDashedFrame() throws(VError) -> NodeStyleLayout {
            let field = try fields(4)
            return .dashedFrame(
                cornerRadius: try number(field[0]), borderWidth: try number(field[1]),
                borderColor: try SemanticColor.fromString(field[2]), dashPattern: field[3])
        }

        mutating func parseSubtitleText() throws(VError) -> NodeStyleLayout {
            let field = try fields(2)
            return .subtitleText(text: field[0], color: try SemanticColor.fromString(field[1]))
        }

        mutating func parsePillBadge() throws(VError) -> NodeStyleLayout {
            let field = try fields(3)
            return .pillBadge(
                text: field[0], fill: try SemanticColor.fromString(field[1]),
                textColor: try SemanticColor.fromString(field[2]))
        }

        mutating func parseStackedShadow() throws(VError) -> NodeStyleLayout {
            let field = try fields(5)
            return .stackedShadow(
                cornerRadius: try number(field[0]), borderWidth: try number(field[1]),
                fill: try SemanticColor.fromString(field[2]), border: try SemanticColor.fromString(field[3]),
                dash: field[4])
        }

        mutating func parseCircleContent() throws(VError) -> NodeStyleLayout {
            let field = try fields(3)
            return .circleContent(
                try CircleContent.fromString(field[0]), font: try VFont.fromString(field[1]),
                color: try SemanticColor.fromString(field[2]))
        }

        /// Steps past `tag` when the text continues with it.
        mutating func consume(_ tag: String) -> Bool {
            guard peek(count: tag.count) == tag else { return false }
            advance(count: tag.count)
            return true
        }

        /// A leaf's `|`-separated fields, through its closing brace.
        mutating func fields(_ count: Int) throws(VError) -> [String] {
            var result: [String] = []
            for _ in 1..<count { result.append(try field()) }
            result.append(try readUntil("}"))
            advance(count: 1)
            return result
        }

        mutating func soleField() throws(VError) -> String {
            try fields(1)[0]
        }

        /// The text up to the next `|`, which is stepped past.
        mutating func field() throws(VError) -> String {
            let value = try readUntil("|")
            advance(count: 1)
            return value
        }

        func number(_ text: String) throws(VError) -> Double {
            guard let value = Double(text) else {
                throw VError.conversionError(from: string, to: "NodeStyleLayout")
            }
            return value
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

        mutating func expect(_ char: String) throws(VError) {
            skipWhitespace()
            guard peek() == char else {
                throw VError.parsingError("NodeStyleLayout: expected '\(char)' in '\(string)'")
            }
            advance(count: 1)
        }

        func peek(count: Int = 1) -> String {
            guard index < string.endIndex else { return "" }
            let end = string.index(index, offsetBy: count, limitedBy: string.endIndex) ?? string.endIndex
            return String(string[index..<end])
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
