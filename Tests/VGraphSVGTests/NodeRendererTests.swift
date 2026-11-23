// What each preset is *for*. `VSVGNodeLayoutTests` snapshots the exact bytes of
// these same styles, but a snapshot can only say the bytes changed — it cannot say
// "hidden means nothing is drawn".

import Testing

@testable import VGraph
@testable import VGraphSVG

struct NodeRendererTests {

    let font = VFont(size: 14)

    func render(
        _ style: NodeStyleLayout, wrappedText: [String] = [], size: VSize = VSize(width: 100, height: 50)
    ) throws -> String {
        try VSVGNodeLayout.render(
            style: style, wrappedText: wrappedText, bounds: VRect(origin: VPoint(x: 0, y: 0), size: size),
            font: font, darkMode: false
        ).render()
    }

    /// "Bare" is the frame, not the fill: still a solid white box.
    @Test func bareTextDrawsBlackTextOnAnUnframedWhiteBox() throws {
        let svg = try render(.bareText, wrappedText: ["Test Node"])

        #expect(svg.contains("Test Node"))
        #expect(svg.contains("fill=\"#ffffff\""))
        #expect(!svg.contains("stroke"), "nothing frames a bare label")
        #expect(!svg.contains("rx="))
    }

    /// The label is composed on top by whoever asks for one, so passing text here
    /// must change nothing.
    @Test func simpleRoundedBoxDrawsAFilledBoxInsideARoundedFrameAndNoText() throws {
        let svg = try render(
            .simpleRoundedBox(color: .literal(VColor.blue)), wrappedText: ["Blue Box"],
            size: VSize(width: 150, height: 80))

        #expect(svg.contains("fill=\"\(VColor.blue.hexString)\""))
        #expect(svg.contains("rx="), "the rounding lives on the frame, and is the whole point of this preset")
        #expect(svg.contains("stroke-width="))
        #expect(!svg.contains("<text"))
        #expect(!svg.contains("Blue Box"))
    }

    @Test func withCategoryDrawsBothTheCategoryAndTheLabel() throws {
        let svg = try render(
            .withCategory(category: "Domain", categoryColor: .literal(VColor.green)), wrappedText: ["My Node"],
            size: VSize(width: 200, height: 100))

        #expect(svg.contains("Domain"))
        #expect(svg.contains("My Node"))
        #expect(svg.contains("<rect"))
    }

    /// Still occupies its slot, so its id stays in the document and hit-testing
    /// keeps working.
    @Test func hiddenDrawsNothingButStillEmitsItsPositionedGroup() throws {
        let svg = try render(.hidden, wrappedText: ["Hidden"])

        #expect(svg == "<g transform=\"translate(0,0)\"></g>")
    }

    @Test func circleDrawsAnEllipseAndKeepsItsLabel() throws {
        let svg = try render(.circle(color: .literal(VColor.red)), wrappedText: ["O"], size: VSize(width: 60, height: 60))

        #expect(svg.contains("<ellipse"))
        #expect(svg.contains("<text"))
    }

    /// The viewport is `iconSize` square whatever the artwork's proportions: the
    /// `<symbol>` carries the viewBox, so SVG's own `xMidYMid meet` does the
    /// fitting and the node path never has to resolve the artwork. ADR-0022.
    @Test func theIconViewportIsSquareAndCenteredWhateverTheArtwork() throws {
        let tall = IconInfo(iconPosition: .center, iconName: "tall.unresolved", iconColor: VColor.blue, iconSize: 24)
        let wide = IconInfo(iconPosition: .center, iconName: "wide.unresolved", iconColor: VColor.blue, iconSize: 24)

        for iconInfo in [tall, wide] {
            let svg = try render(.icon(iconInfo), size: VSize(width: 60, height: 60))
            #expect(svg.contains("width=\"24.0\" height=\"24.0\""), "\(iconInfo.iconName) must get a square viewport")
        }
    }

    /// The two halves have to agree on the id or the icon renders as nothing.
    @Test func iconWithKnownNameReferencesTheSymbolInDefs() throws {
        let iconInfo = IconInfo(
            iconPosition: .center, iconName: "and", iconColor: VColor.blue, iconSize: 24)
        let svg = try render(.icon(iconInfo), size: VSize(width: 60, height: 60))

        #expect(svg.contains("<use"))
        #expect(svg.contains("icon-and"))

        let defs = VSVGDefs.render(
            icons: ["and": BuiltinIcons.artwork(for: "and")!], includeWatermark: false, darkMode: false
        ).render()
        #expect(defs.contains("id=\"icon-and\""))
    }
}
