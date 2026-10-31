// Specifies that VGraph.add(edge:edgeType:) rejects edges whose endpoints
// are the ids of existing groups. Groups can be folded and then represented as
// a node of the same id — edges to/from that folded-group node are fine because
// the group no longer exists at that point. These tests lock in the rule that
// a group (still present as a group) must never appear as an edge endpoint.

import Testing

@testable import VGraph

@Suite("VGraph.add(edge:) rejects group endpoints")
struct AddEdgeGroupEndpointTests {

    // MARK: - Fixtures

    let nodeType = NodeType("Concept")
    let edgeType = EdgeType(string: "connects", from: "Concept", to: "Concept")

    let nodeA = Node("a")
    let nodeB = Node("b")

    let group1 = Group(rawValue: "g1")
    let group2 = Group(rawValue: "g2")

    /// Graph with one node type, one edge type, two nodes, and one group — baseline for all tests.
    private func baseGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .defineStandardAttributes()
            .add(nodeType: nodeType)
            .add(edgeType: edgeType)
            .add(node: nodeA, type: nodeType)
            .add(node: nodeB, type: nodeType)
        graph = try graph.add(group: group1)
        return graph
    }

    // MARK: - Group endpoint rejection

    @Test("Given a group 'g1' and a node 'b', when an edge is added whose source is the group id, then an edgeEndpointIsGroup error is thrown")
    func rejectsGroupAsSource() throws(VError) {
        let graph = try baseGraph()
        let edge = Edge(string: "e1", from: group1.id.id, to: nodeB.id)

        #expect(throws: VError.edgeEndpointIsGroup(edge: edge.id, endpoint: group1)) {
            _ = try graph.add(edge: edge, edgeType: edgeType)
        }
    }

    @Test("Given a group 'g1' and a node 'a', when an edge is added whose target is the group id, then an edgeEndpointIsGroup error is thrown")
    func rejectsGroupAsTarget() throws(VError) {
        let graph = try baseGraph()
        let edge = Edge(string: "e1", from: nodeA.id, to: group1.id.id)

        #expect(throws: VError.edgeEndpointIsGroup(edge: edge.id, endpoint: group1)) {
            _ = try graph.add(edge: edge, edgeType: edgeType)
        }
    }

    @Test("Given two groups 'g1' and 'g2', when an edge is added between them, then an edgeEndpointIsGroup error is thrown")
    func rejectsGroupOnBothEnds() throws(VError) {
        var graph = try baseGraph()
        graph = try graph.add(group: group2)
        let edge = Edge(string: "e1", from: group1.id.id, to: group2.id.id)

        // The source is checked first — either group would be a valid failure.
        #expect(throws: VError.edgeEndpointIsGroup(edge: edge.id, endpoint: group1)) {
            _ = try graph.add(edge: edge, edgeType: edgeType)
        }
    }

    // MARK: - Normal cases still work

    @Test("Given two nodes 'a' and 'b', when a valid edge between them is added, then the graph contains the edge")
    func allowsEdgeBetweenNodes() throws(VError) {
        let graph = try baseGraph()
        let edge = Edge(string: "e1", from: nodeA.id, to: nodeB.id)

        let result = try graph.add(edge: edge, edgeType: edgeType)

        #expect(result.edges.contains { $0.id == edge.id })
    }
}
