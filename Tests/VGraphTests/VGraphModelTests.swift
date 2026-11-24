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
            try network.attributes(node: "a").isEmpty
        }
        #expect(network.nodes.isEmpty)
        #expect(network.nodeTypes.isEmpty)
        #expect(network.edges.isEmpty)
        #expect(network.edgeTypes.isEmpty)
    }

    @Test
    func changeNodeAttribute() throws(VError) {
        var network = VGraph()
        network = try network.adding(nodeType: NodeType("a"))
        network = try network.defining(Attributes.Node.label)
        network = try network.adding(node: Node("node"), type: "a")
        network = try network.setting(node: "node", attribute: Attributes.Node.label("new"))
        #expect(network.nodes.count == 1)
        #expect(network.nodeTypes.count == 1)
        #expect(try network.attributes(node: "node").count == 1)
        let attrs = try network.attributes(node: "node")
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
            network = try network.adding(group: g1)
                .adding(nodeType: nt1)
                .adding(node: n1, type: nt1)
                .addingTo(group: g1, node: n1)
                .adding(group: g2)
                .addingTo(group: g1, childGroup: g2)
                .adding(node: n2, type: nt1)
                .addingTo(group: g2, node: n2)
        case .addedWithGroupThenAddToAgain:
            network = try network.adding(group: g1)
                .adding(nodeType: nt1)
                .adding(node: n1, type: nt1, group: g1)
                .addingTo(group: g1, node: n1)
                .adding(group: g2, childOf: g1)
                .addingTo(group: g1, childGroup: g2)
                .adding(node: n2, type: nt1, group: g2)
        }
        #expect(network.groups.contains(g1))
        #expect(try network.directContent(of: g1) == ([g2], [n1]))
        #expect(try network.allContent(of: g1) == ([g2], [n1, n2]))
        network = try network.deleting(node: n2)
        #expect(try network.allContent(of: g1) == ([g2], [n1]))
        #expect(network.group(of: n2) == nil)
    }

    @Test
    func anEdgeResolvesItselfThenItsType() throws(VError) {
        let network = try VGraph()
            .defining(Attributes.Edge.label)
            .defining(Attributes.Edge.arrowHead)
            .defining(Attributes.Edge.color)
            .defining(Attributes.Edge.arrowTail)
            .defining(Attributes.Edge.headLabel)
            .defining(Attributes.Edge.tailLabel)
            .adding(nodeType: nt1)
            .adding(edgeType: et1_1)
            .adding(group: g1)
            .adding(group: g2, childOf: g1)
            // Both ends of e1_2 sit in g2, which puts the edge there; it still
            // takes nothing from the graph (ADR-0030).
            .adding(node: n2, type: nt1, group: g2)
            .adding(node: n1, type: nt1, group: g2)
            .adding(node: n3, type: nt1)
            .adding(edge: e1_2, edgeType: et1_1)
            .adding(edge: e2_3, edgeType: et1_1)
            .setting(graphAttribute: Attributes.Edge.label("graph"))
            .setting(edgeType: et1_1.id, attribute: Attributes.Edge.arrowHead("type"))
            .setting(edge: e1_2.id, attribute: Attributes.Edge.headLabel("head"))
            .setting(edge: e2_3.id, attribute: Attributes.Edge.tailLabel("tail"))

        let edgeAttributes = try network.attributes(edge: e1_2.id)
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

        let edgeAttributes2 = try network.attributes(edge: e2_3.id)
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
            .adding(nodeType: nt1)
            .adding(edgeType: et1_1)
            .adding(group: g1)
            .adding(node: n1, type: nt1)
            .adding(node: n2, type: nt1)
            .adding(edge: e1_2, edgeType: et1_1)
            .adding(group: g2)
            .adding(node: n3, type: nt1)

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

    @Test("Given a node with a labelled edge, when the node is deleted, then the edge's id starts afresh")
    func deletingANodeForgetsItsEdges() throws(VError) {
        let network = try VGraph()
            .adding(nodeType: nt1)
            .adding(edgeType: et1_1)
            .adding(node: n1, type: nt1)
            .adding(node: n2, type: nt1)
            .adding(node: n3, type: nt1)
            .adding(edge: e1_2, edgeType: et1_1)
            .setting(edge: e1_2.id, attribute: Attributes.Edge.label("old"))
            .deleting(node: n2)

        let reused = try network.adding(edge: Edge(id: e1_2.id, from: n1, to: n3), edgeType: et1_1)

        #expect(try reused.get(edge: e1_2.id, attribute: Attributes.Edge.label) == "")
        #expect(reused.declarationPosition(of: e1_2.id) > reused.declarationPosition(of: n3))
        #expect(!(try network.deleting(edgeType: et1_1.id)).has(edgeType: et1_1.id))
    }

    @Test("The node types in use are listed in the order they were declared")
    func usedNodeTypesFollowDeclaration() throws(VError) {
        let used = (1...8).map { NodeType(rawValue: "used\($0)") }
        let unused = NodeType("unused")
        let declared = try (used + [unused]).folding(VGraph()) { (graph, type) throws(VError) in
            try graph.adding(nodeType: type)
        }
        let network = try used.folding(declared) { (graph, type) throws(VError) in
            try graph.adding(node: Node(rawValue: "node_\(type.id)"), type: type)
        }

        #expect(network.usedNodeTypes == used)
    }

    @Test("A loose name that fits several attributes finds none, rather than whichever the store lists first")
    func anAmbiguousLooseNameFindsNothing() {
        let network = VGraph()

        #expect(network.find(attributeByName: "size", for: .node) == nil)
        #expect(network.find(attributeByName: "length", for: .edge) == Attributes.Edge.len.asDefinition)
        #expect(network.find(attributeByName: "fontsize", for: .node) == Attributes.Node.fontsize.asDefinition)
    }
}
