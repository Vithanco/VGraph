import Testing

@testable import VGraph

@Suite
struct TypedGraphTests {
    let nt1: NodeType
    let nt2: NodeType
    let et1: EdgeType
    let n1: Node
    let n2: Node
    let n3: Node
    let n4: Node
    let e1: Edge
    let e2: Edge

    init() {
        nt1 = NodeType("nt1")
        nt2 = NodeType("nt2")

        et1 = EdgeType(id: "et1", from: nt1, to: nt2)

        n1 = Node("n1")
        n2 = Node("n2")
        n3 = Node("n3")
        n4 = Node("n4")

        e1 = Edge(id: "e1", from: n1, to: n2)
        e2 = Edge(id: "21", from: n1, to: n3)
    }

    @Test
    func testAddNodeType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == nil)
        #expect(tGraph.metagraph.vertices.contains(nt1))
        #expect(!tGraph.metagraph.vertices.contains(nt2))
    }

    @Test
    func cannotAddNodeTypeTwice() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        #expect(throws: VError.nodeTypeAlreadyExists(nt1)) {
            tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        }
    }

    @Test
    func adEdgeType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == nil)
        #expect(tGraph.metagraph.get(edge: et1.id) == et1)
        #expect(tGraph.metagraph.vertices.contains(nt1))
        #expect(tGraph.metagraph.vertices.contains(nt2))
    }

    @Test
    func addEdgeTypeRequiresNodeTypeFrom() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        #expect(throws: VError.nodeTypeNotFound(nt1)) {
            tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        }
    }

    @Test
    func addEdgeTypeRequiresNodeTypeTo() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        #expect(throws: VError.nodeTypeNotFound(nt2)) {
            tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        }
    }

    @Test
    func testAddNode() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == [n1])
        #expect(tGraph.graph.vertices.contains(n1))
    }

    @Test
    func cannotAddNodeTwice() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        #expect(throws: VError.nodeAlreadyExists(n1)) {
            tGraph = try tGraph.add(node: n1, type: nt1)
        }
    }

    @Test
    func addNodefailsWithoutNodeType() throws(VError) {
        var tGraph = TypedGraph()
        #expect(throws: VError.nodeTypeNotFound(nt1)) {
            tGraph = try tGraph.add(node: n1, type: nt1)
        }
    }

    @Test func edgeTypeRequiresNodeTypeTo() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        #expect(throws: VError.nodeTypeNotFound(nt2)) {
            tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        }
    }

    @Test func edgeTypeRequiresNodeTypeFrom() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        #expect(throws: VError.nodeTypeNotFound(nt1)) {
            tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        }
    }

    @Test
    func addEdge() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(node: n3, type: nt1)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == [e1.id])
        #expect(tGraph.graph.get(edge: e1.id) == e1)
        #expect(tGraph.graph.edgeExists(from: n1, to: n2))
        #expect(!tGraph.graph.edgeExists(from: n1, to: n3))
        #expect(!tGraph.graph.edgeExists(from: n2, to: n1))
    }

    /// Nodes and edge types refuse a second copy of an id; an edge used to be
    /// stored twice, after which lookup and delete each saw only one of them.
    @Test
    func addEdgeTwiceThrows() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        #expect(throws: VError.edgeAlreadyExists(e1.id)) {
            try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func removeEdge() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(node: n3, type: nt1)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        tGraph = try tGraph.delete(edge: e1.id)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == nil)
        #expect(tGraph.graph.get(edge: e1.id) == nil)
        #expect(!tGraph.graph.edgeExists(from: n1, to: n2))
        #expect(!tGraph.graph.edgeExists(from: n1, to: n3))
        #expect(!tGraph.graph.edgeExists(from: n2, to: n1))
    }

    @Test func changeEdge() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        tGraph = try tGraph.add(node: n3, type: nt2)
        let e3 = Edge(base: e1, to: n3)
        tGraph = try tGraph.redirect(edge: e3)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == [e3.id])
        #expect(tGraph.graph.get(edge: e1.id) == e3)
        #expect(!tGraph.graph.edgeExists(from: n1, to: n2))
        #expect(tGraph.graph.edgeExists(from: n1, to: n3))
        #expect(!tGraph.graph.edgeExists(from: n2, to: n1))
    }

    @Test
    func addEdgeTypeRequiresEdgeType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt1)
        #expect(throws: VError.edgeTypeNotFound(et1.id)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func addEdgeTypeRequiresNodeFrom() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n2, type: nt1)
        #expect(throws: VError.nodeNotFound(n1)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func addEdgeTypeRequiresNodeTo() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(nodeType: nt2, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(edgeType: et1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        #expect(throws: VError.nodeNotFound(n2)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func notChangingOldValues() throws(VError) {
        let graph = try TypedGraph()
            .add(nodeType: nt1, notation: Notation(rawValue: "change me"))
            .add(node: n1, type: nt1)
        let graph2 =
            try graph
            .add(nodeType: nt2, notation: Notation(rawValue: "change me"))
            .add(node: n2, type: nt2)
        let graph3 =
            try graph2
            .add(edgeType: et1, notation: Notation(rawValue: "change me"))
        let graph4 =
            try graph3
            .add(edge: e1, type: et1.id)

        #expect(graph.counts == TypedGraph.Counts(nodes: 1, edges: 0, nodeTypes: 1, edgeTypes: 0))
        #expect(graph2.counts == TypedGraph.Counts(nodes: 2, edges: 0, nodeTypes: 2, edgeTypes: 0))
        #expect(graph3.counts == TypedGraph.Counts(nodes: 2, edges: 0, nodeTypes: 2, edgeTypes: 1))
        #expect(graph4.counts == TypedGraph.Counts(nodes: 2, edges: 1, nodeTypes: 2, edgeTypes: 1))
    }

    @Test
    func anUnusedNodeTypeIsDeleted() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.delete(nodeType: nt1)
        #expect(!tGraph.has(nodeType: nt1))
    }

    @Test
    func aNodeTypeStillInUseIsRefused() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)

        #expect(throws: VError.nodeTypeStillInUse(nt1)) {
            _ = try tGraph.delete(nodeType: nt1)
        }
    }

    @Test
    func deletingANodeForgetsItsType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1, notation: Notation(rawValue: "change me"))
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt1)

        tGraph = try tGraph.delete(node: n1)

        #expect(tGraph.nodeTypeMapping.getOne(many: n1) == nil)
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == [n2])
    }
}
