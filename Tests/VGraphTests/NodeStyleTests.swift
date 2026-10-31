import TestSupport
import Testing

@testable import VGraph

struct NodeStyleTests {

    // MARK: - AttributeType Serialization Tests

    @Test func testNodeStyleLayoutSerialization() throws {
        let style = NodeStyleLayout.bareText
        let serialized = style.asString
        #expect(!serialized.isEmpty)
        #expect(serialized.contains("{"))
    }

    @Test func testNodeStyleLayoutDeserialization() throws {
        let original = NodeStyleLayout.bareText
        let serialized = original.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    @Test func testComplexStyleSerialization() throws {
        let style = NodeStyleLayout.withCategory(category: "Test", categoryColor: .literal(VColor.blue))
        let serialized = style.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    @Test func testSimpleRoundedBoxSerialization() throws {
        let style = NodeStyleLayout.simpleRoundedBox(color: .literal(VColor.red))
        let serialized = style.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    @Test func testIconOnlySerialization() throws {
        let icon = IconInfo(
            iconPosition: .center,
            iconName: "star.fill",
            iconColor: VColor.yellow,
            iconSize: 24
        )
        let style = NodeStyleLayout.iconOnly(icon: icon)
        let serialized = style.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    @Test func testCircleSerialization() throws {
        let style = NodeStyleLayout.circle(color: .literal(VColor.green))
        let serialized = style.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    @Test func testHiddenSerialization() throws {
        let style = NodeStyleLayout.hidden
        let serialized = style.asString
        let deserialized = try NodeStyleLayout.fromString(serialized)

        let reSerialized = deserialized.asString
        #expect(serialized == reSerialized)
    }

    // MARK: - Attribute Storage Tests

    @Test func testNodeStyleAsAttribute() throws {
        var graph = VGraph()
        let notation = Notation(rawValue: "TestNotation")
        graph = try graph.add(notation: notation)

        let testNodeType = NodeType(string: "TestType")
        graph = try graph.add(nodeType: testNodeType, addTo: notation)

        let style = NodeStyleLayout.simpleRoundedBox(color: .literal(VColor.blue))
        graph = try graph.set(
            nodeType: testNodeType,
            def: Attributes.Node.style,
            value: style
        )

        let retrievedStyle: NodeStyleLayout = try graph.get(
            nodeType: testNodeType,
            attribute: Attributes.Node.style
        )

        #expect(retrievedStyle.asString == style.asString)
    }

    @Test func testDefaultNodeStyleAttribute() throws {
        var graph = VGraph()
        let notation = Notation(rawValue: "TestNotation")
        graph = try graph.add(notation: notation)

        let testNodeType = NodeType(string: "TestType")
        graph = try graph.add(nodeType: testNodeType, addTo: notation)

        let retrievedStyle: NodeStyleLayout = try graph.get(
            nodeType: testNodeType,
            attribute: Attributes.Node.style
        )

        #expect(
            retrievedStyle.asString == Attributes.Node.style.defaultValue.asString)
    }

    @Test func testMultipleNodeTypesWithDifferentStyles() throws {
        var graph = VGraph()
        let notation = Notation(rawValue: "TestNotation")
        graph = try graph.add(notation: notation)

        let type1 = NodeType(string: "Type1")
        let type2 = NodeType(string: "Type2")
        let type3 = NodeType(string: "Type3")

        graph = try graph.add(nodeType: type1, addTo: notation)
        graph = try graph.add(nodeType: type2, addTo: notation)
        graph = try graph.add(nodeType: type3, addTo: notation)

        let style1 = NodeStyleLayout.simpleRoundedBox(color: .literal(VColor.red))
        let style2 = NodeStyleLayout.withCategory(category: "Category", categoryColor: .literal(VColor.blue))
        let style3 = NodeStyleLayout.bareText

        graph = try graph.set(nodeType: type1, def: Attributes.Node.style, value: style1)
        graph = try graph.set(nodeType: type2, def: Attributes.Node.style, value: style2)
        graph = try graph.set(nodeType: type3, def: Attributes.Node.style, value: style3)

        let retrieved1: NodeStyleLayout = try graph.get(
            nodeType: type1, attribute: Attributes.Node.style)
        let retrieved2: NodeStyleLayout = try graph.get(
            nodeType: type2, attribute: Attributes.Node.style)
        let retrieved3: NodeStyleLayout = try graph.get(
            nodeType: type3, attribute: Attributes.Node.style)

        #expect(retrieved1.asString == style1.asString)
        #expect(retrieved2.asString == style2.asString)
        #expect(retrieved3.asString == style3.asString)
    }

    // MARK: - IBIS Notation Integration Tests

    @Test func testIBISNotationHasStyles() throws {
        var graph = VGraph()
        graph = try Notations.Ibis.addNotation(addTo: graph)

        let questionStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Ibis.NodeTypes.question,
            attribute: Attributes.Node.style
        )
        let answerStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Ibis.NodeTypes.answer,
            attribute: Attributes.Node.style
        )
        let proStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Ibis.NodeTypes.pro,
            attribute: Attributes.Node.style
        )
        let conStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.Ibis.NodeTypes.con,
            attribute: Attributes.Node.style
        )

        #expect(!questionStyle.asString.isEmpty)
        #expect(!answerStyle.asString.isEmpty)
        #expect(!proStyle.asString.isEmpty)
        #expect(!conStyle.asString.isEmpty)
    }

