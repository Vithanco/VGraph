import Testing

@testable import VGraph

@Suite("Attribute Tests")
struct AttributeTests {
    let node = ItemKey(.node, "node")
    let nodeLabel = Attributes.Node.label

    @Test("Two spellings of one value are equal through the attribute's type, and only then")
    func valuesCompareThroughTheirType() {
        let fontsize = Attributes.Node.fontsize.asDefinition
        #expect(fontsize.isEqual("20", "20.0"))
        #expect(!fontsize.isEqual("20", "20.5"))
        #expect(!fontsize.isEqual("20", "big"))
        #expect(Attributes.Edge.outDegreeMin.asDefinition.isEqual("07", "7"))
        #expect(!Attributes.Edge.outDegreeMin.asDefinition.isEqual("7", "8"))
        #expect(Attributes.Group.isFolded.asDefinition.isEqual("True", "true"))
        #expect(!Attributes.Group.isFolded.asDefinition.isEqual("true", "false"))
        #expect(Attributes.Node.label.asDefinition.isEqual("20", "20"))
        #expect(!Attributes.Node.label.asDefinition.isEqual("20", "20.0"))
    }

    @Test("Attributes of different definitions are different, whatever their value")
    func equalityIncludesTheDefinition() {
        let label = Attributes.Node.label("x")
        let tooltip = Attributes.Node.tooltip("x")
        #expect(label != tooltip)
        #expect(Set([label, tooltip]).count == 2)
        #expect(label == Attributes.Node.label("x"))
    }

    @Test("An empty string is no number")
    func emptyStringIsNoDouble() {
        #expect(Double("") == nil)
        #expect(throws: VError.self) { try Double.fromString("") }
    }

    @Test("A number written with an exponent is a number: Swift writes very small and very large ones that way")
    func exponentNotationIsANumber() {
        #expect(Double("1e-05") == 0.00001)
        #expect(Double("3.5E+2") == 350)
        #expect(Double("-2.5e3") == -2500)
        #expect(Double("0.25") == 0.25)
        #expect(Double("1e") == nil)
        #expect(Double("e5") == nil)
        #expect(Double("0-5") == nil)
    }

