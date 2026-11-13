import Testing

@testable import App
@testable import VGraph

struct AssembleNodeStyleStepTests {

    // MARK: - Helpers

    /// Creates a minimal graph with a single node type and the given decomposed style attributes.
    private func makeGraph(
        nodeTypeName: String = "TestNode",
        nodeStyle: NodeStyle,
        backgroundColor: VColor = .white,
        iconInfo: IconInfo? = nil,
        category: String? = nil
    ) throws -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        let nodeType = NodeType(string: nodeTypeName)
        graph = try graph.add(nodeType: nodeType)
        graph = try graph.set(nodeType: nodeType, attribute: Attributes.Node.nodeStyle.attribute(nodeStyle))
        graph = try graph.set(nodeType: nodeType, attribute: Attributes.Node.backgroundColor.attribute(backgroundColor))
        if let icon = iconInfo {
            graph = try graph.set(nodeType: nodeType, attribute: Attributes.Node.iconInfo.attribute(icon))
        }
        if let cat = category {
            graph = try graph.set(nodeType: nodeType, attribute: Attributes.Node.category.attribute(cat))
        }
        return graph
    }

    private func assembledStyle(from graph: VGraph, nodeTypeName: String = "TestNode") throws -> NodeStyleLayout {
        let assembled = try DisplayPipeline.assembleNodeStyles(graph)
        return try assembled.get(nodeType: NodeType(string: nodeTypeName), attribute: Attributes.Node.style)
    }

    // MARK: - Style Assembly Tests

    /// One row per `effectiveNodeLayout` arm: each keeps its own input and the layout
    /// it must produce, so a swapped arm or a dropped icon/colour fails its row.
    struct Row: Sendable {
        let style: NodeStyle
        let color: VColor
        let icon: IconInfo?
        let category: String?
        let expected: String
    }

    private static let iconWithText = IconInfo(iconPosition: .top, iconName: "and", iconColor: .blue, iconSize: 24)
    private static let star = IconInfo(iconPosition: .top, iconName: "star.fill", iconColor: .white, iconSize: 24)
    private static let plus = IconInfo(iconPosition: .top, iconName: "plus.circle", iconColor: .black, iconSize: 16)

    static var rows: [Row] {
        let lavender = VColor(hexString: "#EDE7F6")!
        let blue = VColor(hexString: "#7DB3FF")!
        let steel = VColor(hexString: "#4682B4")!
        let red = VColor(hexString: "#E53935")!
        return [
            Row(
                style: .iconWithText, color: lavender, icon: iconWithText, category: nil,
                expected: NodeStyleLayout.iconWithText(backgroundColor: lavender, icon: iconWithText).asString),
            Row(
                style: .simpleRoundedText, color: blue, icon: nil, category: nil,
                expected: NodeStyleLayout.simpleRoundedText(color: blue).asString),
            Row(
                style: .simpleRoundedBox, color: .red, icon: nil, category: nil,
                expected: NodeStyleLayout.simpleRoundedBox(color: .red).asString),
            Row(
                style: .withCategoryAndIcon, color: red, icon: star, category: "Attack",
                expected: NodeStyleLayout.withCategoryAndIcon(category: "Attack", categoryColor: red, icon: star).asString),
            Row(
                style: .iconOnly, color: .white, icon: plus, category: nil,
                expected: NodeStyleLayout.iconOnly(icon: plus).asString),
            Row(
                style: .circle, color: steel, icon: nil, category: nil,
                expected: NodeStyleLayout.circle(color: steel).asString),
            Row(style: .bareText, color: .white, icon: nil, category: nil, expected: NodeStyleLayout.bareText.asString),
            Row(style: .hidden, color: .white, icon: nil, category: nil, expected: NodeStyleLayout.hidden.asString),
        ]
    }

    @Test(arguments: rows)
    func assemblesTheLayoutOfItsStyle(_ row: Row) throws {
        let graph = try makeGraph(
            nodeStyle: row.style, backgroundColor: row.color, iconInfo: row.icon, category: row.category)

        #expect(try assembledStyle(from: graph).asString == row.expected)
    }

    @Test func assembleWithCategory() throws {
        let color = VColor(hexString: "#0096C7")!
        let graph = try makeGraph(
            nodeStyle: .withCategory,
            backgroundColor: color,
            category: "Critical Success Factor"
        )

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.withCategory(category: "Critical Success Factor", categoryColor: color)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleWithCategoryFallbackToNodeTypeName() throws {
        let color = VColor(hexString: "#0096C7")!
        // No category attribute set — should fall back to node type ID
        let graph = try makeGraph(
            nodeTypeName: "Goal",
            nodeStyle: .withCategory,
            backgroundColor: color
        )

        let assembled = try assembledStyle(from: graph, nodeTypeName: "Goal")
        let expected = NodeStyleLayout.withCategory(category: "Goal", categoryColor: color)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleDefaultsToBaretextWhenNoStyleSet() throws {
        var graph = try VGraph().defineStandardAttributes()
        let nodeType = NodeType(string: "Plain")
        graph = try graph.add(nodeType: nodeType)

        let assembled = try DisplayPipeline.assembleNodeStyles(graph)
        let style = try assembled.get(nodeType: nodeType, attribute: Attributes.Node.style)

        #expect(style.asString == NodeStyleLayout.bareText.asString)
    }
}
