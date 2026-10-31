/// `.plain` means "emit as plain text, no span".
public enum VGLTokenRole: Sendable, Equatable {
    case keyword
    case string
    case comment
    case number
    case punctuation
    case notation
    case nodeType
    case unknownType
    case unknownId
    case edgeType
    case groupType
    case nodeId
    case attrKey
    case attrValue
    case syntaxError
    case diagError
    case diagWarning
    case plain

    public var cssClass: String {
        switch self {
        case .keyword: return "vg-kw"
        case .string: return "vg-str"
        case .comment: return "vg-comment"
        case .number: return "vg-num"
        case .punctuation: return "vg-punct"
        case .notation: return "vg-notation"
        case .nodeType, .edgeType, .groupType: return "vg-type"
        case .unknownType, .unknownId: return "vg-error"
        case .nodeId: return "vg-id"
        case .attrKey: return "vg-attr"
        case .attrValue: return "vg-val"
        case .syntaxError: return "vg-syntax-error"
        case .diagError: return "vg-diag-error"
        case .diagWarning: return "vg-diag-warn"
        case .plain: return ""
        }
    }
}

/// `start`/`length` are **character** indices into `Array(source)` (matching `Token`).
public struct VGLSemanticToken: Sendable, Equatable {
    public let start: Int
    public let length: Int
    public let role: VGLTokenRole
    public let title: String?

    public init(start: Int, length: Int, role: VGLTokenRole, title: String? = nil) {
        self.start = start
        self.length = length
        self.role = role
        self.title = title
    }
}

// MARK: - Token → role classification

/// `.identifier` stays `.plain`; its role comes from the name check or parser side-table.
func baseRole(for type: TokenType) -> VGLTokenRole {
    switch type {
    case .vgraph, .vview, .vnotation, .metagraph, .metadescription, .group, .folded, .node, .edge:
        return .keyword
    case .label:
        return .string
    case .number:
        return .number
    case .colon, .comma, .semicolon, .leftBrace, .rightBrace,
        .leftBracket, .rightBracket, .leftParen, .rightParen, .arrow:
        return .punctuation
    case .identifier, .type, .value, .eof, .unknown:
        return .plain
    }
}

/// Read as keywords but lexed as plain identifiers, so not caught by `baseRole`.
let vglSoftKeywords: Set<String> = [
    "extends", "type", "from", "to", "layout",
    "topToBottom", "leftToRight", "bottomToTop", "rightToLeft",
    "qualityCheck", "transform",
]

func classifyLexical(tokens: [Token], notationNames: Set<String>) -> [VGLSemanticToken] {
    var out: [VGLSemanticToken] = []
    for t in tokens where t.type != .eof {
        var role = baseRole(for: t.type)
        if t.type == .identifier {
            if notationNames.contains(t.lexeme) {
                role = .notation
            } else if vglSoftKeywords.contains(t.lexeme) {
                role = .keyword
            } else {
                role = .plain
            }
        }
        if role != .plain {
            out.append(VGLSemanticToken(start: t.start, length: t.end - t.start, role: role))
        }
    }
    return out
}

/// `idRoles` keys identifier tokens by start offset. A `.nodeType` not in
/// `validNodeTypeNames` (when non-nil) is downgraded to `.unknownType`.
func classifySemantic(
    tokens: [Token],
    idRoles: [Int: VGLTokenRole],
    validNodeTypeNames: Set<String>?,
    validGroupTypeNames: Set<String>? = nil,
    groupTypeSlots: Set<Int> = [],
    iconNames: [Int: String] = [:],
    validIconNames: Set<String>? = nil,
    viewNames: [Int: (name: String, isGroup: Bool)] = [:],
    knownNodeIds: Set<String>? = nil,
    knownGroupIds: Set<String>? = nil
) -> [VGLSemanticToken] {
    var out: [VGLSemanticToken] = []
    for t in tokens where t.type != .eof {
        var role = baseRole(for: t.type)
        if let name = iconNames[t.start], let valid = validIconNames, !valid.contains(name) {
            role = .unknownType
        }
        var title: String?
        if t.type == .identifier {
            if let resolved = idRoles[t.start] {
                role = resolved
                if let viewName = viewNames[t.start],
                    let known = viewName.isGroup ? knownGroupIds : knownNodeIds, !known.contains(t.lexeme)
                {
                    role = .unknownId
                    title = "not in the model"
                }
                if role == .nodeType, let valid = validNodeTypeNames, !valid.contains(t.lexeme) {
                    role = .unknownType
                }
                if role == .groupType, let valid = validGroupTypeNames, !valid.contains(t.lexeme) {
                    let detailsANode =
                        groupTypeSlots.contains(t.start) && validNodeTypeNames?.contains(t.lexeme) == true
                    if !detailsANode { role = .unknownType }
                }
            } else {
                role = .plain
            }
        }
        if role != .plain {
            out.append(VGLSemanticToken(start: t.start, length: t.end - t.start, role: role, title: title))
        }
    }
    return out
}

