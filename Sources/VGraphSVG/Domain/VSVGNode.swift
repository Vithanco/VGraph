// Why this exists rather than Elementary's SVG types: docs/adr/0015.

import VGraph

public struct VSVGAttribute: Sendable, Equatable {
    public let name: String
    public let value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// Closed, not a `String`: the mounting adapter needs one statically-typed view
/// per tag and cannot accept an open set.
public enum VSVGTag: Sendable, Equatable, CaseIterable {
    case svg, g, defs, style, symbol, use, marker
    case rect, circle, ellipse, path, polygon, polyline, line
    case text, tspan, title
    case a
    case linearGradient, radialGradient, stop, image, clipPath, mask

    public var name: String {
        switch self {
        case .svg: return "svg"
        case .g: return "g"
        case .defs: return "defs"
        case .style: return "style"
        case .symbol: return "symbol"
        case .use: return "use"
        case .marker: return "marker"
        case .rect: return "rect"
        case .circle: return "circle"
        case .ellipse: return "ellipse"
        case .path: return "path"
        case .polygon: return "polygon"
        case .polyline: return "polyline"
        case .line: return "line"
        case .text: return "text"
        case .tspan: return "tspan"
        case .title: return "title"
        case .a: return "a"
        case .linearGradient: return "linearGradient"
        case .radialGradient: return "radialGradient"
        case .stop: return "stop"
        case .image: return "image"
        case .clipPath: return "clipPath"
        case .mask: return "mask"
        }
    }

    /// Selects ``VSVGNode/escapeStyleText(_:)`` over ``VSVGNode/escape(_:)``.
    var holdsCSS: Bool {
        switch self {
        case .style: return true
        default: return false
        }
    }
}

public indirect enum VSVGNode: Sendable {
    case element(VSVGTag, [VSVGAttribute], [VSVGNode])
    case text(String)
    /// Unescaped, and — unlike every other case — **not mountable**: the
    /// reconciler cannot diff opaque markup (ADR-0015 blocker 4), so anything
    /// built this way is a hole in the editor mount. Nothing in `VGraphSVG`
    /// constructs one; reach for it only with a reason that survives the mount.
    case raw(String)
    case fragment([VSVGNode])
    case empty

    public static func element(_ tag: VSVGTag, _ attributes: [VSVGAttribute] = []) -> VSVGNode {
        .element(tag, attributes, [])
    }
}

extension VSVGNode {
    /// Emits nothing — which `[.empty].isEmpty` does not tell you, and callers
    /// deciding whether to wrap children in a `<g>` need to know.
    public var isEmpty: Bool {
        switch self {
        case .empty: return true
        // A closure, not `\.isEmpty`: Embedded Swift has no key paths.
        case .fragment(let children): return children.allSatisfy { $0.isEmpty }
        case .text(let content), .raw(let content): return content.isEmpty
        case .element: return false
        }
    }
}

// MARK: - Emitting

extension VSVGNode {
    public func render() -> String {
        var output = ""
        emit(into: &output)
        return output
    }

    private func emit(into output: inout String) {
        switch self {
        case .element(let tag, let attributes, let children):
            output += "<" + tag.name
            for attribute in attributes {
                output += " " + attribute.name + "=\"" + VSVGNode.escapeAttribute(attribute.value) + "\""
            }
            if children.isEmpty {
                output += "/>"
                return
            }
            output += ">"
            for child in children {
                if tag.holdsCSS, case .text(let content) = child {
                    output += VSVGNode.escapeStyleText(content)
                } else {
                    child.emit(into: &output)
                }
            }
            output += "</" + tag.name + ">"
        case .text(let content):
            output += VSVGNode.escape(content)
        case .raw(let content):
            output += content
        case .fragment(let children):
            for child in children {
                child.emit(into: &output)
            }
        case .empty:
            break
        }
    }

    /// Character comparisons only: Foundation is unavailable under Embedded Swift.
    public static func escape(_ string: String) -> String {
        var result = ""
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(character)
            }
        }
        return result
    }

    /// The minimal XML text escape, for CSS bodies. The surplus ``escape(_:)``
    /// adds is not merely redundant but harmful: a mounted `<style>` receives
    /// this text through `textContent`, which performs no unescaping, so `>`
    /// escaped beyond necessity reaches the CSS parser as literal `&gt;` and
    /// breaks `.vgraph-group > rect`. Serialised to a string the two agree,
    /// since XML and HTML foreign content both decode the references back.
    static func escapeStyleText(_ string: String) -> String {
        var result = ""
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Narrower than ``escape(_:)`` on purpose: escaping `'` would mangle every
    /// `font-family` and cannot terminate a double-quoted value anyway.
    public static func escapeAttribute(_ string: String) -> String {
        var result = ""
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }
}

// MARK: - Shape attributes

public struct VShapeStyle: Sendable {
    public var fill: VColor?
    public var stroke: VColor?
    public var strokeWidth: Double
    public var strokeDashArray: String?

    public init(
        fill: VColor? = nil,
        stroke: VColor? = nil,
        strokeWidth: Double = 0,
        strokeDashArray: String? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.strokeDashArray = strokeDashArray
    }
}

