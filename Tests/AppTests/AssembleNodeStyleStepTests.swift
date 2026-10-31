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

    @Test func assembleIconWithText() throws {
        let icon = IconInfo(iconPosition: .top, iconName: "and", iconColor: .blue, iconSize: 24)
        let color = VColor(hexString: "#EDE7F6")!
        let graph = try makeGraph(nodeStyle: .iconWithText, backgroundColor: color, iconInfo: icon)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.iconWithText(backgroundColor: color, icon: icon)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleSimpleRoundedText() throws {
        let color = VColor(hexString: "#7DB3FF")!
        let graph = try makeGraph(nodeStyle: .simpleRoundedText, backgroundColor: color)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.simpleRoundedText(color: color)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleSimpleRoundedBox() throws {
        let color = VColor.red
        let graph = try makeGraph(nodeStyle: .simpleRoundedBox, backgroundColor: color)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.simpleRoundedBox(color: color)

        #expect(assembled.asString == expected.asString)
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

    @Test func assembleWithCategoryAndIcon() throws {
        let icon = IconInfo(iconPosition: .top, iconName: "star.fill", iconColor: .white, iconSize: 24)
        let color = VColor(hexString: "#E53935")!
        let graph = try makeGraph(
            nodeStyle: .withCategoryAndIcon,
            backgroundColor: color,
            iconInfo: icon,
            category: "Attack"
        )

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.withCategoryAndIcon(category: "Attack", categoryColor: color, icon: icon)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleIconOnly() throws {
        let icon = IconInfo(iconPosition: .top, iconName: "plus.circle", iconColor: .black, iconSize: 16)
        let graph = try makeGraph(nodeStyle: .iconOnly, iconInfo: icon)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.iconOnly(icon: icon)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleCircle() throws {
        let color = VColor(hexString: "#4682B4")!
        let graph = try makeGraph(nodeStyle: .circle, backgroundColor: color)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.circle(color: color)

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleBareText() throws {
        let graph = try makeGraph(nodeStyle: .bareText)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.bareText

        #expect(assembled.asString == expected.asString)
    }

    @Test func assembleHidden() throws {
        let graph = try makeGraph(nodeStyle: .hidden)

        let assembled = try assembledStyle(from: graph)
        let expected = NodeStyleLayout.hidden

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
