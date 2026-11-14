import TestSupport
import Testing

@testable import VGraph

struct NodeStyleTests {

    // MARK: - Storage round trips

    private static let ink = SemanticColor.literal(VColor.black)
    private static let font = VFont(size: 11)
    private static let star = IconInfo(
        iconPosition: .center, iconName: "star.fill", iconColor: VColor.yellow, iconSize: 24)

    /// One row per parser case: a dropped case makes the attribute store throw on read-back.
    static let layouts: [NodeStyleLayout] = [
        .bareText,
        .withCategory(category: "Test", categoryColor: .literal(VColor.blue)),
        .simpleRoundedBox(color: .literal(VColor.red)),
        .iconOnly(icon: star),
        .circle(color: .literal(VColor.green)),
        .hidden,
        .sized(multiplier: 1.5, .nodeText(color: ink)),
        .horizontal([.nodeText(color: ink), .icon(star)], spacing: 3),
        .accentBar(width: 4, color: ink),
        .typeLabel(text: "Container", font: font, color: ink),
        .typeBadge(icon: "variable", typeLabel: "Stock", color: ink),
        .dashedFrame(cornerRadius: 6, borderWidth: 1, borderColor: ink, dashPattern: "5,3"),
        .italicNodeText(color: ink),
        .subtitleText(text: "a subtitle", color: ink),
        .pillBadge(text: "3", fill: ink, textColor: ink),
        .stackedShadow(cornerRadius: 6, borderWidth: 1, fill: ink, border: ink, dash: "5,3"),
        .circleContent(.icon("variable"), font: font, color: ink),
        .circleContent(.text("= 3"), font: font, color: ink),
    ]

    @Test(arguments: layouts)
    func testNodeStyleLayoutDeserialization(_ layout: NodeStyleLayout) throws {
        let serialized = layout.asString
        #expect(try NodeStyleLayout.fromString(serialized).asString == serialized)
    }

    // MARK: - NodeBackground Tests

    @Test(arguments: [
        NodeBackground.appearance(shape: .box, color: .literal(VColor.white)),
        .solid(shape: .circle, color: .literal(VColor.blue)),
        .clear(shape: .point),
        .appearance(shape: .cylinder, color: .literal(VColor.white)),
        .solid(shape: .person, color: .literal(VColor.blue)),
        .pill(color: .literal(VColor.gray)),
    ])
    func testNodeBackgroundSerialization(_ background: NodeBackground) throws {
        let serialized = background.asString
        #expect(try NodeBackground.fromString(serialized).asString == serialized)
    }

    // MARK: - Walker Tests

    @Test func testWalkFindsFirstElement() {
        let layout = NodeStyleLayout.vertical(
            [
                .frame(cornerRadius: 8, borderWidth: 2, borderColor: .literal(VColor.black)),
                .nodeText(color: .literal(VColor.black)),
                .nodeText(color: .literal(VColor.red)),
            ], spacing: 4)

        // walk should find the first nodeText element
        let result: VColor? = layout.walk { layout in
            guard case .nodeText(let color) = layout else { return nil }
            return color.resolve(darkMode: false)
        }

        #expect(result == VColor.black)  // Should find the first one, not the second
    }

    @Test("walkAll collects every match in order, from an overlay's base as well as its overlay")
    func testWalkAllCollectsAllMatches() {
        let layout = NodeStyleLayout.overlay(
            base: .vertical(
                [
                    .nodeText(color: .literal(VColor.black)),
                    .nodeText(color: .literal(VColor.red)),
                ], spacing: 4),
            overlay: .vertical([.nodeText(color: .literal(VColor.blue))], spacing: 4))

        let colors: [VColor] = layout.walkAll { layout in
            guard case .nodeText(let color) = layout else { return nil }
            return color.resolve(darkMode: false)
        }

        #expect(colors.count == 3)
        #expect(colors == [VColor.black, VColor.red, VColor.blue])
    }

    // MARK: - Icon Extraction Tests

    @Test func testExtractIconsFromNestedLayout() {
        let icon1 = IconInfo(iconPosition: .left, iconName: "star.fill", iconColor: VColor.yellow, iconSize: 24)
        let icon2 = IconInfo(iconPosition: .left, iconName: "heart.fill", iconColor: VColor.red, iconSize: 20)

        let layout = NodeStyleLayout.vertical(
            [
                .icon(icon1),
                .padded(
                    VEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
                    .icon(icon2)
                ),
            ], spacing: 4)

        let icons = layout.extractIcons()

        #expect(icons.count == 2)
        #expect(icons.contains("star.fill"))
        #expect(icons.contains("heart.fill"))
    }

    @Test func testExtractIconsReturnsEmptyWhenNoIcons() {
        let layout = NodeStyleLayout.nodeText(color: .literal(VColor.black))

        let icons = layout.extractIcons()

        #expect(icons.isEmpty)
    }

    @Test func testExtractIconsDeduplicates() {
        let icon1 = IconInfo(iconPosition: .left, iconName: "star.fill", iconColor: VColor.yellow, iconSize: 24)
        let icon2 = IconInfo(iconPosition: .center, iconName: "star.fill", iconColor: VColor.red, iconSize: 20)

        let layout = NodeStyleLayout.vertical(
            [
                .icon(icon1),
                .icon(icon2),
            ], spacing: 4)

        let icons = layout.extractIcons()

        #expect(icons.count == 1)  // Should deduplicate
        #expect(icons.contains("star.fill"))
    }
}
