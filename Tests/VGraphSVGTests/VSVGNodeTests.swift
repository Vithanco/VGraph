// The IR is what both backends render from, so it has to reproduce
// SVGBuilder's output byte for byte.

import Testing

@testable import VGraph
@testable import VGraphSVG

struct VSVGNodeTests {

    let orange = VColor(hexString: "#EA580C")!
    let blue = VColor(hexString: "#0B5FFF")!

    @Test func shapesRenderByteIdenticalToTheStringBuilder() {
        let style = VShapeStyle(fill: orange, stroke: blue, strokeWidth: 2)
        #expect(
            VSVGBuilder.rect(x: 10, y: 20, width: 80, height: 30, rx: 6, style: style).render()
                == SVGBuilder.rect(
                    x: 10, y: 20, width: 80, height: 30, rx: 6, fill: orange, stroke: blue, strokeWidth: 2))
        #expect(
            VSVGBuilder.circle(cx: 5, cy: 6, r: 7, style: style).render()
                == SVGBuilder.circle(cx: 5, cy: 6, r: 7, fill: orange, stroke: blue, strokeWidth: 2))
        #expect(
            VSVGBuilder.ellipse(cx: 1, cy: 2, rx: 3, ry: 4, style: style).render()
                == SVGBuilder.ellipse(cx: 1, cy: 2, rx: 3, ry: 4, fill: orange, stroke: blue, strokeWidth: 2))
        #expect(
            VSVGBuilder.path(d: "M0 0 L10 10", style: style).render()
                == SVGBuilder.path(d: "M0 0 L10 10", fill: orange, stroke: blue, strokeWidth: 2))
        #expect(
            VSVGBuilder.polygon(points: "0,0 5,5 10,0", style: style).render()
                == SVGBuilder.polygon(points: "0,0 5,5 10,0", fill: orange, stroke: blue, strokeWidth: 2))
    }

    @Test func aMissingFillIsNoneAndAWidthlessStrokeIsNoStroke() {
        #expect(
            VSVGBuilder.rect(x: 0, y: 0, width: 5, height: 5).render()
                == SVGBuilder.rect(x: 0, y: 0, width: 5, height: 5))
        let widthless = VShapeStyle(fill: orange, stroke: blue, strokeWidth: 0)
        #expect(
            VSVGBuilder.rect(x: 0, y: 0, width: 4, height: 4, style: widthless).render()
                == SVGBuilder.rect(x: 0, y: 0, width: 4, height: 4, fill: orange))
    }

    @Test func translucencyAndDashesMatch() {
        let ghost = VColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        #expect(
            VSVGBuilder.rect(
                x: 0, y: 0, width: 4, height: 4,
                style: VShapeStyle(fill: ghost, stroke: ghost, strokeWidth: 1)
            ).render()
                == SVGBuilder.rect(
                    x: 0, y: 0, width: 4, height: 4, fill: ghost, stroke: ghost, strokeWidth: 1))
        #expect(
            VSVGBuilder.path(
                d: "M0 0 L1 1", style: VShapeStyle(stroke: blue, strokeWidth: 1, strokeDashArray: "4 2")
            ).render()
                == SVGBuilder.path(d: "M0 0 L1 1", stroke: blue, strokeWidth: 1, strokeDashArray: "4 2"))
    }

    @Test func textAndMultilineTextMatch() {
        let font = VFont(size: 13)
        #expect(
            VSVGBuilder.text(x: 4, y: 8, content: "Idea", font: font, color: blue).render()
                == SVGBuilder.text(x: 4, y: 8, content: "Idea", font: font, color: blue))
        #expect(
            VSVGBuilder.multilineText(
                x: 2, y: 3, lines: ["one", "two"], font: font, color: blue, lineHeight: 14
            ).render()
                == SVGBuilder.multilineText(
                    x: 2, y: 3, lines: ["one", "two"], font: font, color: blue, lineHeight: 14))
    }

    /// Every optional `<text>` attribute at once, in one call: the emitter builds
    /// them up in a different place than `SVGBuilder` does (`class` and
    /// `fill-opacity` come from separate steps), so only a case that sets both can
    /// catch them landing in the wrong order. Reachable via classed group labels
    /// whose `fontcolor` carries alpha.
    @Test func aClassedTranslucentTextKeepsItsAttributeOrder() {
        let font = VFont(size: 11)
        let translucent = VColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        #expect(
            VSVGBuilder.text(
                x: 4, y: 8, content: "SUBSYSTEM", font: font, color: translucent, anchor: "start",
                fontWeight: 600, fontStyle: "italic", opacity: 0.85, letterSpacing: "0.07em",
                cssClass: SVGElementId.groupLabelClass
            ).render()
                == SVGBuilder.text(
                    x: 4, y: 8, content: "SUBSYSTEM", font: font, color: translucent, anchor: "start",
                    fontWeight: 600, fontStyle: "italic", opacity: 0.85, letterSpacing: "0.07em",
                    cssClass: SVGElementId.groupLabelClass))
    }

    @Test func groupsMatchAndNestWithoutManualClosing() {
        let inner = VSVGBuilder.group(id: "node-a", cssClass: "vgraph-node", children: [VSVGBuilder.rect(x: 0, y: 0, width: 1, height: 1)])
        let outer = VSVGBuilder.group(id: "group-g1", transform: "translate(5,5)", children: [inner])
        #expect(
            outer.render()
                == SVGBuilder.group(
                    id: "group-g1", transform: "translate(5,5)",
                    content: SVGBuilder.group(
                        id: "node-a", cssClass: "vgraph-node",
                        content: SVGBuilder.rect(x: 0, y: 0, width: 1, height: 1))))
    }

    /// Guards a copy-paste slip in the 23-case tag switch.
    @Test func everyTagEmitsItsOwnDistinctName() {
        var seen: Set<String> = []
        for tag in VSVGTag.allCases {
            #expect(!tag.name.isEmpty)
            #expect(seen.insert(tag.name).inserted, "duplicate tag name \(tag.name)")
        }
        #expect(seen.count == VSVGTag.allCases.count)
    }

    // MARK: - What the IR fixes

    @Test func textContentIsEscaped() {
        let rendered = VSVGNode.text("a < b & c > d").render()
        #expect(rendered == "a &lt; b &amp; c &gt; d")
    }

    @Test func textContentCannotCloseItsElementOrInjectMarkup() {
        let rendered = VSVGBuilder.text(
            x: 0, y: 0, content: "</text><script>alert(1)</script>",
            font: VFont(size: 12), color: blue
        ).render()
        #expect(!rendered.contains("<script>"))
        #expect(!rendered.contains("</text><"))
        #expect(rendered.hasSuffix("</text>"))
    }

    /// Paired with ``apostrophesInAttributeValuesSurviveUntouched`` — the two
    /// escapers deliberately differ.
    @Test func apostrophesInTextContentAreEscaped() {
        #expect(VSVGNode.text("it's").render() == "it&apos;s")
    }

    @Test func attributeValuesAreEscapedSoALabelCannotBreakOut() {
        let hostile = "a\" onload=\"alert(1)"
        let rendered = VSVGBuilder.group(id: hostile, children: [.empty]).render()
        #expect(!rendered.contains("onload=\"alert(1)\""))
        #expect(rendered.contains("&quot;"))
    }

    @Test func apostrophesInAttributeValuesSurviveUntouched() {
        let rendered = VSVGBuilder.text(x: 0, y: 0, content: "x", font: VFont(size: 12), color: blue).render()
        #expect(rendered.contains("font-family=\"'DM Sans'"))
        #expect(!rendered.contains("&apos;DM Sans"))
    }

    @Test func everyOpenedElementIsClosed() {
        let tree = VSVGBuilder.group(
            children: [
                VSVGBuilder.group(children: [VSVGBuilder.group(children: [VSVGBuilder.rect(x: 0, y: 0, width: 1, height: 1)])])
            ])
        let rendered = tree.render()
        #expect(rendered.components(separatedBy: "<g").count == rendered.components(separatedBy: "</g>").count)
    }

    @Test func rawIsTheOnlyUnescapedCase() {
        #expect(VSVGNode.raw("<![CDATA[a < b]]>").render() == "<![CDATA[a < b]]>")
    }

    @Test func fragmentsAndEmptyAddNoMarkup() {
        #expect(VSVGNode.empty.render() == "")
        #expect(
            VSVGNode.fragment([.text("a"), .empty, .text("b")]).render() == "ab")
    }
}
