import TestSupport
import Testing

@testable import App
@testable import VGraph

@Suite("GraphStructureTraverser Tests")
struct GraphStructureTraverserTests {

    // MARK: - Basic Traversal Tests

    @Test
    func traverseGraphWithOnlyNodes() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, _ in visited.append("enterGroup:\(group.id)") },
            onExitGroup: { group, _, _ in visited.append("exitGroup:\(group.id)") },
            onNode: { node, _, _ in visited.append("node:\(node.id)") },
            onEdge: { edge, _ in visited.append("edge:\(edge.from.id)->\(edge.to.id)") }
        )

        try traverser.traverse(graph)

        #expect(visited.contains("node:n1"), "Should visit node n1")
        #expect(visited.contains("node:n2"), "Should visit node n2")
        #expect(visited.filter { $0.starts(with: "enterGroup") }.isEmpty, "Should not visit any groups")
    }

    @Test
    func traverseGraphWithNodesAndEdges() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
                edge n1 -> n2;
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, _ in visited.append("enterGroup:\(group.id)") },
            onExitGroup: { group, _, _ in visited.append("exitGroup:\(group.id)") },
            onNode: { node, _, _ in visited.append("node:\(node.id)") },
            onEdge: { edge, _ in visited.append("edge:\(edge.from.id)->\(edge.to.id)") }
        )

        try traverser.traverse(graph)

        #expect(visited.contains("node:n1"), "Should visit node n1")
        #expect(visited.contains("node:n2"), "Should visit node n2")
        #expect(visited.contains("edge:n1->n2"), "Should visit the edge")

        let nodeIndex = visited.firstIndex(of: "node:n1")!
        let edgeIndex = visited.firstIndex(of: "edge:n1->n2")!
        #expect(edgeIndex > nodeIndex, "Edges should be visited after nodes")
    }

    // MARK: - Group Traversal Tests

    @Test
    func traverseSingleGroup() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, depth in visited.append("enterGroup:\(group.id)@\(depth)") },
            onExitGroup: { group, _, depth in visited.append("exitGroup:\(group.id)@\(depth)") },
            onNode: { node, _, depth in visited.append("node:\(node.id)@\(depth)") },
            onEdge: { edge, _ in visited.append("edge:\(edge.from.id)->\(edge.to.id)") }
        )

        try traverser.traverse(graph)

        #expect(
            visited == [
                "enterGroup:g1@0",
                "node:n1@1",
                "exitGroup:g1@0",
            ], "Should visit group enter, node, then group exit")
    }

    @Test
    func traverseNestedGroups() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                    group g2 "Group 2" {
                        node n2: Answer "Node 2";
                        group g3 "Group 3" {
                            node n3: Question "Node 3";
                        };
                    };
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, depth in visited.append("enterGroup:\(group.id)@\(depth)") },
            onExitGroup: { group, _, depth in visited.append("exitGroup:\(group.id)@\(depth)") },
            onNode: { node, _, depth in visited.append("node:\(node.id)@\(depth)") },
            onEdge: { edge, _ in visited.append("edge") }
        )

        try traverser.traverse(graph)

        // Verify depth-first traversal with correct depths
        // Groups are visited first (sorted by itemOrder), then nodes
        #expect(
            visited == [
                "enterGroup:g1@0",
                "enterGroup:g2@1",
                "enterGroup:g3@2",
                "node:n3@3",
                "exitGroup:g3@2",
                "node:n2@2",
                "exitGroup:g2@1",
                "node:n1@1",
                "exitGroup:g1@0",
            ], "Should traverse depth-first with correct depths")
    }

    @Test
    func traverseSiblingGroups() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
                group g2 "Group 2" {
                    node n2: Answer "Node 2";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, depth in visited.append("enterGroup:\(group.id)@\(depth)") },
            onExitGroup: { group, _, depth in visited.append("exitGroup:\(group.id)@\(depth)") },
            onNode: { node, _, depth in visited.append("node:\(node.id)@\(depth)") },
            onEdge: { edge, _ in visited.append("edge") }
        )

        try traverser.traverse(graph)

        // Both groups should be at depth 0 (root level)
        #expect(visited.contains("enterGroup:g1@0"), "g1 should be at depth 0")
        #expect(visited.contains("enterGroup:g2@0"), "g2 should be at depth 0")
        #expect(visited.contains("node:n1@1"), "n1 should be at depth 1 (inside g1)")
        #expect(visited.contains("node:n2@1"), "n2 should be at depth 1 (inside g2)")
    }

    // MARK: - String Output Tests

    @Test
    func forStringOutputConcatenates() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { group, _, _ in "[\(group.id){" },
            onExitGroup: { _, _, _ in "}]" },
            onNode: { node, _, _ in "(\(node.id))" },
            onEdge: { edge, _ in "<\(edge.from.id)->\(edge.to.id)>" }
        )

        let result = try traverser.traverse(graph)

        #expect(result == "[g1{(n1)}]", "String outputs should be concatenated")
    }

    @Test
    func forStringOutputWithEdges() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
                edge n1 -> n2;
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { group, _, _ in "[\(group.id){" },
            onExitGroup: { _, _, _ in "}]" },
            onNode: { node, _, _ in "(\(node.id))" },
            onEdge: { edge, _ in "<\(edge.from.id)->\(edge.to.id)>" }
        )

        let result = try traverser.traverse(graph)

        #expect(result.contains("(n1)"), "Should contain node n1")
        #expect(result.contains("(n2)"), "Should contain node n2")
        #expect(result.contains("<n1->n2>"), "Should contain edge")
        #expect(result.hasSuffix("<n1->n2>"), "Edge should be at the end")
    }

    // MARK: - Order Preservation Tests

    @Test
    func preservesItemOrder() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
                node n3: Question "Node 3";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visitedNodes: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { _, _, _ in },
            onExitGroup: { _, _, _ in },
            onNode: { node, _, _ in visitedNodes.append(node.id.description) },
            onEdge: { _, _ in }
        )

        try traverser.traverse(graph)

        #expect(visitedNodes == ["n1", "n2", "n3"], "Nodes should be visited in itemOrder")
    }

    // MARK: - Mixed Content Tests

    @Test
    func traverseMixedGroupAndRootContent() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
                node n2: Answer "Node 2";
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var visited: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { group, _, _ in visited.append("enterGroup:\(group.id)") },
            onExitGroup: { group, _, _ in visited.append("exitGroup:\(group.id)") },
            onNode: { node, _, _ in visited.append("node:\(node.id)") },
            onEdge: { _, _ in }
        )

        try traverser.traverse(graph)

        #expect(visited.contains("enterGroup:g1"), "Should visit group")
        #expect(visited.contains("node:n1"), "Should visit grouped node")
        #expect(visited.contains("node:n2"), "Should visit root node")

        // Group content should come before root nodes (groups sorted first by itemOrder)
        let groupEnterIndex = visited.firstIndex(of: "enterGroup:g1")!
        let n1Index = visited.firstIndex(of: "node:n1")!
        let groupExitIndex = visited.firstIndex(of: "exitGroup:g1")!

        #expect(
            n1Index > groupEnterIndex && n1Index < groupExitIndex,
            "Node n1 should be between group enter and exit")
    }

    // MARK: - Complex Graph Test

    @Test
    func traverseComplexGraph() throws(VError) {
        // Build a graph similar to what DotExporter would handle:
        // g1 (parent)
        //   ├── n1 (question)
        //   └── g2 (child)
        //       └── n2 (answer)
        // n3 (root level, question)
        // edge: n1 -> n2

        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                group parent "Parent Group" {
                    node n1: Question "Node 1";
                    group child "Child Group" {
                        node n2: Answer "Node 2";
                    };
                };
                node n3: Question "Node 3";
                edge n1 -> n2;
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { group, _, depth in
                String(repeating: "  ", count: depth) + "subgraph \(group.id) {\n"
            },
            onExitGroup: { _, _, depth in
                String(repeating: "  ", count: depth) + "}\n"
            },
            onNode: { node, _, depth in
                String(repeating: "  ", count: depth) + "\(node.id);\n"
            },
            onEdge: { edge, _ in
                "\(edge.from.id) -> \(edge.to.id);\n"
            }
        )

        let result = try traverser.traverse(graph)

        #expect(result.contains("subgraph parent"), "Should contain parent group")
        #expect(result.contains("subgraph child"), "Should contain child group")
        #expect(result.contains("n1;"), "Should contain n1")
        #expect(result.contains("n2;"), "Should contain n2")
        #expect(result.contains("n3;"), "Should contain n3")
        #expect(result.contains("n1 -> n2;"), "Should contain edge")

        let parentStart = result.range(of: "subgraph parent")!.lowerBound
        let childStart = result.range(of: "subgraph child")!.lowerBound
        #expect(childStart > parentStart, "Child should appear after parent start")
    }

    // MARK: - Edge-only graph test

    @Test
    func traverseGraphWithMultipleEdges() throws(VError) {
        let vgraphInput = """
            vgraph testGraph: IBIS "Test Graph" {
                node q1: Question "Question 1";
                node a1: Answer "Answer 1";
                node a2: Answer "Answer 2";
                edge q1 -> a1;
                edge q1 -> a2;
            }
            """
        let app = VGraphTestApp()
        let graph = try app.parseGraph(vgraphInput)

        var edges: [String] = []
        let traverser = GraphStructureTraverser<Void>.forSideEffects(
            onEnterGroup: { _, _, _ in },
            onExitGroup: { _, _, _ in },
            onNode: { _, _, _ in },
            onEdge: { edge, _ in edges.append("\(edge.from.id)->\(edge.to.id)") }
        )

        try traverser.traverse(graph)

        #expect(edges.count == 2, "Should visit both edges")
        #expect(edges.contains("q1->a1"), "Should visit first edge")
        #expect(edges.contains("q1->a2"), "Should visit second edge")
    }
}
