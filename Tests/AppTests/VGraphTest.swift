import Testing

@testable import VGraph

struct VGraphTests {
    let nt1: NodeType
    let nt2: NodeType
    let et1_1: EdgeType
    let et1_2: EdgeType
    let n1: Node
    let n2: Node
    let n3: Node
    let n4: Node
    let e1_2: Edge
    let e2_3: Edge
    let g1: Group
    let g2: Group
    let g3: Group

    init() {
        nt1 = NodeType("nt1")
        nt2 = NodeType("nt2")

        et1_1 = EdgeType(id: "et1", from: nt1, to: nt1)
        et1_2 = EdgeType(id: "et1", from: nt1, to: nt2)

        n1 = Node("n1")
        n2 = Node("n2")
        n3 = Node("n3")
        n4 = Node("n4")

        e1_2 = Edge(id: "e1_2", from: n1, to: n2)
        e2_3 = Edge(id: "e2_3", from: n1, to: n3)

        g1 = Group(rawValue: "c1")
        g2 = Group(rawValue: "c2")
        g3 = Group(rawValue: "c3")
    }

    @Test
    func createEmptyNetwork() throws(VError) {
        let network = VGraph()
        #expect(throws: VError.nodeTypeNotFoundForNode("a")) {
            try network.getAttributes(node: "a").isEmpty
        }
        #expect(network.nodes.isEmpty)
        #expect(network.nodeTypes.isEmpty)
        #expect(network.edges.isEmpty)
        #expect(network.edgeTypes.isEmpty)
    }

    @Test
    func createNodeType() throws(VError) {
        var network = VGraph()
        network =
            try network
            .define(Attributes.Node.label)
            .add(nodeType: NodeType("a"))

        #expect(network.find(attributeByName: "label", for: .node) != nil)
        #expect(network.nodes.isEmpty)
        #expect(network.nodeTypes.count == 1)
        let allA = network.getAllAttributes(nodeType: NodeType("a"))
        #expect(allA.count == 0, "no attribute was used!")
    }

    @Test
    func createNodeTypeAttribute() throws(VError) {
        var network = VGraph()
        network =
            try network
            .define(Attributes.Node.label)
            .add(nodeType: NodeType("a"))
            .add(nodeType: NodeType("b"))
            .set(node: Node("b"), attribute: Attributes.Node.label.attribute("label"))

        #expect(network.find(attributeByName: "label", for: .node) != nil)
        #expect(network.nodes.isEmpty)
        #expect(network.nodeTypes.count == 2)
        let allA = network.getAllAttributes(nodeType: NodeType("a"))
        // getAllAttributes returns attributes actually set, not all defined attributes
        #expect(allA.count == 0, "\(allA)")  // No attributes set for node type "a"
    }

    @Test
    func createNode() throws(VError) {
        var network = VGraph()
        network =
            try network
            .add(nodeType: NodeType("a"))
            .define(attribute: Attributes.Node.label)
            .add(node: Node("node"), type: "a")
        #expect(network.getAllAttributes(nodeType: "a").count == 0)
        network = try network.set(node: "node", attribute: Attributes.Node.label.attribute(fromString: "a label"))
        #expect(network.nodes.count == 1)
        #expect(network.nodeTypes.count == 1)
        // After setting a node attribute, getAllAttributes for the type still returns 0
        // because the attribute is set on the node, not the node type
        #expect(network.getAllAttributes(nodeType: "a").count == 0)
    }

    @Test
    func changeNodeAttribute() throws(VError) {
        var network = VGraph()
        network = try network.add(nodeType: NodeType("a"))
        network = try network.define(attribute: Attributes.Node.label)
        network = try network.add(node: Node("node"), type: "a")
        network = try network.update(node: "node", attribute: Attributes.Node.label.attribute("new"))
        #expect(network.nodes.count == 1)
        #expect(network.nodeTypes.count == 1)
        #expect(try network.getAttributes(node: "node").count == 1)
        let attrs = try network.getAttributes(node: "node")
        let labelValue = attrs[Attributes.Node.label.id]
        #expect(labelValue == "new")
    }

    @Test
    func addGroup() throws(VError) {
        var network = VGraph()
        network = try network.add(group: g1)
            .add(nodeType: nt1)
            .add(node: n1, type: nt1)
            .addTo(group: g1, node: n1)
            .add(group: g2)
            .addTo(group: g1, childGroup: g2)
            .add(node: n2, type: nt1)
            .addTo(group: g2, node: n2)
        #expect(network.groups.contains(g1))
        #expect(try network.getDirectContent(group: g1) == ([g2], [n1]))
        #expect(try network.getAllContent(group: g1) == ([g2], [n1, n2]))
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 2, groupsInGroupCount: 1))
        network = try network.delete(node: n2)
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 1, groupsInGroupCount: 1))
    }

    @Test
    func addGroupShorterWay() throws(VError) {
        var network = VGraph()
        network = try network.add(group: g1)
            .add(nodeType: nt1)
            .add(node: n1, type: nt1, group: g1)
            .add(group: g2, childOf: g1)
            .add(node: n2, type: nt1, group: g2)
        #expect(network.groups.contains(g1))
        #expect(try network.getDirectContent(group: g1) == ([g2], [n1]))
        #expect(try network.getAllContent(group: g1) == ([g2], [n1, n2]))
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 2, groupsInGroupCount: 1))
        network = try network.delete(node: n2)
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 1, groupsInGroupCount: 1))
    }

    @Test
    func canAddGroupTwice() throws(VError) {
        var network = VGraph()
        network = try network.add(group: g1)
            .add(nodeType: nt1)
            .add(node: n1, type: nt1, group: g1)
            .addTo(group: g1, node: n1)
            .add(group: g2, childOf: g1)
            .addTo(group: g1, childGroup: g2)
            .add(node: n2, type: nt1, group: g2)
        #expect(network.groups.contains(g1))
        #expect(try network.getDirectContent(group: g1) == ([g2], [n1]))
        #expect(try network.getAllContent(group: g1) == ([g2], [n1, n2]))
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 2, groupsInGroupCount: 1))
        network = try network.delete(node: n2)
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 1, groupsInGroupCount: 1))
    }

    @Test
    func canRemoveFromGroup() throws(VError) {
        var network = VGraph()
        network = try network.add(group: g1)
            .add(nodeType: nt1)
            .add(node: n1, type: nt1, group: g1)
            .add(group: g2, childOf: g1)
            .addTo(group: nil, node: n1)
            .addTo(group: nil, childGroup: g2)
        #expect(network.groups.contains(g1))
        #expect(try network.getDirectContent(group: g1) == ([], []))
        #expect(try network.getAllContent(group: g1) == ([], []))
        #expect(
            network.groupStructure.counts == GroupStructure.Counts(groupCount: 2, nodeCount: 0, groupsInGroupCount: 0))
    }

    @Test
    func notChangingOldValues() throws(VError) {
        let network = try VGraph()
            .add(group: g1)
        let network2 = try network.add(nodeType: nt1).add(node: n1, type: nt1)
        #expect(
            network2.counts
                == VGraph
                .Counts(
                    graphCount: TypedGraph.Counts(nodes: 1, edges: 0, nodeTypes: 1, edgeTypes: 0),
                    adsCount: AttributeStore.Counts(definitions: VGraph().attributeDefinitions.count, entries: 0),
                    groupCount: GroupStructure.Counts(groupCount: 1, nodeCount: 0, groupsInGroupCount: 0)))
        #expect(
            network.counts
                == VGraph
                .Counts(
                    graphCount: TypedGraph.Counts(nodes: 0, edges: 0, nodeTypes: 0, edgeTypes: 0),
                    adsCount: AttributeStore.Counts(definitions: VGraph().attributeDefinitions.count, entries: 0),
                    groupCount: GroupStructure.Counts(groupCount: 1, nodeCount: 0, groupsInGroupCount: 0)))
    }

    @Test
    func addSubGraphAttribute() throws(VError) {
        let network = try VGraph().add(group: g1).define(Attributes.Group.label)
        let network2 = try network.set(group: g1, attribute: Attributes.Group.label.attribute("hello world"))

        #expect(try network.get(group: g1, attribute: Attributes.Group.label) == "")
        #expect(try network2.get(group: g1, attribute: Attributes.Group.label) == "hello world")
    }

    @Test
    func addGraphAttribute() throws(VError) {
        let network = try VGraph().define(Attributes.Group.label)
        #expect(try network.get(graphAttribute: Attributes.Group.label) == "")
        let network2 = try network.set(graphAttribute: Attributes.Group.label.attribute("hello world"))
        #expect(try network2.get(graphAttribute: Attributes.Group.label) == "hello world")
    }

    @Test
    func aNodeDoesNotTakeItsGroupsValues() throws(VError) {
        let group = Group(rawValue: "sub")
        let nodeType = NodeType(rawValue: "nt1")
        let node = Node(rawValue: "n1")
        let network = try VGraph()
            .define(Attributes.Node.label)
            .add(nodeType: nodeType)
            .add(group: group)
            .add(
                node: node,
                type: nodeType,
                group: group
            )
            .set(group: group, attribute: Attributes.Group.label.attribute("a Value"))

        // ADR-0030: a group says what belongs together, not what its members look like.
        let value = try network.get(node: node, attribute: Attributes.Group.label)
        #expect(value == Attributes.Group.label.defaultValue)
    }

    @Test
    func aNodeResolvesItselfThenItsType() throws(VError) {
        let s1 = Group(rawValue: "sub1")
        let s2 = Group(rawValue: "sub2")
        let nodeType = NodeType(rawValue: "nt1")
        let node = Node(rawValue: "n1")
        let node2 = Node(rawValue: "n2")
        let network = try VGraph()
            .define(Attributes.Node.label)
            .define(Attributes.Node.style)
            .define(Attributes.Node.margin)
            .define(Attributes.Node.tooltip)
            .define(Attributes.Node.position)
            .define(Attributes.Node.width)
            // Note: not defining height - test only checks specific 6 attributes
            .add(nodeType: nodeType)
            .add(group: s1)
            .add(group: s2, childOf: s1)
            .add(node: node2, type: nodeType)
            .add(
                node: node,
                type: nodeType,
                group: s2
            )
            .set(graphAttribute: Attributes.Node.tooltip, value: "graph")
            .set(nodeType: nodeType, def: Attributes.Node.label, value: "type")
            .set(node: node, def: Attributes.Node.position, value: VPoint(x: 42, y: 42).asString)
            .set(node: node2, def: Attributes.Node.width, value: 42.0)

        // Only the node and its type count (ADR-0030): the graph's tooltip does
        // not reach it.
        let nodeAttributes = try network.getAttributes(node: node)
        #expect(nodeAttributes.count == 2)
        let graphAtt = nodeAttributes.value(for: Attributes.Node.tooltip)
        #expect(graphAtt == Attributes.Node.tooltip.defaultValue)
        let label = nodeAttributes.value(for: Attributes.Node.label)
        #expect(label == "type")
        let margin = nodeAttributes.value(for: Attributes.Node.margin)
        #expect(margin == Attributes.Node.margin.defaultValue)
        let position = nodeAttributes.value(for: Attributes.Node.position)
        #expect(position == VPoint(x: 42, y: 42).asString)
        let width = nodeAttributes.value(for: Attributes.Node.width)
        #expect(width == Attributes.Node.width.defaultValue)

        let value2 = try network.getAttributes(node: node2)
        #expect(value2.count == 2)
        let tooltip2 = value2.value(for: Attributes.Node.tooltip)
        #expect(tooltip2 == Attributes.Node.tooltip.defaultValue)
        let label2 = value2.value(for: Attributes.Node.label)
        #expect(label2 == "type")
        let margin2 = value2.value(for: Attributes.Node.margin)
        #expect(margin2 == Attributes.Node.margin.defaultValue)
        let style2 = value2.value(for: Attributes.Node.style)
        #expect(style2 == Attributes.Node.style.defaultValue)
        let position2 = value2.value(for: Attributes.Node.position)
        #expect(position2 == Attributes.Node.position.defaultValue)
        let width2 = value2.value(for: Attributes.Node.width)
        #expect(width2 == 42.0)
    }

    @Test
    func anEdgeResolvesItselfThenItsType() throws(VError) {
        let network = try VGraph()
            .define(Attributes.Edge.label)
            .define(Attributes.Edge.arrowHead)
            .define(Attributes.Edge.color)
            .define(Attributes.Edge.arrowTail)
            .define(Attributes.Edge.headLabel)
            .define(Attributes.Edge.tailLabel)
            .add(nodeType: nt1)
            .add(edgeType: et1_1)
            .add(group: g1)
            .add(group: g2, childOf: g1)
            // Both ends of e1_2 sit in g2, which puts the edge there; it still
            // takes nothing from the graph (ADR-0030).
            .add(node: n2, type: nt1, group: g2)
            .add(node: n1, type: nt1, group: g2)
            .add(node: n3, type: nt1)
            .add(edge: e1_2, edgeType: et1_1)
            .add(edge: e2_3, edgeType: et1_1)
            .set(graphAttribute: Attributes.Edge.label, value: "graph")
            .set(edgeType: et1_1.id, attribute: Attributes.Edge.arrowHead.attribute("type"))
            .set(edge: e1_2.id, attribute: Attributes.Edge.headLabel.attribute("head"))
            .set(edge: e2_3.id, attribute: Attributes.Edge.tailLabel.attribute("tail"))

        let edgeAttributes = try network.getAttributes(edge: e1_2.id)
        #expect(edgeAttributes.count == 2)
        let edgeLabel = edgeAttributes.value(for: Attributes.Edge.label)
        #expect(edgeLabel == Attributes.Edge.label.defaultValue)
        let arrowHead = edgeAttributes.value(for: Attributes.Edge.arrowHead)
        #expect(arrowHead == "type")
        let edgeColor = edgeAttributes.value(for: Attributes.Edge.color)
        #expect(edgeColor == VColor.black)
        let arrowTail = edgeAttributes.value(for: Attributes.Edge.arrowTail)
        #expect(arrowTail == Attributes.Edge.arrowTail.defaultValue)
        let headLabel = edgeAttributes.value(for: Attributes.Edge.headLabel)
        #expect(headLabel == "head")
        let tailLabel = edgeAttributes.value(for: Attributes.Edge.tailLabel)
        #expect(tailLabel == "")

        let edgeAttributes2 = try network.getAttributes(edge: e2_3.id)
        #expect(edgeAttributes2.count == 2)
        let edgeLabel2 = edgeAttributes2.value(for: Attributes.Edge.label)
        #expect(edgeLabel2 == Attributes.Edge.label.defaultValue)
        let arrowHead2 = edgeAttributes2.value(for: Attributes.Edge.arrowHead)
        #expect(arrowHead2 == "type")
        let edgeColor2 = edgeAttributes2.value(for: Attributes.Edge.color)
        #expect(edgeColor2 == VColor.black)
        let arrowTail2 = edgeAttributes2.value(for: Attributes.Edge.arrowTail)
        #expect(arrowTail2 == Attributes.Edge.arrowTail.defaultValue)
        let headLabel2 = edgeAttributes2.value(for: Attributes.Edge.headLabel)
        #expect(headLabel2 == Attributes.Edge.headLabel.defaultValue)
        let tailLabel2 = edgeAttributes2.value(for: Attributes.Edge.tailLabel)
        #expect(tailLabel2 == "tail")
    }

    @Test
    func declarationOrderSequencing() throws(VError) {
        let network = try VGraph()
            .add(nodeType: nt1)
            .add(edgeType: et1_1)
            .add(group: g1)
            .add(node: n1, type: nt1)
            .add(node: n2, type: nt1)
            .add(edge: e1_2, edgeType: et1_1)
            .add(group: g2)
            .add(node: n3, type: nt1)

        let g1Order = network.declarationPosition(of: g1)
        let n1Order = network.declarationPosition(of: n1)
        let n2Order = network.declarationPosition(of: n2)
        let e1_2Order = network.declarationPosition(of: e1_2.id)
        let g2Order = network.declarationPosition(of: g2)
        let n3Order = network.declarationPosition(of: n3)

        #expect(g1Order == 1)
        #expect(n1Order == 2)
        #expect(n2Order == 3)
        #expect(e1_2Order == 4)
        #expect(g2Order == 5)
        #expect(n3Order == 6)
    }
}
