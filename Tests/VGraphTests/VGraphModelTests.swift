import Testing

@testable import VGraph

struct VGraphModelTests {
    let nt1: NodeType
    let et1_1: EdgeType
    let n1: Node
    let n2: Node
    let n3: Node
    let e1_2: Edge
    let e2_3: Edge
    let g1: Group
    let g2: Group

    init() {
        nt1 = NodeType("nt1")

        et1_1 = EdgeType(id: "et1", from: nt1, to: nt1)

        n1 = Node("n1")
        n2 = Node("n2")
        n3 = Node("n3")

        e1_2 = Edge(id: "e1_2", from: n1, to: n2)
        e2_3 = Edge(id: "e2_3", from: n1, to: n3)

        g1 = Group(rawValue: "c1")
        g2 = Group(rawValue: "c2")
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

    /// `addTo` on a membership that already exists is a no-op here, unlike on
    /// GroupStructure, which refuses it.
    enum Construction: String, CaseIterable {
        case addToOnly
        case addedWithGroupThenAddToAgain
    }

    @Test(arguments: Construction.allCases)
    func groupMembershipIsIdempotent(_ construction: Construction) throws(VError) {
        var network = VGraph()
        switch construction {
        case .addToOnly:
            network = try network.add(group: g1)
                .add(nodeType: nt1)
                .add(node: n1, type: nt1)
                .addTo(group: g1, node: n1)
                .add(group: g2)
                .addTo(group: g1, childGroup: g2)
                .add(node: n2, type: nt1)
                .addTo(group: g2, node: n2)
        case .addedWithGroupThenAddToAgain:
            network = try network.add(group: g1)
                .add(nodeType: nt1)
                .add(node: n1, type: nt1, group: g1)
                .addTo(group: g1, node: n1)
                .add(group: g2, childOf: g1)
                .addTo(group: g1, childGroup: g2)
                .add(node: n2, type: nt1, group: g2)
        }
        #expect(network.groups.contains(g1))
        #expect(try network.getDirectContent(group: g1) == ([g2], [n1]))
        #expect(try network.getAllContent(group: g1) == ([g2], [n1, n2]))
        network = try network.delete(node: n2)
        #expect(try network.getAllContent(group: g1) == ([g2], [n1]))
        #expect(network.group(of: n2) == nil)
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
        #expect(network.group(of: n1) == nil)
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