    @Test("Defining an attribute again is a no-op where it matches, and an error where it differs")
    func aDefinitionMayRepeatButNotContradict() throws(VError) {
        let store = try AttributeStore().define(nodeLabel)
        #expect(store.definitions.count == 1)
        #expect(try store.define(nodeLabel) == store)
        let renamed = AttributeDefinition(
            id: nodeLabel.id,
            name: "another name",
            description: nodeLabel.description,
            defaultValue: nodeLabel.defaultValue,
            target: nodeLabel.target,
            typeAsString: String.typeName
        )
        #expect(throws: VError.definitionAlreadyExists(nodeLabel.id)) {
            try store.define(renamed)
        }
    }

    @Test("A new graph defines every node, edge and group attribute, none hiding another")
    func theStandardAttributesShareNoId() {
        let sets = [Attributes.Node.definitions, Attributes.Edge.definitions, Attributes.Group.definitions]
        #expect(VGraph().attributeDefinitions.count == sets.map { $0.count }.reduce(0, +))
    }

    @Test("Defining a set again is a no-op where it matches, and an error where it differs")
    func aSetOfDefinitionsMayRepeatButNotContradict() throws(VError) {
        let store = try AttributeStore().define(nodeLabel)
        #expect(try store.define(AttributeDefContainer([nodeLabel.asDefinition])) == store)
        let renamed = AttributeDefinition(
            id: nodeLabel.id,
            name: "another name",
            description: nodeLabel.description,
            defaultValue: nodeLabel.defaultValue,
            target: nodeLabel.target,
            typeAsString: String.typeName
        )
        #expect(throws: VError.definitionAlreadyExists(nodeLabel.id)) {
            try store.define(AttributeDefContainer([renamed]))
        }
    }

    @Test
    func aGroupAttributeCannotBeSetOnANodeOrEdge() throws(VError) {
        let nodeType = NodeType("TestNodeTyoe")
        let node = Node("TestNode")
        let edgeType = EdgeType(id: "testEdgeType", from: nodeType, to: nodeType)
        let edge = Edge(id: "testEdge", from: node, to: node)
        let graph = try VGraph()
            .adding(nodeType: nodeType)
            .adding(node: node, type: nodeType)
            .adding(edgeType: edgeType)
            .adding(edge: edge, edgeType: edgeType)

        #expect(throws: VError.wrongTarget(is: .group, insteadOf: .node)) {
            try graph.setting(node: node, attribute: Attributes.Group.label.attribute("a Label"))
        }
        #expect(throws: VError.wrongTarget(is: .group, insteadOf: .edge)) {
            try graph.setting(edge: edge, attribute: Attributes.Group.label.attribute("a Label"))
        }
        // all is allowed for groups, as that is a way to defined shared attributes
    }

    @Test
    func arrayOfStringsAttribute() throws(VError) {
        let stringArrayDef = TypedAttributeDefinition<[String]>(
            id: "test.stringarray",
            name: "String Array",
            description: "An array of strings for testing",
            defaultValue: [],
            target: .node
        )

        let testString = "[hello,world,swift]"
        let attribute = try stringArrayDef.attribute(fromString: testString)

        #expect(attribute.stringValue == testString)

        let node = Node("testNode")
        let nodeType = NodeType("testNodeType")

        var graph = try VGraph()
            .adding(nodeType: nodeType)
            .adding(node: node, type: nodeType)
            .defining(stringArrayDef)
            .setting(node: node, attribute: attribute)

        // Retrieve and verify we get an array of individual strings
        let retrieved: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved == ["hello", "world", "swift"])
        #expect(retrieved.count == 3)
        #expect(retrieved[0] == "hello")
        #expect(retrieved[1] == "world")
        #expect(retrieved[2] == "swift")

        // Test with strings containing spaces (trimmed by parser)
        let testStringWithSpaces = "[ first , second , third ]"
        let attribute2 = try stringArrayDef.attribute(fromString: testStringWithSpaces)
        #expect(attribute2.stringValue == "[first,second,third]")
        graph = try graph.setting(node: node, attribute: attribute2)

        let retrieved2: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved2 == ["first", "second", "third"])

        let emptyArrayString = "[]"
        let attribute3 = try stringArrayDef.attribute(fromString: emptyArrayString)
        graph = try graph.setting(node: node, attribute: attribute3)

        let retrieved3: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved3.isEmpty, "\(retrieved3)")
        #expect(retrieved3.count == 0)

        let singleElementString = "[single]"
        let attribute4 = try stringArrayDef.attribute(fromString: singleElementString)
        graph = try graph.setting(node: node, attribute: attribute4)

        let retrieved4: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved4 == ["single"])
        #expect(retrieved4.count == 1)
    }

    @Test("A wrapped line that contains a comma stays one line")
    func arrayElementsKeepTheirCommas() throws(VError) {
        let lines = ["Yes, soon", "a\\b", "x,", ",y", "\\,"]
        let stored = Attributes.Node.wrappedText.attribute(lines)
        #expect(try Attributes.Node.wrappedText.value(fromString: stored.stringValue) == lines)
    }

    @Test("A backslash that escapes nothing is read as written, as values stored before escaping were")
    func strayBackslashesSurvive() throws(VError) {
        #expect(try [String].fromString("[C:\\temp,x\\]") == ["C:\\temp", "x\\"])
    }

    @Test
    func vRectAttributeType() throws(VError) {
        let bounds = Attributes.Group.layoutedBounds
        let testString = "10.0,20.0,100.0,50.0"
        let attribute = try bounds.attribute(fromString: testString)

        #expect(attribute.stringValue == testString)

        let group = Group(rawValue: "testGroup")
        let graph = try VGraph()
            .adding(group: group)
            .setting(group: group, attribute: attribute)

        #expect(try graph.get(group: group, attribute: bounds) == VRect(x: 10, y: 20, width: 100, height: 50))

        let rect = VRect(x: 5.5, y: 10.5, width: 200.0, height: 150.0)
        #expect(try VRect.fromString(rect.asString) == rect)

        #expect(throws: VError.conversionError(from: "invalid", to: "VRect")) {
            _ = try VRect.fromString("invalid")
        }

        #expect(throws: VError.conversionError(from: "1,2,3", to: "VRect")) {
            _ = try VRect.fromString("1,2,3")  // Only 3 components
        }
    }

    @Test("A new graph defines exactly the node, edge and group tables")
    func aNewGraphDefinesTheStandardTables() {
        let standard = Attributes.Node.definitions
            .merging(Attributes.Edge.definitions) { _, edge in edge }
            .merging(Attributes.Group.definitions) { _, group in group }
        #expect(VGraph().attributeDefinitions == standard)
    }
}
