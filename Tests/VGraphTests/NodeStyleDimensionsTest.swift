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
            layout: .iconWithText(backgroundColor: VColor.blue, icon: icon),
            width: 135.5, height: 31.5),
        Row(
            name: "withCategory",
            layout: .withCategory(category: "Domain", categoryColor: VColor.green),
            width: 115.5, height: 48.5),
        Row(
            name: "withCategoryAndIcon",
            layout: .withCategoryAndIcon(category: "Question", categoryColor: VColor.green, icon: icon),
            width: 143.5, height: 58.5),
    ]

    @Test(arguments: rows)
    func aStyleAddsItsChromeAroundTheText(_ row: Row) {
        let size = row.layout.calculateSizeWithText(VSize(width: 100, height: 14))

        #expect(abs(size.width - row.width) < 0.01)
        #expect(abs(size.height - row.height) < 0.01)
    }
}