    // MARK: - PredefinedStyles Tests

    @Test func testPredefinedStylesExist() {
        let bareText = NodeStyleLayout.bareText
        let hidden = NodeStyleLayout.hidden
        let simple = NodeStyleLayout.simpleRoundedBox(color: .literal(VColor.gray))
        let category = NodeStyleLayout.withCategory(category: "Test", categoryColor: .literal(VColor.blue))
        let circle = NodeStyleLayout.circle(color: .literal(VColor.red))

        #expect(!bareText.asString.isEmpty)
        #expect(!hidden.asString.isEmpty)
        #expect(!simple.asString.isEmpty)
        #expect(!category.asString.isEmpty)
        #expect(!circle.asString.isEmpty)
    }

    @Test func testIconWithTextStyle() {
        let icon = IconInfo(
            iconPosition: .left,
            iconName: "star",
            iconColor: VColor.yellow,
            iconSize: 20
        )
        let style = NodeStyleLayout.iconWithText(
            backgroundColor: VColor.blue,
            icon: icon
        )

        #expect(!style.asString.isEmpty)
    }

    // MARK: - NodeBackground Tests

    @Test func testNodeBackgroundSerialization() throws {
        let backgrounds: [NodeBackground] = [
            .appearance(shape: .box, color: .literal(VColor.white)),
            .solid(shape: .circle, color: .literal(VColor.blue)),
            .clear(shape: .point),
        ]

        for background in backgrounds {
            let serialized = background.asString
            let deserialized = try NodeBackground.fromString(serialized)
            let reSerialized = deserialized.asString
            #expect(serialized == reSerialized)
        }
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

    @Test func testWalkReturnsNilWhenNotFound() {
        let layout = NodeStyleLayout.frame(cornerRadius: 8, borderWidth: 2, borderColor: .literal(VColor.black))

        let result: Bool? = layout.walk { layout in
            guard case .nodeText(_) = layout else { return nil }
            return true
        }

        #expect(result == nil)
    }

    @Test func testWalkSearchesNestedStructures() {
        let layout = NodeStyleLayout.padded(
            VEdgeInsets(top: 4, left: 4, bottom: 4, right: 4),
            .background(
                .solid(shape: .box, color: .literal(VColor.white)),
                .vertical(
                    [
                        .frame(cornerRadius: 8, borderWidth: 2, borderColor: .literal(VColor.black)),
                        .nodeText(color: .literal(VColor.blue)),
                    ], spacing: 4)
            )
        )

        let result: VColor? = layout.walk { layout in
            guard case .nodeText(let color) = layout else { return nil }
            return color.resolve(darkMode: false)
        }

        #expect(result == VColor.blue)
    }

    @Test func testWalkAllCollectsAllMatches() {
        let layout = NodeStyleLayout.vertical(
            [
                .nodeText(color: .literal(VColor.black)),
                .nodeText(color: .literal(VColor.red)),
                .nodeText(color: .literal(VColor.blue)),
            ], spacing: 4)

        let colors: [VColor] = layout.walkAll { layout in
            guard case .nodeText(let color) = layout else { return nil }
            return color.resolve(darkMode: false)
        }

        #expect(colors.count == 3)
        #expect(colors == [VColor.black, VColor.red, VColor.blue])
    }

    @Test func testWalkAllReturnsEmptyWhenNothingMatches() {
        let layout = NodeStyleLayout.frame(cornerRadius: 8, borderWidth: 2, borderColor: .literal(VColor.black))

        let results: [Bool] = layout.walkAll { layout in
            guard case .nodeText(_) = layout else { return nil }
            return true
        }

        #expect(results.isEmpty)
    }

    @Test func testWalkAllCollectsFromNestedStructures() {
        let layout = NodeStyleLayout.overlay(
            base: .vertical(
                [
                    .nodeText(color: .literal(VColor.black)),
                    .nodeText(color: .literal(VColor.red)),
                ], spacing: 4),
            overlay: .vertical(
                [
                    .nodeText(color: .literal(VColor.blue))
                ], spacing: 4)
        )

        let colors: [VColor] = layout.walkAll { layout in
            guard case .nodeText(let color) = layout else { return nil }
            return color.resolve(darkMode: false)
        }

        #expect(colors.count == 3)
        #expect(Set(colors) == Set([VColor.black, VColor.red, VColor.blue]))
    }

    // MARK: - Icon Extraction Tests

    @Test func testExtractIconsFromSimpleLayout() {
        let icon = IconInfo(
            iconPosition: .left,
            iconName: "star.fill",
            iconColor: VColor.yellow,
            iconSize: 24
        )
        let layout = NodeStyleLayout.icon(icon)

        let icons = layout.extractIcons()

        #expect(icons.count == 1)
        #expect(icons.contains("star.fill"))
    }

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
