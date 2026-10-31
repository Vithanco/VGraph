// Specifies that DotExporter emits every edge's id as a DOT `id="..."`
// attribute so that the layout engine can key returned edge layouts by
// the same id the model uses. Without this, the layout data round-trip
// depends on edge iteration order, which has bitten us in practice
// (see: dir="back" arrows disappearing on short edges in ConceptMaps).

import Testing

@testable import VGraph
@testable import VGraphvizLib

@Suite("DotExporter emits edge id as a DOT attribute")
struct DotExporterEdgeIdTests {

    // MARK: - Fixtures

    let nodeType = NodeType("Concept")
    let edgeType = EdgeType(string: "connects", from: "Concept", to: "Concept")

    let nodeA = Node("a")
    let nodeB = Node("b")

    private func graphWithTwoNodes() throws(VError) -> VGraph {
        try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nodeType)
            .add(edgeType: edgeType)
            .add(node: nodeA, type: nodeType)
            .add(node: nodeB, type: nodeType)
    }

    // MARK: - Edge id emission

    @Test("Given an edge with id 'e1', when exported to DOT, then the edge's attribute block contains id=\"e1\"")
    func edgeIdIsEmittedAsAttribute() throws(VError) {
        var graph = try graphWithTwoNodes()
        graph = try graph.add(edge: Edge(string: "e1", from: nodeA.id, to: nodeB.id), edgeType: edgeType)

        let dot = try DotExporter().export(graph: graph)

        #expect(dot.contains("id=\"e1\""))
    }

    @Test("Given two edges between the same node pair with ids 'e1' and 'e2', when exported to DOT, then both ids appear in the output")
    func parallelEdgesEmitDistinctIds() throws(VError) {
        var graph = try graphWithTwoNodes()
        graph = try graph.add(edge: Edge(string: "e1", from: nodeA.id, to: nodeB.id), edgeType: edgeType)
        graph = try graph.add(edge: Edge(string: "e2", from: nodeA.id, to: nodeB.id), edgeType: edgeType)

        let dot = try DotExporter().export(graph: graph)

        #expect(dot.contains("id=\"e1\""))
        #expect(dot.contains("id=\"e2\""))
    }
}
