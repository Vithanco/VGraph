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
        tGraph = try tGraph.add(nodeType: nt1)
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == nil)
        #expect(tGraph.metagraph.vertices.contains(nt1))
        #expect(!tGraph.metagraph.vertices.contains(nt2))
    }

    @Test
    func cannotAddNodeTypeTwice() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        #expect(throws: VError.nodeTypeAlreadyExists(nt1)) {
            tGraph = try tGraph.add(nodeType: nt1)
        }
    }

    @Test
    func adEdgeType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == nil)
        #expect(tGraph.metagraph.get(edge: et1.id) == et1)
        #expect(tGraph.metagraph.vertices.contains(nt1))
        #expect(tGraph.metagraph.vertices.contains(nt2))
    }

    @Test
    func addEdgeTypeRequiresNodeTypeFrom() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt2)
        #expect(throws: VError.nodeTypeNotFound(nt1)) {
            tGraph = try tGraph.add(edgeType: et1)
        }
    }

    @Test
    func addEdgeTypeRequiresNodeTypeTo() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        #expect(throws: VError.nodeTypeNotFound(nt2)) {
            tGraph = try tGraph.add(edgeType: et1)
        }
    }

    @Test
    func testAddNode() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == [n1])
        #expect(tGraph.graph.vertices.contains(n1))
    }

    @Test
    func cannotAddNodeTwice() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
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

    @Test
    func addEdge() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(node: n3, type: nt1)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == [e1.id])
        #expect(tGraph.graph.get(edge: e1.id) == e1)
        #expect(tGraph.graph.getEdges(from: n1, to: n2) == [e1])
        #expect(tGraph.graph.getEdges(from: n1, to: n3) == [])
        #expect(tGraph.graph.getEdges(from: n2, to: n1) == [])
    }

    /// Nodes and edge types refuse a second copy of an id; an edge used to be
    /// stored twice, after which lookup and delete each saw only one of them.
    @Test
    func addEdgeTwiceThrows() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
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
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(node: n3, type: nt1)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        tGraph = try tGraph.delete(edge: e1.id)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == nil)
        #expect(tGraph.graph.get(edge: e1.id) == nil)
        #expect(tGraph.graph.getEdges(from: n1, to: n2) == [])
        #expect(tGraph.graph.getEdges(from: n1, to: n3) == [])
        #expect(tGraph.graph.getEdges(from: n2, to: n1) == [])
    }

    @Test func changeEdge() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt2)
        tGraph = try tGraph.add(edge: e1, type: et1.id)
        tGraph = try tGraph.add(node: n3, type: nt2)
        let e3 = Edge(base: e1, to: n3)
        tGraph = try tGraph.redirect(edge: e3)
        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == [e3.id])
        #expect(tGraph.graph.get(edge: e1.id) == e3)
        #expect(tGraph.graph.getEdges(from: n1, to: n2) == [])
        #expect(tGraph.graph.getEdges(from: n1, to: n3) == [e3])
        #expect(tGraph.graph.getEdges(from: n2, to: n1) == [])
    }

    @Test("Retyping a node the graph does not have is an error")
    func setNodeTypeRequiresTheNode() throws(VError) {
        let tGraph = try TypedGraph().add(nodeType: nt1)
        #expect(throws: VError.nodeNotFound(n1)) {
            try tGraph.setNodeType(node: n1, type: nt1)
        }
    }

    @Test("Retyping an edge the graph does not have is an error")
    func setEdgeTypeRequiresTheEdge() throws(VError) {
        let tGraph = try TypedGraph().add(nodeType: nt1).add(nodeType: nt2).add(edgeType: et1)
        #expect(throws: VError.edgeNotFound(e1.id)) {
            try tGraph.setEdgeType(edge: e1.id, type: et1.id)
        }
    }

    @Test
    func addEdgeTypeRequiresEdgeType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt1)
        #expect(throws: VError.edgeTypeNotFound(et1.id)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func addEdgeTypeRequiresNodeFrom() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        tGraph = try tGraph.add(node: n2, type: nt1)
        #expect(throws: VError.nodeNotFound(n1)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func addEdgeTypeRequiresNodeTo() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(nodeType: nt2)
        tGraph = try tGraph.add(edgeType: et1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        #expect(throws: VError.nodeNotFound(n2)) {
            tGraph = try tGraph.add(edge: e1, type: et1.id)
        }
    }

    @Test
    func anUnusedNodeTypeIsDeleted() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.delete(nodeType: nt1)
        #expect(!tGraph.has(nodeType: nt1))
    }

    @Test
    func aNodeTypeStillInUseIsRefused() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(node: n1, type: nt1)

        #expect(throws: VError.nodeTypeStillInUse(nt1)) {
            _ = try tGraph.delete(nodeType: nt1)
        }
    }

    @Test
    func deletingANodeForgetsItsType() throws(VError) {
        var tGraph = TypedGraph()
        tGraph = try tGraph.add(nodeType: nt1)
        tGraph = try tGraph.add(node: n1, type: nt1)
        tGraph = try tGraph.add(node: n2, type: nt1)

        tGraph = try tGraph.delete(node: n1)

        #expect(tGraph.nodeTypeMapping.getOne(many: n1) == nil)
        #expect(tGraph.nodeTypeMapping.getMany(one: nt1) == [n2])
    }

    @Test("Deleting a node frees the type of every edge it took with it")
    func deletingANodeForgetsItsEdgesTypes() throws(VError) {
        let tGraph = try TypedGraph()
            .add(nodeType: nt1)
            .add(nodeType: nt2)
            .add(edgeType: et1)
            .add(node: n1, type: nt1)
            .add(node: n2, type: nt2)
            .add(edge: e1, type: et1.id)
            .delete(node: n2)

        #expect(tGraph.edgeTypeMapping.getMany(one: et1.id) == nil)
        #expect(!(try tGraph.delete(edgeType: et1.id)).has(edgeType: et1.id))
    }
}
