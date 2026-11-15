import Testing

@testable import VGraph
@testable import VGraphSVG

struct VSVGNodeTests {

    let orange = VColor(hexString: "#EA580C")!
    let blue = VColor(hexString: "#0B5FFF")!

    @Test func shapesCarryFillStrokeAndWidth() {
        let style = VShapeStyle(fill: orange, stroke: blue, strokeWidth: 2)
        #expect(
            VSVGBuilder.rect(x: 10, y: 20, width: 80, height: 30, rx: 6, style: style).render()
                == ##"<rect x="10" y="20" width="80" height="30" rx="6" fill="#ea580c" stroke="#0b5fff" stroke-width="2"/>"##)
        #expect(
            VSVGBuilder.circle(cx: 5, cy: 6, r: 7, style: style).render()
                == ##"<circle cx="5" cy="6" r="7" fill="#ea580c" stroke="#0b5fff" stroke-width="2"/>"##)
        #expect(
            VSVGBuilder.ellipse(cx: 1, cy: 2, rx: 3, ry: 4, style: style).render()
                == ##"<ellipse cx="1" cy="2" rx="3" ry="4" fill="#ea580c" stroke="#0b5fff" stroke-width="2"/>"##)
        #expect(
            VSVGBuilder.path(d: "M0 0 L10 10", style: style).render()
                == ##"<path d="M0 0 L10 10" fill="#ea580c" stroke="#0b5fff" stroke-width="2"/>"##)
        #expect(
            VSVGBuilder.polygon(points: "0,0 5,5 10,0", style: style).render()
                == ##"<polygon points="0,0 5,5 10,0" fill="#ea580c" stroke="#0b5fff" stroke-width="2"/>"##)
    }

    @Test func aMissingFillIsNoneAndAWidthlessStrokeIsNoStroke() {
        #expect(
            VSVGBuilder.rect(x: 0, y: 0, width: 5, height: 5).render()
                == ##"<rect x="0" y="0" width="5" height="5" fill="none"/>"##)
        let widthless = VShapeStyle(fill: orange, stroke: blue, strokeWidth: 0)
        #expect(
            VSVGBuilder.rect(x: 0, y: 0, width: 4, height: 4, style: widthless).render()
                == ##"<rect x="0" y="0" width="4" height="4" fill="#ea580c"/>"##)
    }

    @Test func translucencyAndDashesAreEmittedAsAttributes() {
        let ghost = VColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        #expect(
            VSVGBuilder.rect(
                x: 0, y: 0, width: 4, height: 4,
                style: VShapeStyle(fill: ghost, stroke: ghost, strokeWidth: 1)
            ).render()
                == ##"<rect x="0" y="0" width="4" height="4" fill="#ff0000" fill-opacity="0.5" stroke="#ff0000" stroke-width="1" stroke-opacity="0.5"/>"##
        )
        #expect(
            VSVGBuilder.path(
                d: "M0 0 L1 1", style: VShapeStyle(stroke: blue, strokeWidth: 1, strokeDashArray: "4 2")
            ).render()
                == ##"<path d="M0 0 L1 1" fill="none" stroke="#0b5fff" stroke-width="1" stroke-dasharray="4 2"/>"##)
    }

    @Test func textAndMultilineTextCarryFontAndColour() {
        let font = VFont(size: 13)
        #expect(
            VSVGBuilder.text(x: 4, y: 8, content: "Idea", font: font, color: blue).render()
                == ##"<text x="4" y="8" text-anchor="middle" fill="#0b5fff" font-size="13" font-family="'DM Sans', Helvetica, sans-serif">Idea</text>"##
        )
        #expect(
            VSVGBuilder.multilineText(
                x: 2, y: 3, lines: ["one", "two"], font: font, color: blue, lineHeight: 14
            ).render()
                == ##"<text x="2" y="3" text-anchor="middle" fill="#0b5fff" font-size="13" font-family="'DM Sans', Helvetica, sans-serif"><tspan x="2" dy="0">one</tspan><tspan x="2" dy="14">two</tspan></text>"##
        )
    }

    /// Every optional `<text>` attribute at once: `class` and `fill-opacity` are
    /// added in separate steps, so only a case that sets both can catch them
    /// landing in the wrong order. Reachable via classed group labels whose
    /// `fontcolor` carries alpha.
    @Test func aClassedTranslucentTextKeepsItsAttributeOrder() {
        let font = VFont(size: 11)
        let translucent = VColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        #expect(
            VSVGBuilder.text(
                x: 4, y: 8, content: "SUBSYSTEM", font: font, color: translucent, anchor: "start",
                fontWeight: 600, fontStyle: "italic", opacity: 0.85, letterSpacing: "0.07em",
                cssClass: SVGElementId.groupLabelClass
            ).render()
                == ##"<text x="4" y="8" text-anchor="start" fill="#4c4c4c" font-size="11" font-family="'DM Sans', Helvetica, sans-serif" class="vgraph-group-label" fill-opacity="0.5" font-weight="600" font-style="italic" opacity="0.85" letter-spacing="0.07em">SUBSYSTEM</text>"##
        )
    }

    @Test func groupsNestWithoutManualClosing() {
        let inner = VSVGBuilder.group(id: "node-a", cssClass: "vgraph-node", children: [VSVGBuilder.rect(x: 0, y: 0, width: 1, height: 1)])
        let outer = VSVGBuilder.group(id: "group-g1", transform: "translate(5,5)", children: [inner])
        #expect(
            outer.render()
                == ##"<g id="group-g1" transform="translate(5,5)"><g id="node-a" class="vgraph-node"><rect x="0" y="0" width="1" height="1" fill="none"/></g></g>"##
        )
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
