// Every `NodeStyleLayout` case on the same input, so adding one — or changing how
// an existing one draws — shows up as a reviewable diff rather than as nothing.

import Testing

@testable import VGraph
@testable import VGraphSVG

struct VSVGNodeLayoutTests {

    let bounds = VRect(origin: VPoint(x: 10, y: 20), size: VSize(width: 150, height: 80))
    let font = VFont(size: 14)

    func expectSnapshot(
        _ style: NodeStyleLayout, wrappedText: [String] = ["Test Node"],
        bounds: VRect? = nil, nodeTextSize: VSize? = nil, variant: String? = nil,
        name: String = #function, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let rendered = try VSVGNodeLayout.render(
            style: style, wrappedText: wrappedText, bounds: bounds ?? self.bounds, font: font,
            nodeTextSize: nodeTextSize, darkMode: false
        ).render()
        SVGSnapshot.verify(
            rendered, named: SVGSnapshot.caseName("NodeLayout", name, variant), sourceLocation: sourceLocation)
    }

    // MARK: - Presets shared with NodeRendererTests

    @Test func bareText() throws {
        try expectSnapshot(.bareText)
    }

    @Test func simpleRoundedBox() throws {
        try expectSnapshot(.simpleRoundedBox(color: .literal(VColor.blue)), wrappedText: ["Blue Box"])
    }

    @Test func withCategoryHeader() throws {
        try expectSnapshot(
            .withCategory(category: "Domain", categoryColor: .literal(VColor.green)), wrappedText: ["My Node"])
    }

    @Test func hidden() throws {
        try expectSnapshot(.hidden, wrappedText: ["Hidden"])
    }

    @Test func circleStyle() throws {
        try expectSnapshot(
            .circle(color: .literal(VColor.red)),
            wrappedText: ["O"], bounds: VRect(origin: VPoint(x: 0, y: 0), size: VSize(width: 60, height: 60)))
    }

    // MARK: - Every NodeStyleLayout case, directly

    @Test func categoryHeader() throws {
        try expectSnapshot(
            .categoryHeader(text: "Header", font: VFont(size: 11), backgroundColor: .literal(.blue), textColor: .literal(.white)))
    }

    @Test func frame() throws {
        try expectSnapshot(.frame(cornerRadius: 6, borderWidth: 2, borderColor: .literal(.black)))
    }

    @Test func dashedFrame() throws {
        try expectSnapshot(
            .dashedFrame(cornerRadius: 4, borderWidth: 1.5, borderColor: .literal(.gray), dashPattern: "5,3"))
    }

    @Test func italicNodeText() throws {
        try expectSnapshot(.italicNodeText(color: .literal(.black)), wrappedText: ["one", "two"])
    }

    @Test func subtitleText() throws {
        try expectSnapshot(.subtitleText(text: "subtitle", color: .literal(.gray)))
    }

    @Test func pillBadge() throws {
        try expectSnapshot(.pillBadge(text: "12", fill: .literal(.red), textColor: .literal(.white)))
    }

    @Test func stackedShadow() throws {
        try expectSnapshot(
            .stackedShadow(
                cornerRadius: 5, borderWidth: 1, fill: .literal(.blue), border: .literal(.black), dash: "5,3"))
    }

    @Test func stackedShadowWithoutDash() throws {
        try expectSnapshot(
            .stackedShadow(cornerRadius: 5, borderWidth: 1, fill: .literal(.blue), border: .literal(.black), dash: ""))
    }

    @Test func circleBorder() throws {
        try expectSnapshot(.circleBorder(borderWidth: 2, borderColor: .literal(.black)))
    }

    @Test func iconWithKnownNameSucceeds() throws {
        let iconInfo = IconInfo(iconPosition: .center, iconName: "and", iconColor: .blue, iconSize: 24)
        try expectSnapshot(.icon(iconInfo), wrappedText: [])
    }

    @Test func iconWithUnknownNameDrawsTheMissingGlyph() throws {
        let iconInfo = IconInfo(iconPosition: .center, iconName: "nonexistent.icon", iconColor: .red, iconSize: 24)
        let svg = try VSVGNodeLayout.render(
            style: .icon(iconInfo), wrappedText: [], bounds: bounds, font: font, darkMode: false
        ).render()

        #expect(svg.contains("icon-nonexistent.icon"), "the reference keeps the name the document asked for")
    }

    @Test func nodeText() throws {
        try expectSnapshot(.nodeText(color: .literal(.black)), wrappedText: ["line one", "line two"])
    }

    @Test func empty() throws {
        try expectSnapshot(.empty, wrappedText: [])
    }

    @Test func padded() throws {
        try expectSnapshot(
            .padded(VEdgeInsets(top: 4, left: 8, bottom: 4, right: 8), .nodeText(color: .literal(.black))))
    }

    @Test func background() throws {
        try expectSnapshot(.background(.solid(shape: .box, color: .literal(.blue)), .nodeText(color: .literal(.white))))
    }

    @Test func backgroundAppearanceCircle() throws {
        try expectSnapshot(.background(.appearance(shape: .circle, color: .literal(.blue)), .empty))
    }

    @Test func backgroundAppearancePoint() throws {
        try expectSnapshot(.background(.appearance(shape: .point, color: .literal(.blue)), .empty))
    }

    @Test func backgroundAppearanceCylinder() throws {
        try expectSnapshot(.background(.appearance(shape: .cylinder, color: .literal(.blue)), .empty))
    }

    @Test func backgroundAppearancePerson() throws {
        try expectSnapshot(.background(.appearance(shape: .person, color: .literal(.blue)), .empty))
    }

    @Test func backgroundPill() throws {
        try expectSnapshot(.background(.pill(color: .literal(.blue)), .empty))
    }

    @Test func backgroundClear() throws {
        try expectSnapshot(.background(.clear(shape: .box), .nodeText(color: .literal(.black))))
    }

    @Test func sized() throws {
        try expectSnapshot(.sized(multiplier: 0.5, .nodeText(color: .literal(.black))))
    }

    @Test func vertical() throws {
        try expectSnapshot(
            .vertical(
                [.nodeText(color: .literal(.black)), .subtitleText(text: "sub", color: .literal(.gray))],
                spacing: 4))
    }

    @Test func horizontal() throws {
        try expectSnapshot(
            .horizontal(
                [
                    .typeLabel(text: "a", font: VFont(size: 9), color: .literal(.black)),
                    .typeLabel(text: "b", font: VFont(size: 9), color: .literal(.black)),
                ],
                spacing: 4))
    }

    @Test func emptyVerticalAndHorizontalAreEmpty() throws {
        try expectSnapshot(.vertical([], spacing: 4), variant: "vertical")
        try expectSnapshot(.horizontal([], spacing: 4), variant: "horizontal")
    }

    @Test func overlay() throws {
        try expectSnapshot(
            .overlay(base: .background(.solid(shape: .box, color: .literal(.blue)), .empty), overlay: .nodeText(color: .literal(.white))))
    }

    @Test func accentBar() throws {
        try expectSnapshot(.accentBar(width: 4, color: .literal(.blue)))
    }

    @Test func typeLabel() throws {
        try expectSnapshot(.typeLabel(text: "concept", font: VFont(size: 9), color: .literal(.black)))
    }

    @Test func typeBadge() throws {
        try expectSnapshot(.typeBadge(icon: "concept", typeLabel: "concept", color: .literal(.blue)))
    }

    // MARK: - darkMode threading
    //
    // Every recursive branch has to hand `darkMode` down to its children, and a
    // dropped one is invisible to every snapshot above because those all render
    // light. So these assert against an explicit token pair instead, which pins
    // which side was used rather than only that the bytes did not move.

    let themed = SemanticColor(id: "test.token", lightHex: "#112233", darkHex: "#ccddee")

    func expectThemeReachesTheLeaf(
        _ style: NodeStyleLayout, wrappedText: [String] = ["Test Node"],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let light = try VSVGNodeLayout.render(
            style: style, wrappedText: wrappedText, bounds: bounds, font: font, darkMode: false
        ).render()
        let dark = try VSVGNodeLayout.render(
            style: style, wrappedText: wrappedText, bounds: bounds, font: font, darkMode: true
        ).render()
        #expect(light.contains("#112233"), "light side missing", sourceLocation: sourceLocation)
        #expect(dark.contains("#ccddee"), "dark side missing", sourceLocation: sourceLocation)
        #expect(!dark.contains("#112233"), "darkMode was not threaded here", sourceLocation: sourceLocation)
    }

    @Test func darkModeReachesLeaves() throws {
        try expectThemeReachesTheLeaf(.frame(cornerRadius: 4, borderWidth: 2, borderColor: themed))
        try expectThemeReachesTheLeaf(.nodeText(color: themed))
        try expectThemeReachesTheLeaf(.accentBar(width: 4, color: themed))
        try expectThemeReachesTheLeaf(.typeBadge(icon: "concept", typeLabel: "concept", color: themed))
    }

    @Test func darkModeReachesThroughEveryNestingBranch() throws {
        let leaf = NodeStyleLayout.frame(cornerRadius: 4, borderWidth: 2, borderColor: themed)
        try expectThemeReachesTheLeaf(.padded(VEdgeInsets(top: 2, left: 2, bottom: 2, right: 2), leaf))
        try expectThemeReachesTheLeaf(.sized(multiplier: 0.8, leaf))
        try expectThemeReachesTheLeaf(.vertical([leaf], spacing: 2))
        try expectThemeReachesTheLeaf(.horizontal([leaf], spacing: 2))
        try expectThemeReachesTheLeaf(.overlay(base: leaf, overlay: .empty))
        try expectThemeReachesTheLeaf(.overlay(base: .empty, overlay: leaf))
        // `.background` threads twice: the background itself and the inner layout.
        try expectThemeReachesTheLeaf(.background(.solid(shape: .box, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.clear(shape: .box), leaf))
    }

    /// Each `NodeBackground` shape builds its own set of nodes, so the colour has
    /// to reach every one of them.
    @Test func darkModeReachesEveryBackgroundShape() throws {
        try expectThemeReachesTheLeaf(.background(.appearance(shape: .box, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.appearance(shape: .circle, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.appearance(shape: .point, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.appearance(shape: .cylinder, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.appearance(shape: .person, color: themed), .empty))
        try expectThemeReachesTheLeaf(.background(.pill(color: themed), .empty))
    }

    // MARK: - Nested composite (exercises recursion depth + transform wrapping)

    @Test func deeplyNestedComposite() throws {
        let style = NodeStyleLayout.background(
            .solid(shape: .box, color: .literal(.blue)),
            .padded(
                VEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
                .vertical(
                    [
                        .typeLabel(text: "type", font: VFont(size: 9), color: .literal(.white)),
                        .horizontal(
                            [.accentBar(width: 3, color: .literal(.red)), .nodeText(color: .literal(.white))],
                            spacing: 2),
                        .overlay(base: .empty, overlay: .pillBadge(text: "3", fill: .literal(.red), textColor: .literal(.white))),
                    ], spacing: 2)))
        try expectSnapshot(style, wrappedText: ["deep", "nest"])
    }
}
