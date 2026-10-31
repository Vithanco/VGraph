// Nodes, edges and groups share one id space: edges, the editor and folding
// look elements up by bare id, so a node and a group with the same id would be
// ambiguous. Attributes no longer share it: they are keyed by (kind, id)
// (ADR-0030), so a node may share its id with a type.
//
// These tests lock in two guarantees:
// 1. Adding a node, edge or group whose id another of those already has THROWS
//    `VError.idCollision`.
// 2. Every `delete(...)` frees its id, so reusing an id after deletion is safe.

import Testing

@testable import VGraph

@Suite("ID collision detection")
struct IdCollisionTests {

    // MARK: - Cross-kind collisions via VGraph public API

    @Test("A node may share its id with a node type, and each keeps its own values")
    func aNodeMayShareItsIdWithANodeType() throws(VError) {
        let nodeType = NodeType(string: "Question")
        let graph = try VGraph().defineStandardAttributes()
            .add(nodeType: nodeType)
            .add(node: Node(string: "Question"), type: nodeType)
            .set(nodeType: nodeType, attribute: Attributes.Node.fontsize.attribute(20))
            .set(node: Node(string: "Question"), attribute: Attributes.Node.fontsize.attribute(30))
        #expect(try graph.get(nodeType: nodeType, attribute: Attributes.Node.fontsize) == 20)
        #expect(try graph.get(node: Node(string: "Question"), attribute: Attributes.Node.fontsize) == 30)
    }

    @Test("Group id cannot collide with existing Node id")
    func groupIdCollidesWithNode() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(string: "T")
        graph = try graph.add(nodeType: nodeType)
        graph = try graph.add(node: Node(string: "shared"), type: nodeType)

        #expect(throws: VError.idCollision(id: "shared")) {
            _ = try graph.add(group: Group(rawValue: "shared"))
        }
    }

    @Test("Node id cannot collide with existing Group id")
    func nodeIdCollidesWithGroup() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(string: "T")
        graph = try graph.add(nodeType: nodeType)
        graph = try graph.add(group: Group(rawValue: "shared"))

        #expect(throws: VError.idCollision(id: "shared")) {
            _ = try graph.add(node: Node(string: "shared"), type: nodeType)
        }
    }

    // MARK: - delete symmetry: every add has a matching delete that frees the id

    @Test("delete(node:) frees the id for reuse")
    func deleteNodeFreesId() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(string: "T")
        graph = try graph.add(nodeType: nodeType)
        let node = Node(string: "reuseMe")
        graph = try graph.add(node: node, type: nodeType)
        graph = try graph.delete(node: node)

        // Reusing the id for a Group must now succeed.
        _ = try graph.add(group: Group(rawValue: "reuseMe"))
    }

    @Test("delete(group:) frees the id for reuse")
    func deleteGroupFreesId() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(string: "T")
        graph = try graph.add(nodeType: nodeType)
        let group = Group(rawValue: "reuseMe")
        graph = try graph.add(group: group)
        graph = try graph.delete(group: group)

        // Reusing the id for a Node must now succeed.
        _ = try graph.add(node: Node(string: "reuseMe"), type: nodeType)
    }

    // Note: `delete(nodeType:)` has a pre-existing quirk (requires the type to have
    // been attached to at least one node, and still "in use" detection returns wrong
    // result for never-used types). Its values are cleared by the same
    // `removeKey` as a node's, edge's or group's.

    @Test("delete(edge:) frees the id for reuse")
    func deleteEdgeFreesId() throws(VError) {
        var graph = VGraph()
        let nt = NodeType(string: "T")
        graph = try graph.add(nodeType: nt)
        graph = try graph.add(node: Node(string: "a"), type: nt)
        graph = try graph.add(node: Node(string: "b"), type: nt)
        let et = EdgeType(id: "e", from: nt, to: nt)
        graph = try graph.add(edgeType: et)
        let edge = Edge(id: Edge.Id(string: "reuseMe"), from: Node(string: "a"), to: Node(string: "b"))
        graph = try graph.add(edge: edge, edgeType: et)
        graph = try graph.delete(edge: edge.id)

        // Reusing the id for a Group must now succeed.
        _ = try graph.add(group: Group(rawValue: "reuseMe"))
    }
}
