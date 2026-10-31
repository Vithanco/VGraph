import Testing

@testable import VGraph

struct NodeStyleEnumTests {

    // MARK: - Round-trip serialization

    @Test func roundTripAllCases() throws {
        for style in NodeStyle.allCases {
            let serialized = style.asString
            let deserialized = try NodeStyle.fromString(serialized)
            #expect(deserialized == style, "Round-trip failed for \(style)")
        }
    }

    // MARK: - fromString

    @Test func fromStringIconWithText() throws {
        #expect(try NodeStyle.fromString("iconWithText") == .iconWithText)
    }

    @Test func fromStringSimpleRoundedText() throws {
        #expect(try NodeStyle.fromString("simpleRoundedText") == .simpleRoundedText)
    }

    @Test func fromStringSimpleRoundedBox() throws {
        #expect(try NodeStyle.fromString("simpleRoundedBox") == .simpleRoundedBox)
    }

    @Test func fromStringRoundedBoxAlias() throws {
        #expect(try NodeStyle.fromString("roundedBox") == .simpleRoundedBox)
    }

    @Test func fromStringCustomAlias() throws {
        #expect(try NodeStyle.fromString("custom") == .bareText)
    }

    @Test func fromStringUnknownThrows() {
        #expect(throws: VError.self) {
            try NodeStyle.fromString("nonexistent")
        }
    }

    // MARK: - asString

    @Test func asStringMatchesExpected() {
        #expect(NodeStyle.iconWithText.asString == "iconWithText")
        #expect(NodeStyle.simpleRoundedText.asString == "simpleRoundedText")
        #expect(NodeStyle.simpleRoundedBox.asString == "simpleRoundedBox")
        #expect(NodeStyle.withCategory.asString == "withCategory")
        #expect(NodeStyle.withCategoryAndIcon.asString == "withCategoryAndIcon")
        #expect(NodeStyle.iconOnly.asString == "iconOnly")
        #expect(NodeStyle.circle.asString == "circle")
        #expect(NodeStyle.bareText.asString == "bareText")
        #expect(NodeStyle.hidden.asString == "hidden")
    }

    // MARK: - needsIcon / needsCategory

    @Test func needsIconCorrect() {
        #expect(NodeStyle.iconWithText.needsIcon == true)
        #expect(NodeStyle.withCategoryAndIcon.needsIcon == true)
        #expect(NodeStyle.iconOnly.needsIcon == true)
        #expect(NodeStyle.simpleRoundedText.needsIcon == false)
        #expect(NodeStyle.withCategory.needsIcon == false)
        #expect(NodeStyle.bareText.needsIcon == false)
    }

    @Test func needsCategoryCorrect() {
        #expect(NodeStyle.withCategory.needsCategory == true)
        #expect(NodeStyle.withCategoryAndIcon.needsCategory == true)
        #expect(NodeStyle.iconWithText.needsCategory == false)
        #expect(NodeStyle.bareText.needsCategory == false)
    }
}
