import Testing

@testable import VGraph

@Suite("Attribute Tests")
struct AttributeTests {
    let node = ItemKey(.node, "node")
    let nodeLabel = Attributes.Node.label
    let edgeLabel = Attributes.Edge.label

    @Test
    func testEmptyDefault() throws(VError) {
        let ads = AttributeStore()
        #expect(ads.counts == AttributeStore.Counts(definitions: 0, entries: 0))
    }

    @Test
    func testNoLongerEmpty() throws(VError) {
        let ads = try AttributeStore().define(nodeLabel)
            .set(nodeLabel.attribute("node.nodeName"), for: node, in: .model, chains: ChainTable())
        #expect(ads.counts == AttributeStore.Counts(definitions: 1, entries: 1))
    }

    @Test
    func testDefNeedsToExist() throws(VError) {
        let ads = AttributeStore()
        #expect(throws: VError.attributeNotFound(nodeLabel.id)) {
            _ = try ads.getAttributeDefinition(nodeLabel.id)
        }
    }

    @Test
    func aKeyNobodyWroteResolvesToTheDefault() throws(VError) {
        let ads = try AttributeStore().define(nodeLabel)
        #expect(try ads.values(in: .model, for: node).isEmpty)
        #expect(try ads.resolve(nodeLabel.id, for: node, through: .model, chains: ChainTable()).value == nodeLabel.defaultValue)
    }

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

    @Test
    func getAllDefintions() throws(VError) {
        var ads = AttributeStore()
        ads = try ads.define(nodeLabel).define(edgeLabel)
        let lhs: [String] = ads.definitions.values.map { $0.id.description }.sorted()
        let expected: [AttributeDefinition] = [nodeLabel.asDefinition, edgeLabel.asDefinition]
        let rhs: [String] = expected.map { $0.id.description }.sorted()
        #expect(lhs == rhs)
    }

    @Test
    func cannotDefineTwice() throws(VError) {
        var ads = AttributeStore()
        ads = try ads.define(nodeLabel)
        #expect(ads.counts.definitions == 1)
        ads = try ads.define(nodeLabel)
        #expect(ads.counts.definitions == 1)
        let newNodeName = AttributeDefinition(
            id: nodeLabel.id,
            name: "another name",
            description: nodeLabel.description,
            defaultValue: nodeLabel.defaultValue,
            target: nodeLabel.target,
            typeAsString: String.typeName
        )
        #expect(throws: VError.definitionAlreadyExists(nodeLabel.id)) {
            ads = try ads.define(newNodeName)
        }
    }

    @Test
    func notChangingOldValues() throws(VError) {
        let ads = try AttributeStore().define(nodeLabel)
            .set(nodeLabel.attribute("one"), for: ItemKey(.node, "1"), in: .model, chains: ChainTable())
        let ads2 = try ads.set(nodeLabel.attribute("two"), for: ItemKey(.node, "2"), in: .model, chains: ChainTable())
        #expect(ads.counts.entries == 1)
        #expect(ads2.counts.entries == 2)
    }

    @Test
    func arrayAttribute() throws {
        let problems = TypedAttributeDefinition<[MessageWithSeverity]>(
            id: "test.problems", name: "problems", description: "", defaultValue: [], target: .node)
        let testString = "  [ {error|prob1},{warning|prob2} ,  {info|prob3}  ]  "
        let attribute = try problems.attribute(fromString: testString)
        // Normalized form: whitespace stripped during parse → asString round-trip
        #expect(attribute.stringValue == "[{error|prob1},{warning|prob2},{info|prob3}]")
        #expect(
            try problems.value(fromString: attribute.stringValue) == [
                MessageWithSeverity(message: "prob1", severity: .error),
                MessageWithSeverity(message: "prob2", severity: .warning),
                MessageWithSeverity(message: "prob3", severity: .info),
            ])
    }

    @Test
    func defineThrowsErrorIfWrongTarget() throws(VError) {
        let nodeType = NodeType("TestNodeTyoe")
        let node = Node("TestNode")
        let edgeType = EdgeType(id: "testEdgeType", from: nodeType, to: nodeType)
        let edge = Edge(id: "testEdge", from: node, to: node)
        let group = Group(rawValue: "group")
        let graph = try VGraph()
            .add(nodeType: nodeType)
            .add(node: node, type: nodeType)
            .add(edgeType: edgeType)
            .add(group: group)
            .add(edge: edge, edgeType: edgeType)

        #expect(throws: VError.wrongTarget(is: .graph, insteadOf: .node)) {
            try graph.set(node: node, attribute: Attributes.Group.label.attribute("a Label"))
        }
        #expect(throws: VError.wrongTarget(is: .graph, insteadOf: .edge)) {
            try graph.set(edge: edge, attribute: Attributes.Group.label.attribute("a Label"))
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
            .add(nodeType: nodeType)
            .add(node: node, type: nodeType)
            .define(stringArrayDef)
            .set(node: node, attribute: attribute)

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
        graph = try graph.set(node: node, attribute: attribute2)

        let retrieved2: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved2 == ["first", "second", "third"])

        let emptyArrayString = "[]"
        let attribute3 = try stringArrayDef.attribute(fromString: emptyArrayString)
        graph = try graph.set(node: node, attribute: attribute3)

        let retrieved3: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved3.isEmpty, "\(retrieved3)")
        #expect(retrieved3.count == 0)

        let singleElementString = "[single]"
        let attribute4 = try stringArrayDef.attribute(fromString: singleElementString)
        graph = try graph.set(node: node, attribute: attribute4)

        let retrieved4: [String] = try graph.get(node: node, attribute: stringArrayDef)
        #expect(retrieved4 == ["single"])
        #expect(retrieved4.count == 1)
    }

    @Test
    func vRectAttributeType() throws(VError) {
        let rectDef = TypedAttributeDefinition<VRect>(
            id: "test.rect",
            name: "Test Rect",
            description: "A rect for testing",
            defaultValue: VRect.zero,
            target: .node
        )

        let testString = "10.0,20.0,100.0,50.0"
        let attribute = try rectDef.attribute(fromString: testString)

        #expect(attribute.stringValue == testString)

        let node = Node("testNode")
        let nodeType = NodeType("testNodeType")

        let graph = try VGraph()
            .add(nodeType: nodeType)
            .add(node: node, type: nodeType)
            .define(rectDef)
            .set(node: node, attribute: attribute)

        // Retrieve and verify we get the correct VRect
        let retrieved: VRect = try graph.get(node: node, attribute: rectDef)
        #expect(retrieved.x == 10.0)
        #expect(retrieved.y == 20.0)
        #expect(retrieved.width == 100.0)
        #expect(retrieved.height == 50.0)

        let rect = VRect(x: 5.5, y: 10.5, width: 200.0, height: 150.0)
        let rectString = rect.asString
        let parsedRect = try VRect.fromString(rectString)
        #expect(parsedRect.x == rect.x)
        #expect(parsedRect.y == rect.y)
        #expect(parsedRect.width == rect.width)
        #expect(parsedRect.height == rect.height)

        let zeroRect = VRect.zero
        #expect(zeroRect.x == 0.0)
        #expect(zeroRect.y == 0.0)
        #expect(zeroRect.width == 0.0)
        #expect(zeroRect.height == 0.0)

        #expect(throws: VError.conversionError(from: "invalid", to: "VRect")) {
            _ = try VRect.fromString("invalid")
        }

        #expect(throws: VError.conversionError(from: "1,2,3", to: "VRect")) {
            _ = try VRect.fromString("1,2,3")  // Only 3 components
        }
    }

    @Test("Given the standard tables, then each is a constant and a new graph defines exactly them")
    func standardTablesAreConstants() {
        #expect(Attributes.Node.definitions[Attributes.Node.label.id] != nil)
        #expect(Attributes.Edge.definitions[Attributes.Edge.label.id] != nil)
        #expect(Attributes.Group.definitions[Attributes.Group.layoutedBounds.id] != nil)
        #expect(Attributes.Loop.definitions[Attributes.Loop.style.id] != nil)
        let standard = combine(
            parent: combine(parent: Attributes.Node.definitions, child: Attributes.Edge.definitions),
            child: Attributes.Group.definitions)
        #expect(VGraph().attributeDefinitions == standard)
    }

    @Test
    func groupAttributesWithVRect() throws(VError) {
        let layoutedBoundsDef = Attributes.Group.layoutedBounds
        #expect(layoutedBoundsDef.id.id == "group.layoutedBounds")
        #expect(layoutedBoundsDef.defaultValue == VRect.zero)

        let group = Group(rawValue: "testGroup")
        let nodeType = NodeType("testNodeType")
        let node = Node("testNode")

        var graph = try VGraph()
            .add(nodeType: nodeType)
            .add(node: node, type: nodeType)
            .add(group: group)
            .addTo(group: group, node: node)

        // Set layouted bounds on the group
        let bounds = VRect(x: 10, y: 20, width: 100, height: 50)
        graph = try graph.set(group: group, attribute: layoutedBoundsDef.attribute(bounds))

        // Retrieve and verify
        let retrievedBounds: VRect = try graph.get(group: group, attribute: layoutedBoundsDef)
        #expect(retrievedBounds.x == 10)
        #expect(retrievedBounds.y == 20)
        #expect(retrievedBounds.width == 100)
        #expect(retrievedBounds.height == 50)
    }

    @Test
    func nestedGroupsWithLayoutedBounds() throws(VError) {
        let nodeType = NodeType("testNodeType")
        let node1 = Node("node1")
        let node2 = Node("node2")
        let parentGroup = Group(rawValue: "parentGroup")
        let childGroup = Group(rawValue: "childGroup")

        var graph = try VGraph()
            .add(nodeType: nodeType)
            .add(node: node1, type: nodeType)
            .add(node: node2, type: nodeType)
            .add(group: parentGroup)
            .add(group: childGroup, childOf: parentGroup)
            .addTo(group: parentGroup, node: node1)
            .addTo(group: childGroup, node: node2)

        // Set layouted bounds on both groups
        let parentBounds = VRect(x: 0, y: 0, width: 200, height: 150)
        let childBounds = VRect(x: 10, y: 10, width: 80, height: 60)

        graph = try graph.set(group: parentGroup, attribute: Attributes.Group.layoutedBounds.attribute(parentBounds))
        graph = try graph.set(group: childGroup, attribute: Attributes.Group.layoutedBounds.attribute(childBounds))

        let retrievedParent: VRect = try graph.get(group: parentGroup, attribute: Attributes.Group.layoutedBounds)
        let retrievedChild: VRect = try graph.get(group: childGroup, attribute: Attributes.Group.layoutedBounds)

        #expect(retrievedParent.width == 200)
        #expect(retrievedChild.width == 80)

        #expect(graph.groups.count == 2)
    }

    // MARK: - What an edge inherits from the graph

    /// No node is grouped, so the edge is in no group either and falls back to
    /// the graph's own attributes — which for an edge means the *edge* ones.
    private func ungroupedEdge() throws(VError) -> (VGraph, Edge) {
        let nodeType = NodeType("Concept")
        let edgeType = EdgeType(string: "connects", from: "Concept", to: "Concept")
        let a = Node("a")
        let b = Node("b")
        let edge = Edge(string: "e1", from: a.id, to: b.id)

        let graph = try VGraph()
            .define(Attributes.Edge.color)
            .define(Attributes.Node.tooltip)
            .add(nodeType: nodeType)
            .add(edgeType: edgeType)
            .add(node: a, type: nodeType)
            .add(node: b, type: nodeType)
            .add(edge: edge, edgeType: edgeType)
        return (graph, edge)
    }

    /// ADR-0030: the graph is in no other element's chain.
    @Test("An ungrouped edge does not take the graph's edge values")
    func ungroupedEdgeIgnoresGraphEdgeAttributes() throws(VError) {
        var (graph, edge) = try ungroupedEdge()
        graph = try graph.set(graphAttribute: Attributes.Edge.color.attribute(VColor(named: "blue")!))

        #expect(graph.group(of: edge.id) == nil, "the fixture must reach the ungrouped branch")

        let attributes = try graph.getAttributes(edge: edge.id)
        #expect(attributes[Attributes.Edge.color.id] == nil)
    }

    @Test("An ungrouped edge does not inherit the graph's node attributes")
    func ungroupedEdgeIgnoresGraphNodeAttributes() throws(VError) {
        var (graph, edge) = try ungroupedEdge()
        graph = try graph.set(graphAttribute: Attributes.Node.tooltip.attribute("for nodes only"))

        let attributes = try graph.getAttributes(edge: edge.id)
        #expect(attributes[Attributes.Node.tooltip.id] == nil)
    }
}
