import Testing
import VGLanguage

@testable import VGraph

@Suite("GraphStructureTraverser Tests")
struct GraphStructureTraverserTests {

    /// One line per visit, so a test compares the whole walk.
    private func walk(_ vgl: String) throws -> [String] {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { group, _, depth in "enterGroup:\(group.id)@\(depth)\n" },
            onExitGroup: { group, _, depth in "exitGroup:\(group.id)@\(depth)\n" },
            onNode: { node, _, depth in "node:\(node.id)@\(depth)\n" },
            onEdge: { edge, _ in "edge:\(edge.from.id)->\(edge.to.id)\n" }
        )
        return try traverser.traverse(graph).split(separator: "\n").map { String($0) }
    }

    @Test
    func traverseSingleGroup() throws {
        let visited = try walk(
            """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
            }
            """)

        #expect(visited == ["enterGroup:g1@0", "node:n1@1", "exitGroup:g1@0"])
    }

    /// Groups before nodes at every level, depth first.
    @Test
    func traverseNestedGroups() throws {
        let visited = try walk(
            """
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
            """)

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
            ])
    }

    @Test
    func traverseSiblingGroups() throws {
        let visited = try walk(
            """
            vgraph testGraph: IBIS "Test Graph" {
                group g1 "Group 1" {
                    node n1: Question "Node 1";
                };
                group g2 "Group 2" {
                    node n2: Answer "Node 2";
                };
            }
            """)

        #expect(
            visited == [
                "enterGroup:g1@0", "node:n1@1", "exitGroup:g1@0",
                "enterGroup:g2@0", "node:n2@1", "exitGroup:g2@0",
            ])
    }

    @Test
    func forStringOutputConcatenates() throws {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(
            source: """
                vgraph testGraph: IBIS "Test Graph" {
                    group g1 "Group 1" {
                        node n1: Question "Node 1";
                    };
                }
                """)

        let traverser = GraphStructureTraverser.forStringOutput(
            onEnterGroup: { group, _, _ in "[\(group.id){" },
            onExitGroup: { _, _, _ in "}]" },
            onNode: { node, _, _ in "(\(node.id))" },
            onEdge: { edge, _ in "<\(edge.from.id)->\(edge.to.id)>" }
        )

        #expect(try traverser.traverse(graph) == "[g1{(n1)}]")
    }

    @Test
    func edgesComeAfterEveryNode() throws {
        let visited = try walk(
            """
            vgraph testGraph: IBIS "Test Graph" {
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
                edge n1 -> n2;
            }
            """)

        #expect(visited == ["node:n1@0", "node:n2@0", "edge:n1->n2"])
    }

    /// Declared out of id order, so sorting by id would show.
    @Test
    func preservesDeclarationOrder() throws {
        let visited = try walk(
            """
            vgraph testGraph: IBIS "Test Graph" {
                node n3: Question "Node 3";
                node n1: Question "Node 1";
                node n2: Answer "Node 2";
            }
            """)

        #expect(visited == ["node:n3@0", "node:n1@0", "node:n2@0"])
    }
}
