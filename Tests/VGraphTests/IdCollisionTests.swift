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
        let nodeType = NodeType(rawValue: "Question")
        let graph = try VGraph()
            .adding(nodeType: nodeType)
            .adding(node: Node(rawValue: "Question"), type: nodeType)
            .setting(nodeType: nodeType, attribute: Attributes.Node.fontsize.attribute(20))
            .setting(node: Node(rawValue: "Question"), attribute: Attributes.Node.fontsize.attribute(30))
        #expect(try graph.get(nodeType: nodeType, attribute: Attributes.Node.fontsize) == 20)
        #expect(try graph.get(node: Node(rawValue: "Question"), attribute: Attributes.Node.fontsize) == 30)
    }

    @Test("Group id cannot collide with existing Node id")
    func groupIdCollidesWithNode() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(rawValue: "T")
        graph = try graph.adding(nodeType: nodeType)
        graph = try graph.adding(node: Node(rawValue: "shared"), type: nodeType)

        #expect(throws: VError.idCollision(id: "shared")) {
            _ = try graph.adding(group: Group(rawValue: "shared"))
        }
    }

    @Test("Node id cannot collide with existing Group id")
    func nodeIdCollidesWithGroup() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(rawValue: "T")
        graph = try graph.adding(nodeType: nodeType)
        graph = try graph.adding(group: Group(rawValue: "shared"))

        #expect(throws: VError.idCollision(id: "shared")) {
            _ = try graph.adding(node: Node(rawValue: "shared"), type: nodeType)
        }
    }

    // MARK: - delete symmetry: every add has a matching delete that frees the id

    @Test("deleting(node:) frees the id for reuse")
    func deleteNodeFreesId() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(rawValue: "T")
        graph = try graph.adding(nodeType: nodeType)
        let node = Node(rawValue: "reuseMe")
        graph = try graph.adding(node: node, type: nodeType)
        graph = try graph.deleting(node: node)

        // Reusing the id for a Group must now succeed.
        _ = try graph.adding(group: Group(rawValue: "reuseMe"))
    }

    @Test("deleting(group:) frees the id for reuse")
    func deleteGroupFreesId() throws(VError) {
        var graph = VGraph()
        let nodeType = NodeType(rawValue: "T")
        graph = try graph.adding(nodeType: nodeType)
        let group = Group(rawValue: "reuseMe")
        graph = try graph.adding(group: group)
        graph = try graph.deleting(group: group)

        // Reusing the id for a Node must now succeed.
        _ = try graph.adding(node: Node(rawValue: "reuseMe"), type: nodeType)
    }

    // Note: `deleting(nodeType:)` has a pre-existing quirk (requires the type to have
    // been attached to at least one node, and still "in use" detection returns wrong
    // result for never-used types). Its values are cleared by the same
    // `removeKey` as a node's, edge's or group's.

    @Test("deleting(edge:) frees the id for reuse")
    func deleteEdgeFreesId() throws(VError) {
        var graph = VGraph()
        let nt = NodeType(rawValue: "T")
        graph = try graph.adding(nodeType: nt)
        graph = try graph.adding(node: Node(rawValue: "a"), type: nt)
        graph = try graph.adding(node: Node(rawValue: "b"), type: nt)
        let et = EdgeType(id: "e", from: nt, to: nt)
        graph = try graph.adding(edgeType: et)
        let edge = Edge(id: Edge.Id(rawValue: "reuseMe"), from: Node(rawValue: "a"), to: Node(rawValue: "b"))
        graph = try graph.adding(edge: edge, edgeType: et)
        graph = try graph.deleting(edge: edge.id)

        // Reusing the id for a Group must now succeed.
        _ = try graph.adding(group: Group(rawValue: "reuseMe"))
    }
}