extension VShapeStyle {
    /// Absent fill emits `none`, not nothing: omitting it inherits the parent's.
    public func nodeAttributes() -> [VSVGAttribute] {
        var attributes: [VSVGAttribute] = []
        if let fill {
            attributes.append(VSVGAttribute("fill", fill.hexString))
            if fill.alphaComponent < 1.0 {
                attributes.append(VSVGAttribute("fill-opacity", SVGBuilder.format(fill.alphaComponent)))
            }
        } else {
            attributes.append(VSVGAttribute("fill", "none"))
        }
        if let stroke, strokeWidth > 0 {
            attributes.append(VSVGAttribute("stroke", stroke.hexString))
            attributes.append(VSVGAttribute("stroke-width", SVGBuilder.format(strokeWidth)))
            if stroke.alphaComponent < 1.0 {
                attributes.append(VSVGAttribute("stroke-opacity", SVGBuilder.format(stroke.alphaComponent)))
            }
        }
        if let strokeDashArray {
            attributes.append(VSVGAttribute("stroke-dasharray", strokeDashArray))
        }
        return attributes
    }
}

// MARK: - Primitives

public enum VSVGBuilder {
    static func number(_ value: Double) -> String { SVGBuilder.format(value) }

    public static func rect(
        x: Double, y: Double, width: Double, height: Double, rx: Double = 0, style: VShapeStyle = .init()
    ) -> VSVGNode {
        var attributes = [
            VSVGAttribute("x", number(x)), VSVGAttribute("y", number(y)),
            VSVGAttribute("width", number(width)), VSVGAttribute("height", number(height)),
        ]
        if rx > 0 { attributes.append(VSVGAttribute("rx", number(rx))) }
        return .element(.rect, attributes + style.nodeAttributes())
    }

    public static func circle(cx: Double, cy: Double, r: Double, style: VShapeStyle = .init()) -> VSVGNode {
        .element(
            .circle,
            [VSVGAttribute("cx", number(cx)), VSVGAttribute("cy", number(cy)), VSVGAttribute("r", number(r))]
                + style.nodeAttributes())
    }

    public static func ellipse(
        cx: Double, cy: Double, rx: Double, ry: Double, style: VShapeStyle = .init()
    ) -> VSVGNode {
        .element(
            .ellipse,
            [
                VSVGAttribute("cx", number(cx)), VSVGAttribute("cy", number(cy)),
                VSVGAttribute("rx", number(rx)), VSVGAttribute("ry", number(ry)),
            ] + style.nodeAttributes())
    }

    public static func path(d: String, style: VShapeStyle = .init()) -> VSVGNode {
        .element(.path, [VSVGAttribute("d", d)] + style.nodeAttributes())
    }

    public static func polygon(points: String, style: VShapeStyle = .init()) -> VSVGNode {
        .element(.polygon, [VSVGAttribute("points", points)] + style.nodeAttributes())
    }

    /// `cssClass` is threaded through rather than appended by the caller because
    /// `SVGBuilder` emits it *before* `fill-opacity`; appending both in order at
    /// the call site would swap them for a classed, translucent label.
    static func textAttributes(
        x: Double, y: Double, font: VFont, color: VColor, anchor: String, cssClass: String? = nil
    ) -> [VSVGAttribute] {
        var attributes = [
            VSVGAttribute("x", number(x)), VSVGAttribute("y", number(y)),
            VSVGAttribute("text-anchor", anchor), VSVGAttribute("fill", color.hexString),
            VSVGAttribute("font-size", number(font.size)), VSVGAttribute("font-family", font.svgName),
        ]
        if let cssClass { attributes.append(VSVGAttribute("class", cssClass)) }
        if color.alphaComponent < 1.0 {
            attributes.append(VSVGAttribute("fill-opacity", number(color.alphaComponent)))
        }
        return attributes
    }

    public static func text(
        x: Double, y: Double, content: String, font: VFont, color: VColor, anchor: String = "middle",
        fontWeight: Int = 400, fontStyle: String = "normal", opacity: Double = 1.0,
        letterSpacing: String? = nil, cssClass: String? = nil
    ) -> VSVGNode {
        var attributes = textAttributes(
            x: x, y: y, font: font, color: color, anchor: anchor, cssClass: cssClass)
        if fontWeight != 400 { attributes.append(VSVGAttribute("font-weight", "\(fontWeight)")) }
        if fontStyle != "normal" { attributes.append(VSVGAttribute("font-style", fontStyle)) }
        if opacity < 1.0 { attributes.append(VSVGAttribute("opacity", number(opacity))) }
        if let letterSpacing { attributes.append(VSVGAttribute("letter-spacing", letterSpacing)) }
        return .element(.text, attributes, [.text(content)])
    }

    public static func multilineText(
        x: Double, y: Double, lines: [String], font: VFont, color: VColor, lineHeight: Double,
        anchor: String = "middle"
    ) -> VSVGNode {
        let spans: [VSVGNode] = lines.enumerated().map { index, line in
            .element(
                .tspan,
                [VSVGAttribute("x", number(x)), VSVGAttribute("dy", number(index == 0 ? 0 : lineHeight))],
                [.text(line)])
        }
        return .element(.text, textAttributes(x: x, y: y, font: font, color: color, anchor: anchor), spans)
    }

    public static func style(css: String) -> VSVGNode {
        .element(.style, [], [.text(css)])
    }

    /// Prefer `transform` over x/y on the shapes inside: a re-layout then patches
    /// one attribute, which the browser can animate.
    public static func group(
        id: String? = nil, cssClass: String? = nil, transform: String? = nil, children: [VSVGNode]
    ) -> VSVGNode {
        var attributes: [VSVGAttribute] = []
        if let id { attributes.append(VSVGAttribute("id", id)) }
        if let cssClass { attributes.append(VSVGAttribute("class", cssClass)) }
        if let transform { attributes.append(VSVGAttribute("transform", transform)) }
        return .element(.g, attributes, children)
    }

    public static func translate(x: Double, y: Double) -> String {
        "translate(\(number(x)),\(number(y)))"
    }
}
