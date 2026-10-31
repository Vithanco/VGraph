import VGraph

public struct SVGBuilder {

    // MARK: - Number Formatting

    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return "\(value)"
    }

    // The two halves of the embedded-VGL envelope, shared by `embedVGL` and
    // `extractVGL` so the writer and the reader cannot drift apart.
    //
    // The wrapper element is prefixed because the root declares the SVG
    // namespace as the default one: an unprefixed `<vgl>` would not be ours at
    // all, it would be an element we invented inside W3C's namespace, which the
    // SVG spec calls an error. `<metadata>` holding foreign namespaced content
    // is the extension mechanism SVG actually offers, and `version` is where a
    // future change to the payload format gets handled.
    //
    // The declaration rides on the element rather than on the root tag so that
    // the envelope stays self-contained: ADR-0015 admits two backends and only
    // one of them mints the root, so a prefix declared there would be undeclared
    // — a hard XML error — in output from the other.
    //
    // The namespace URI is frozen. It is an identifier, not an address — nothing
    // fetches it, and it need not resolve — but it is baked into every saved
    // diagram, and namespaces compare byte-for-byte: `http` and `https` spellings
    // are two different namespaces, so "modernising" it would silently split the
    // format in two and cost `extractVGL` a third read path. A change to the
    // payload format belongs in `version`, which is there so this string never
    // has to move.
    private static let vglMetadataOpen =
        #"<metadata><vithanco:vgl xmlns:vithanco="https://vithanco.com/ns/vgl" version="1"><![CDATA["#
    private static let vglMetadataClose = "]]></vithanco:vgl></metadata>"

    // The unnamespaced envelope this one replaced. Read-only: diagrams saved by
    // earlier versions have to keep opening.
    private static let legacyMetadataOpen = "<metadata><vgl><![CDATA["
    private static let legacyMetadataClose = "]]></vgl></metadata>"

    // A `]]>` in the payload would end the CDATA section early and leave an SVG
    // no XML parser will open — not a mangled diagram, an unopenable file. The
    // only escape CDATA has is to close the section and reopen it around the
    // offending `>`.
    private static let cdataTerminator = "]]>"
    private static let cdataTerminatorSplit = "]]]]><![CDATA[>"

    public static func embedVGL(_ vgl: String, in svg: String) -> String {
        let payload = replacing(cdataTerminator, with: cdataTerminatorSplit, in: vgl)
        let metadata = vglMetadataOpen + payload + vglMetadataClose
        guard let closeAngle = svg.firstIndex(of: ">") else { return svg }
        var result = svg
        result.insert(contentsOf: metadata, at: svg.index(after: closeAngle))
        return result
    }

    /// The inverse of ``embedVGL(_:in:)`` — what makes a saved diagram
    /// re-openable as a document rather than a picture.
    public static func extractVGL(from svg: String) -> String? {
        if let payload = payload(from: svg, between: vglMetadataOpen, and: vglMetadataClose) {
            return replacing(cdataTerminatorSplit, with: cdataTerminator, in: payload)
        }
        // Legacy payloads were spliced in raw, so there is nothing to unsplit —
        // one carrying `]]>` never made it to disk as readable XML anyway.
        return payload(from: svg, between: legacyMetadataOpen, and: legacyMetadataClose)
    }

    private static func payload(from svg: String, between open: String, and close: String)
        -> String?
    {
        guard let open = firstRange(of: open, in: svg, from: svg.startIndex),
            let close = firstRange(of: close, in: svg, from: open.upperBound)
        else { return nil }
        return String(svg[open.upperBound..<close.lowerBound])
    }

    /// Leftmost-first, non-overlapping replacement, hand-rolled for the same
    /// reason as ``firstRange(of:in:from:)``: no Foundation under Embedded Swift.
    private static func replacing(_ needle: String, with replacement: String, in haystack: String)
        -> String
    {
        var result = ""
        var cursor = haystack.startIndex
        while let found = firstRange(of: needle, in: haystack, from: cursor) {
            result += haystack[cursor..<found.lowerBound]
            result += replacement
            cursor = found.upperBound
        }
        result += haystack[cursor...]
        return result
    }

    /// Substring search, hand-rolled because this file is compiled for Embedded
    /// Swift too, where neither Foundation's `range(of:)` nor the
    /// `_StringProcessing` collection algorithms exist.
    ///
    /// Compares UTF-8 rather than `Character`s for speed over a whole SVG. That
    /// is safe for a match's *boundaries* only because every marker here is
    /// ASCII, and an ASCII byte can never occur inside a multi-byte sequence —
    /// so a match can only ever begin and end on a character boundary.
    private static func firstRange(
        of needle: String, in haystack: String, from start: String.Index
    ) -> Range<String.Index>? {
        let needleBytes = needle.utf8
        let haystackBytes = haystack.utf8
        guard !needleBytes.isEmpty else { return nil }

        var candidate = start
        while candidate < haystack.endIndex {
            var here = candidate
            var wanted = needleBytes.startIndex
            while wanted < needleBytes.endIndex, here < haystack.endIndex,
                haystackBytes[here] == needleBytes[wanted]
            {
                here = haystackBytes.index(after: here)
                wanted = needleBytes.index(after: wanted)
            }
            if wanted == needleBytes.endIndex { return candidate..<here }
            candidate = haystackBytes.index(after: candidate)
        }
        return nil
    }

    /// ADR-0015 accepts two backends, so this calls the IR one's rule rather than
    /// restating it: a value safe through one and not the other is an accident of
    /// which ran. Numbers and colours skip it — `format` and `hexString` cannot
    /// produce a character that means anything in markup.
    static func attr(_ value: String) -> String {
        VSVGNode.escapeAttribute(value)
    }

    // MARK: - Group

    public static func group(id: String? = nil, cssClass: String? = nil, transform: String? = nil, content: String) -> String {
        var attrs = ""
        if let id = id {
            attrs += " id=\"\(attr(id))\""
        }
        if let cssClass = cssClass {
            attrs += " class=\"\(attr(cssClass))\""
        }
        if let transform = transform {
            attrs += " transform=\"\(attr(transform))\""
        }
        return "<g\(attrs)>\(content)</g>"
    }

    /// Interactive hover styles baked into every SVG. Pure CSS `:hover` so it works
    /// inline everywhere (website, VS Code, Obsidian) with no host JS, and is inert
    /// for PNG export. Neighbour re-brightening (`renderNeighborHoverStyles`) relies
    /// on id-level selectors outranking the class-level dim rule defined here.
    public static func hoverStylesCSS() -> String {
        return """
            .vgraph-node, .vgraph-edge, .vgraph-group > rect { transition: opacity 0.12s ease-out, filter 0.12s ease-out; }
            .vgraph-node, .vgraph-edge, .loop-indicator { cursor: pointer; }
            svg:has(.vgraph-node:hover, .vgraph-edge:hover, .loop-indicator:hover) .vgraph-node,
            svg:has(.vgraph-node:hover, .vgraph-edge:hover, .loop-indicator:hover) .vgraph-edge { opacity: 0.15; }
            .vgraph-node:hover, .vgraph-edge:hover { opacity: 1 !important; }
            .vgraph-node:hover { filter: drop-shadow(0 0 10px rgba(59,130,246,0.95)) drop-shadow(0 0 3px rgba(59,130,246,1)); }
            .vgraph-edge:hover { filter: drop-shadow(0 0 9px rgba(59,130,246,0.95)); }
            .vgraph-edge:hover path { stroke: #3b82f6; stroke-width: 4; }
            .vgraph-edge:hover polygon, .vgraph-edge:hover ellipse, .vgraph-edge:hover circle { fill: #3b82f6; stroke: #3b82f6; }
            .vgraph-group:hover > rect { filter: drop-shadow(0 0 8px rgba(59,130,246,0.85)); stroke: #3b82f6; }
            .vgraph-url-badge { cursor: pointer; }
            .vgraph-url-badge:hover { opacity: 0.75; }
            """
    }

    // MARK: - Basic Shapes

    public static func rect(
        x: Double, y: Double, width: Double, height: Double, rx: Double = 0, fill: VColor? = nil, stroke: VColor? = nil,
        strokeWidth: Double = 0, strokeDashArray: String? = nil
    ) -> String {
        var attrs = "x=\"\(format(x))\" y=\"\(format(y))\" width=\"\(format(width))\" height=\"\(format(height))\""
        if rx > 0 {
            attrs += " rx=\"\(format(rx))\""
        }
        if let fill = fill {
            attrs += " fill=\"\(fill.hexString)\""
            if fill.alphaComponent < 1.0 {
                attrs += " fill-opacity=\"\(format(fill.alphaComponent))\""
            }
        } else {
            attrs += " fill=\"none\""
        }
        if let stroke = stroke, strokeWidth > 0 {
            attrs += " stroke=\"\(stroke.hexString)\" stroke-width=\"\(format(strokeWidth))\""
            if stroke.alphaComponent < 1.0 {
                attrs += " stroke-opacity=\"\(format(stroke.alphaComponent))\""
            }
        }
        if let dash = strokeDashArray {
            attrs += " stroke-dasharray=\"\(attr(dash))\""
        }
        return "<rect \(attrs)/>"
    }

    public static func circle(
        cx: Double, cy: Double, r: Double, fill: VColor? = nil, stroke: VColor? = nil, strokeWidth: Double = 0
    ) -> String {
        var attrs = "cx=\"\(format(cx))\" cy=\"\(format(cy))\" r=\"\(format(r))\""
        if let fill = fill {
            attrs += " fill=\"\(fill.hexString)\""
            if fill.alphaComponent < 1.0 {
                attrs += " fill-opacity=\"\(format(fill.alphaComponent))\""
            }
        } else {
            attrs += " fill=\"none\""
        }
        if let stroke = stroke, strokeWidth > 0 {
            attrs += " stroke=\"\(stroke.hexString)\" stroke-width=\"\(format(strokeWidth))\""
            if stroke.alphaComponent < 1.0 {
                attrs += " stroke-opacity=\"\(format(stroke.alphaComponent))\""
            }
        }
        return "<circle \(attrs)/>"
    }

    public static func ellipse(
        cx: Double, cy: Double, rx: Double, ry: Double, fill: VColor? = nil, stroke: VColor? = nil,
        strokeWidth: Double = 0
    ) -> String {
        var attrs = "cx=\"\(format(cx))\" cy=\"\(format(cy))\" rx=\"\(format(rx))\" ry=\"\(format(ry))\""
        if let fill = fill {
            attrs += " fill=\"\(fill.hexString)\""
            if fill.alphaComponent < 1.0 {
                attrs += " fill-opacity=\"\(format(fill.alphaComponent))\""
            }
        } else {
            attrs += " fill=\"none\""
        }
        if let stroke = stroke, strokeWidth > 0 {
            attrs += " stroke=\"\(stroke.hexString)\" stroke-width=\"\(format(strokeWidth))\""
            if stroke.alphaComponent < 1.0 {
                attrs += " stroke-opacity=\"\(format(stroke.alphaComponent))\""
            }
        }
        return "<ellipse \(attrs)/>"
    }

    public static func path(
        d: String, fill: VColor? = nil, stroke: VColor? = nil, strokeWidth: Double = 0, strokeDashArray: String? = nil
    ) -> String {
        var attrs = "d=\"\(attr(d))\""
        if let fill = fill {
            attrs += " fill=\"\(fill.hexString)\""
            if fill.alphaComponent < 1.0 {
                attrs += " fill-opacity=\"\(format(fill.alphaComponent))\""
            }
        } else {
            attrs += " fill=\"none\""
        }
        if let stroke = stroke, strokeWidth > 0 {
            attrs += " stroke=\"\(stroke.hexString)\" stroke-width=\"\(format(strokeWidth))\""
            if stroke.alphaComponent < 1.0 {
                attrs += " stroke-opacity=\"\(format(stroke.alphaComponent))\""
            }
        }
        if let dashArray = strokeDashArray {
            attrs += " stroke-dasharray=\"\(attr(dashArray))\""
        }
        return "<path \(attrs)/>"
    }

    public static func polygon(points: String, fill: VColor? = nil, stroke: VColor? = nil, strokeWidth: Double = 0)
        -> String
    {
        var attrs = "points=\"\(attr(points))\""
        if let fill = fill {
            attrs += " fill=\"\(fill.hexString)\""
            if fill.alphaComponent < 1.0 {
                attrs += " fill-opacity=\"\(format(fill.alphaComponent))\""
            }
        } else {
            attrs += " fill=\"none\""
        }
        if let stroke = stroke, strokeWidth > 0 {
            attrs += " stroke=\"\(stroke.hexString)\" stroke-width=\"\(format(strokeWidth))\""
            if stroke.alphaComponent < 1.0 {
                attrs += " stroke-opacity=\"\(format(stroke.alphaComponent))\""
            }
        }
        return "<polygon \(attrs)/>"
    }

    // MARK: - Text

    public static func text(
        x: Double, y: Double, content: String, font: VFont, color: VColor, anchor: String = "middle",
        fontWeight: Int = 400, fontStyle: String = "normal", opacity: Double = 1.0,
        letterSpacing: String? = nil, cssClass: String? = nil
    ) -> String {
        var attrs =
            "x=\"\(format(x))\" y=\"\(format(y))\" text-anchor=\"\(attr(anchor))\" fill=\"\(color.hexString)\" font-size=\"\(format(font.size))\" font-family=\"\(attr(font.svgName))\""
        if let cssClass {
            attrs += " class=\"\(attr(cssClass))\""
        }
        if color.alphaComponent < 1.0 {
            attrs += " fill-opacity=\"\(format(color.alphaComponent))\""
        }
        if fontWeight != 400 {
            attrs += " font-weight=\"\(fontWeight)\""
        }
        if fontStyle != "normal" {
            attrs += " font-style=\"\(attr(fontStyle))\""
        }
        if opacity < 1.0 {
            attrs += " opacity=\"\(format(opacity))\""
        }
        if let ls = letterSpacing {
            attrs += " letter-spacing=\"\(attr(ls))\""
        }
        let escapedContent = escapeXML(content)
        return "<text \(attrs)>\(escapedContent)</text>"
    }

    /// The query separator is a literal `&` and must stay one: escaping it here
    /// would double-escape on the way out and reach a mounted `<style>` intact.
    /// See VSVGDefsTests.theFontImportURLIsEscapedForXMLButNotOverEscaped.
    public static func dmSansFontImportCSS() -> String {
        return
            "@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400&display=swap');"
    }

    public static func multilineText(
        x: Double, y: Double, lines: [String], font: VFont, color: VColor, lineHeight: Double, anchor: String = "middle"
    ) -> String {
        var attrs =
            "x=\"\(format(x))\" y=\"\(format(y))\" text-anchor=\"\(attr(anchor))\" fill=\"\(color.hexString)\" font-size=\"\(format(font.size))\" font-family=\"\(attr(font.svgName))\""
        if color.alphaComponent < 1.0 {
            attrs += " fill-opacity=\"\(format(color.alphaComponent))\""
        }

        var tspans = ""
        for (index, line) in lines.enumerated() {
            let dy = index == 0 ? 0 : lineHeight
            let escapedLine = escapeXML(line)
            tspans += "<tspan x=\"\(format(x))\" dy=\"\(format(dy))\">\(escapedLine)</tspan>"
        }

        return "<text \(attrs)>\(tspans)</text>"
    }

    // MARK: - Helpers

    public static func translate(x: Double, y: Double) -> String {
        return "translate(\(format(x)),\(format(y)))"
    }

    /// Builds one hover rule for `scope`. `edgeIds` get the `edge-` selector prefix;
    /// `nodeElementIds` are finished element ids, from `SVGElementId.displayNode`,
    /// since a folded group's box is not stamped as a node; `rawIds` are used
    /// verbatim. `opacity:1` is required to outrank the spotlight dim in
    /// `hoverStyles()`.
    public static func neighborGlowRule(
        scope: String, edgeIds: [String], nodeElementIds: [String], rawIds: [String] = []
    ) -> String {
        let glow = "{opacity:1;filter:drop-shadow(0 0 8px rgba(59,130,246,0.9));}"
        var glowTargets: [String] = []
        var seen = Set<String>()
        for e in edgeIds where seen.insert("e" + e).inserted {
            glowTargets.append(scope + "#\(cssEscapeIdent(SVGElementId.edge(e)))")
        }
        for n in nodeElementIds where seen.insert("n" + n).inserted {
            glowTargets.append(scope + "#\(cssEscapeIdent(n))")
        }
        for id in rawIds where seen.insert("r" + id).inserted {
            glowTargets.append(scope + "#\(cssEscapeIdent(id))")
        }
        if glowTargets.isEmpty { return "" }

        var rule = glowTargets.joined(separator: ",") + glow + "\n"

        var edgeSeen = Set<String>()
        var lineTargets: [String] = []
        var arrowTargets: [String] = []
        for e in edgeIds where edgeSeen.insert(e).inserted {
            let sel = scope + "#\(cssEscapeIdent(SVGElementId.edge(e)))"
            lineTargets.append(sel + " path")
            arrowTargets.append(sel + " polygon")
            arrowTargets.append(sel + " ellipse")
            arrowTargets.append(sel + " circle")
        }
        if !lineTargets.isEmpty {
            rule += lineTargets.joined(separator: ",") + "{stroke:#3b82f6;stroke-width:3;}\n"
            rule += arrowTargets.joined(separator: ",") + "{fill:#3b82f6;stroke:#3b82f6;}\n"
        }
        return rule
    }

    /// Escape a string for use in a CSS id selector (`#…`). Embedded-Swift safe:
    /// integer scalar comparisons only, no Unicode-property APIs (`.isLetter` etc.).
    public static func cssEscapeIdent(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            let v = scalar.value
            let isDigit = v >= 48 && v <= 57
            let isUpper = v >= 65 && v <= 90
            let isLower = v >= 97 && v <= 122
            let isDashOrUnderscore = (v == 45 || v == 95)
            if isDigit || isUpper || isLower || isDashOrUnderscore {
                result.unicodeScalars.append(scalar)
            } else {
                result += "\\"
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// Text content, not an attribute: the wider rule, and the IR backend's own
    /// so the two cannot drift.
    private static func escapeXML(_ string: String) -> String {
        VSVGNode.escape(string)
    }
}
