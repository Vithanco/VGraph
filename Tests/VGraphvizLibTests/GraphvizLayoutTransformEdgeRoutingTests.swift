// Specifies the contract between GraphvizLibLayoutEngine.layout(graph:)
// (which reads layouts out of GraphLayoutData.edgeLayouts) and the model's
// edges: each edge must receive the layout data that was computed for
// it, not for some other edge that happens to share the same positional
// slot. The previous index-based keying broke this whenever Graphviz's
// node-outgoing iteration order diverged from the model's edge order.

import Testing
import VGraph
import VGraphvizLib

@Suite("Layout data is applied to the correct model edge")
struct GraphvizLayoutTransformEdgeRoutingTests {

    struct SilentLogger: ForLogMessages {
        func log(_ message: String) {}
        func error(_ message: String) {}
    }

    // MARK: - Fixtures

    let nodeType = NodeType("Concept")
    let edgeType = EdgeType(string: "connects", from: "Concept", to: "Concept")

    let nodeA = Node("a")
    let nodeB = Node("b")
    let nodeC = Node("c")
    let nodeD = Node("d")

    /// Three edges ordered A→B, B→C, A→D in model-insertion order. Node A's
    /// outgoing edges are deliberately non-contiguous in that order.
    private func nonContiguousEdgeGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nodeType)
            .add(edgeType: edgeType)
            .add(node: nodeA, type: nodeType)
            .add(node: nodeB, type: nodeType)
            .add(node: nodeC, type: nodeType)
            .add(node: nodeD, type: nodeType)

        graph = try graph.add(edge: Edge(string: "e_ab", from: nodeA.id, to: nodeB.id), edgeType: edgeType)
        graph = try graph.add(edge: Edge(string: "e_bc", from: nodeB.id, to: nodeC.id), edgeType: edgeType)
        graph = try graph.add(edge: Edge(string: "e_ad", from: nodeA.id, to: nodeD.id), edgeType: edgeType)
        return graph
    }

    // MARK: - Routing

    @Test(
        "Given a graph where node A has non-contiguous outgoing edges in model order, when layout data keyed by edge id is applied, then each model edge receives the layout data for its own id (not a neighbour's)"
    )
    func eachEdgeReceivesItsOwnLayoutData() throws(VError) {
        let graph = try nonContiguousEdgeGraph()

        // Build three layout entries with visibly distinct spline endpoints so
        // we can assert which edge received which layout.
        // Use 4 points (cubic bezier: 3n+1) to match the shape Graphviz emits.
        let layoutAB = EdgeLayoutData(splinePoints: [
            VPoint(x: 1, y: 1), VPoint(x: 1, y: 2), VPoint(x: 1, y: 3), VPoint(x: 1, y: 4),
        ])
        let layoutBC = EdgeLayoutData(splinePoints: [
            VPoint(x: 10, y: 10), VPoint(x: 10, y: 20), VPoint(x: 10, y: 30), VPoint(x: 10, y: 40),
        ])
        let layoutAD = EdgeLayoutData(splinePoints: [
            VPoint(x: 100, y: 100), VPoint(x: 100, y: 200), VPoint(x: 100, y: 300), VPoint(x: 100, y: 400),
        ])

        let layoutData = GraphLayoutData(
            edgeLayouts: [
                "e_ab": layoutAB,
                "e_bc": layoutBC,
                "e_ad": layoutAD,
            ]
        )

        let updated = try applyLayoutData(layoutData, to: graph, logger: SilentLogger())

        let ab: EdgeLayoutData = try updated.get(edge: Edge.Id(string: "e_ab"), attribute: Attributes.Edge.layoutData)
        let bc: EdgeLayoutData = try updated.get(edge: Edge.Id(string: "e_bc"), attribute: Attributes.Edge.layoutData)
        let ad: EdgeLayoutData = try updated.get(edge: Edge.Id(string: "e_ad"), attribute: Attributes.Edge.layoutData)

        #expect(ab.splinePoints.first == VPoint(x: 1, y: 1))
        #expect(bc.splinePoints.first == VPoint(x: 10, y: 10))
        #expect(ad.splinePoints.first == VPoint(x: 100, y: 100))
    }
}
