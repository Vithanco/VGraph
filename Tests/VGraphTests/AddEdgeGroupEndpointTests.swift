// Specifies that VGraph.add(edge:edgeType:) rejects edges whose endpoints
// are the ids of existing groups. Groups can be folded and then represented as
// a node of the same id — edges to/from that folded-group node are fine because
// the group no longer exists at that point. These tests lock in the rule that
// a group (still present as a group) must never appear as an edge endpoint.

import Testing

@testable import VGraph

@Suite("VGraph.adding(edge:) rejects group endpoints")
struct AddEdgeGroupEndpointTests {

    // MARK: - Fixtures

    let nodeType = NodeType("Concept")
    let edgeType = EdgeType(string: "connects", from: "Concept", to: "Concept")

    let nodeA = Node("a")
    let nodeB = Node("b")

    let group1 = Group(rawValue: "g1")

    /// Graph with one node type, one edge type, two nodes, and one group — baseline for all tests.
    private func baseGraph() throws(VError) -> VGraph {
        var graph = try VGraph()
            .adding(nodeType: nodeType)
            .adding(edgeType: edgeType)
            .adding(node: nodeA, type: nodeType)
            .adding(node: nodeB, type: nodeType)
        graph = try graph.adding(group: group1)
        return graph
    }

    // MARK: - Group endpoint rejection

    @Test("Given a group 'g1' and a node 'b', when an edge is added whose source is the group id, then an edgeEndpointIsGroup error is thrown")
    func rejectsGroupAsSource() throws(VError) {
        let graph = try baseGraph()
        let edge = Edge(string: "e1", from: group1.id.id, to: nodeB.id)

        #expect(throws: VError.edgeEndpointIsGroup(edge: edge.id, endpoint: group1)) {
            _ = try graph.adding(edge: edge, edgeType: edgeType)
        }
    }

    @Test("Given a group 'g1' and a node 'a', when an edge is added whose target is the group id, then an edgeEndpointIsGroup error is thrown")
    func rejectsGroupAsTarget() throws(VError) {
        let graph = try baseGraph()
        let edge = Edge(string: "e1", from: nodeA.id, to: group1.id.id)

        #expect(throws: VError.edgeEndpointIsGroup(edge: edge.id, endpoint: group1)) {
            _ = try graph.adding(edge: edge, edgeType: edgeType)
        }
    }
}
