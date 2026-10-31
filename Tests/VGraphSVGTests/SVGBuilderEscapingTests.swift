// ADR-0015 accepts two SVG backends. The IR one escaped attribute values and
// the string one interpolated raw, so whether a value could break out of its
// attribute depended on which backend happened to render it.

import Testing
import VGraph

@testable import VGraphSVG

@Suite("The string backend escapes what the IR backend escapes")
struct SVGBuilderEscapingTests {

    private static let hostile = #"M0 0" onload="alert(1)"#

    @Test("Path data cannot break out of its attribute")
    func pathDataIsEscaped() {
        let svg = SVGBuilder.path(d: Self.hostile)

        #expect(!svg.contains("onload=\"alert(1)\""))
        #expect(svg.contains("&quot;"))
    }

    /// The point is not that each escapes, but that they escape *the same* —
    /// which is why this calls the IR's own function rather than a second table.
    @Test(
        "Both backends spell an attribute value identically",
        arguments: [#"M0 0" x="#, "a & b", "<tspan>", "'DM Sans', Helvetica, sans-serif"])
    func theTwoBackendsAgree(_ value: String) {
        let fromString = SVGBuilder.path(d: value)
        let fromIR = VSVGNode.element(.path, [VSVGAttribute("d", value)]).render()

        #expect(fromString.contains("d=\"\(VSVGNode.escapeAttribute(value))\""))
        #expect(fromIR.contains("d=\"\(VSVGNode.escapeAttribute(value))\""))
    }

    @Test("A group's id, class and transform are escaped")
    func groupAttributesAreEscaped() {
        let svg = SVGBuilder.group(
            id: #"a" onclick="x"#, cssClass: #"b" onclick="y"#, transform: #"c" onclick="z"#, content: "")

        #expect(!svg.contains("onclick=\"x\""))
        #expect(!svg.contains("onclick=\"y\""))
        #expect(!svg.contains("onclick=\"z\""))
    }

    @Test("Polygon points and a dash array are escaped")
    func otherStringAttributesAreEscaped() {
        let polygon = SVGBuilder.polygon(points: Self.hostile)
        let dashed = SVGBuilder.path(d: "M0 0", strokeDashArray: #"5,3" onload="q"#)

        #expect(!polygon.contains("onload=\"alert(1)\""))
        #expect(!dashed.contains("onload=\"q\""))
    }

    /// Escaping `'` would mangle every `font-family`, and a single quote cannot
    /// terminate a double-quoted value anyway — so the narrower rule is the
    /// right one to share, and this is the regression guard on it.
    @Test("A font family keeps its single quotes")
    func singleQuotesSurvive() {
        let svg = SVGBuilder.text(x: 0, y: 0, content: "Hi", font: VFont(size: 14), color: VColor.black)

        #expect(svg.contains("'"), "font-family names are single-quoted and must stay that way")
        #expect(!svg.contains("&apos;"))
    }
}
