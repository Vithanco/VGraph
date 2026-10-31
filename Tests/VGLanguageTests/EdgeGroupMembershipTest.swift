// An edge belongs to the group that holds both of its ends. That group is
// *derived* from the endpoints, never stored — VGL has no way to say "this edge
// is in group X" independently of where its nodes are, so anything stored could
// not survive an export.

import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("An edge's group is derived from its endpoints")
struct EdgeGroupMembershipTest {

    private func parse(_ source: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: source)
    }

    private func reparse(_ graph: VGraph) throws -> VGraph {
        try parse(try VGLExporter().export(graph: graph))
    }

    private func onlyEdge(in graph: VGraph) throws -> Edge.Id {
        try #require(graph.edges.first).id
    }

    private let root = Group(rawValue: rootGroup)

    // MARK: - The round trip

    /// The document rule: an export fed back is the same graph. The exporter
    /// writes every edge at top level, so a membership that lived anywhere but
    /// in the endpoints could not come back.
    @Test func anEdgeDeclaredInsideAGroupKeepsThatGroupAcrossAReparse() throws {
        let graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                group g1 "Cluster" {
                    node q1: Question "Why?";
                    node a1: Answer "Because";
                    edge q1 -> a1;
                };
            }
            """)
        let g1 = try #require(graph.groups.first { $0.id.description == "g1" })

        #expect(graph.group(of: try onlyEdge(in: graph)) == g1)

        let reparsed = try reparse(graph)
        #expect(reparsed.group(of: try onlyEdge(in: reparsed)) == g1)
    }

    /// Where the edge is *written* carries no membership of its own: the ends
    /// decide. Declaring the same edge outside the group it belongs to changes
    /// nothing.
    @Test func whereTheEdgeIsWrittenDoesNotDecideItsGroup() throws {
        let graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                group g1 "Cluster" {
                    node q1: Question "Why?";
                    node a1: Answer "Because";
                };
                edge q1 -> a1;
            }
            """)
        let g1 = try #require(graph.groups.first { $0.id.description == "g1" })

        #expect(graph.group(of: try onlyEdge(in: graph)) == g1)
    }

    // MARK: - The common ancestor

    /// Ends in sibling subgroups: the edge is drawn inside the group that holds
    /// both, not in either half and not at the top.
    @Test func anEdgeBetweenSiblingSubgroupsBelongsToTheirParent() throws {
        let graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                group outer "Outer" {
                    group left "Left" {
                        node q1: Question "Why?";
                    };
                    group right "Right" {
                        node a1: Answer "Because";
                    };
                };
                edge q1 -> a1;
            }
            """)
        let outer = try #require(graph.groups.first { $0.id.description == "outer" })

        #expect(graph.group(of: try onlyEdge(in: graph)) == outer)
    }

    /// No group holds both ends, so the answer is the root — the same answer
    /// `group(of: node)` gives for a node nobody grouped.
    @Test func anEdgeAcrossUnrelatedGroupsBelongsToTheRoot() throws {
        let graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                group g1 "One" {
                    node q1: Question "Why?";
                };
                group g2 "Two" {
                    node a1: Answer "Because";
                };
                edge q1 -> a1;
            }
            """)

        #expect(graph.group(of: try onlyEdge(in: graph)) == root)
    }

    @Test func anEdgeBetweenUngroupedNodesBelongsToTheRoot() throws {
        let graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                node q1: Question "Why?";
                node a1: Answer "Because";
                edge q1 -> a1;
            }
            """)

        #expect(graph.group(of: try onlyEdge(in: graph)) == root)
    }

    // MARK: - It follows the nodes

    /// The bug a stored membership has and a derived one cannot: move an end out
    /// and the edge is no longer inside the group it was declared in.
    @Test func anEdgeFollowsItsEndsWhenOneLeavesTheGroup() throws {
        var graph = try parse(
            """
            vgraph demo: IBIS "Demo" {
                group g1 "One" {
                    node q1: Question "Why?";
                    node a1: Answer "Because";
                    edge q1 -> a1;
                };
                group g2 "Two" {
                    node a2: Answer "Or because";
                };
            }
            """)
        let g2 = try #require(graph.groups.first { $0.id.description == "g2" })
        let edge = try onlyEdge(in: graph)

        graph = try graph.addTo(group: g2, node: Node(string: "q1"))

        #expect(graph.group(of: edge) == root, "the edge stayed in a group only one end is still in")
    }
}