// MARK: - HTML building

private func htmlEscape(_ chars: ArraySlice<Character>) -> String {
    var out = ""
    out.reserveCapacity(chars.count)
    for c in chars {
        switch c {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        default: out.append(c)
        }
    }
    return out
}

/// Comments are kept out of the token stream (see `Lexer.comments`), so recover
/// `//`→end-of-line runs here as `vg-comment`.
private func appendPlainGap(_ chars: [Character], _ lo: Int, _ hi: Int, into html: inout String) {
    var i = lo
    var plainStart = lo
    while i < hi {
        if chars[i] == "/" && i + 1 < hi && chars[i + 1] == "/" {
            if i > plainStart { html += htmlEscape(chars[plainStart..<i]) }
            var j = i
            while j < hi && chars[j] != "\n" { j += 1 }
            html += "<span class=\"vg-comment\">" + htmlEscape(chars[i..<j]) + "</span>"
            i = j
            plainStart = j
        } else {
            i += 1
        }
    }
    if hi > plainStart { html += htmlEscape(chars[plainStart..<hi]) }
}

private func htmlAttrEscape(_ s: String) -> String {
    var out = ""
    out.reserveCapacity(s.count)
    for c in s {
        switch c {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(c)
        }
    }
    return out
}

/// `tokens` are flat leaf spans; `markers` are diagnostic regions that wrap whole
/// tokens with a tooltip. Reconstructs the source verbatim. Markers must be
/// token-aligned; a marker overlapping an already-kept one is dropped (flat spans
/// can't nest — the finding still shows in the diagnostics box).
func buildHighlightHTML(
    source: String,
    tokens: [VGLSemanticToken],
    markers: [VGLSemanticToken] = []
) -> String {
    let chars = Array(source)
    let leafs = tokens.sorted { $0.start < $1.start }

    var keptMarkers: [VGLSemanticToken] = []
    var lastMarkerEnd = 0
    for m in markers.sorted(by: { $0.start < $1.start }) where m.length > 0 {
        if m.start >= lastMarkerEnd {
            keptMarkers.append(m)
            lastMarkerEnd = m.start + m.length
        }
    }

    var html = ""
    var li = 0

    // `li` advances monotonically across calls (leafs are sorted, ranges disjoint).
    func emitFlat(_ lo: Int, _ hi: Int) {
        var cursor = lo
        while li < leafs.count, leafs[li].start < hi {
            let leaf = leafs[li]
            let start = leaf.start
            let end = min(leaf.start + leaf.length, hi)
            guard start >= cursor, end >= start else {
                li += 1
                continue
            }
            if start > cursor { appendPlainGap(chars, cursor, start, into: &html) }
            let title = leaf.title.map { " title=\"\(htmlAttrEscape($0))\"" } ?? ""
            html += "<span class=\"\(leaf.role.cssClass)\"\(title)>" + htmlEscape(chars[start..<end]) + "</span>"
            cursor = end
            li += 1
        }
        if cursor < hi { appendPlainGap(chars, cursor, hi, into: &html) }
    }

    var cursor = 0
    var mi = 0
    while cursor < chars.count {
        if mi < keptMarkers.count, keptMarkers[mi].start == cursor {
            let m = keptMarkers[mi]
            mi += 1
            let end = min(m.start + m.length, chars.count)
            let title = m.title.map { " title=\"\(htmlAttrEscape($0))\"" } ?? ""
            html += "<span class=\"\(m.role.cssClass)\"\(title)>"
            emitFlat(m.start, end)
            html += "</span>"
            cursor = end
        } else {
            let nextStop = mi < keptMarkers.count ? keptMarkers[mi].start : chars.count
            emitFlat(cursor, nextStop)
            cursor = nextStop
        }
    }
    return html
}
