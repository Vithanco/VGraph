import Testing

@testable import VGraph

struct NodeStyleDimensionsTest {

    private static let icon = IconInfo(
        iconPosition: .left, iconName: "star", iconColor: VColor.yellow, iconSize: 24)

    struct Row: CustomTestStringConvertible, Sendable {
        let name: String
        let layout: NodeStyleLayout
        let width: Double
        let height: Double
        var testDescription: String { name }
    }

    /// The text size is fixed so the rows pin what each style adds around it
    /// (the text estimate itself is TextSizeEstimatorTest's).
    static let rows: [Row] = [
        Row(name: "bareText", layout: .bareText, width: 100, height: 14),
        Row(
            name: "iconWithText",
            layout: .iconWithText(backgroundColor: .literal(VColor.blue), icon: icon),
            width: 135.5, height: 31.5),
        Row(
            name: "withCategory",
            layout: .withCategory(category: "Domain", categoryColor: .literal(VColor.green)),
            width: 115.5, height: 48.5),
        Row(
            name: "withCategoryAndIcon",
            layout: .withCategoryAndIcon(category: "Question", categoryColor: .literal(VColor.green), icon: icon),
            width: 143.5, height: 58.5),
    ]

    @Test(arguments: rows)
    func aStyleAddsItsChromeAroundTheText(_ row: Row) {
        let size = row.layout.size(aroundText: VSize(width: 100, height: 14))

        #expect(abs(size.width - row.width) < 0.01)
        #expect(abs(size.height - row.height) < 0.01)
    }

    /// The node's minimum width is reserved from the badge's type name, so the
    /// row itself must be measured the same way or the name runs past the strip.
    @Test("A type badge is as wide as the minimum width its notation reserves for it", arguments: ["Person", "Software System"])
    func aTypeBadgeMatchesItsReservedWidth(_ typeName: String) {
        let badge = NodeStyleLayout.typeBadge(icon: "person", typeLabel: typeName, color: .literal(VColor.black))
        let width = badge.size(aroundText: .zero).width
        let insets = NodeStyleConstants.accentStripLeftInset + NodeStyleConstants.accentStripRightInset

        #expect(abs(width + insets - NodeStyleConstants.iconBadgeMinWidth(typeLabel: typeName)) < 0.01)
    }
}
