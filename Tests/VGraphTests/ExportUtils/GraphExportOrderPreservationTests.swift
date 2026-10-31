import Testing

@testable import VGraph

struct GraphExportOrderPreservationTests {

    @Test func testSortNodesByItemOrder() throws {
        let nt1 = NodeType(rawValue: "TestType")
        let n1 = Node(rawValue: "node1")
        let n2 = Node(rawValue: "node2")
        let n3 = Node(rawValue: "node3")

        var graph = VGraph()
        graph = try graph.add(nodeType: nt1)
        graph = try graph.add(node: n1, type: nt1)
        graph = try graph.add(node: n2, type: nt1)
        graph = try graph.add(node: n3, type: nt1)

        // Nodes should be sorted by their itemOrder (which is auto-assigned in order of addition)
        let sorted = try GraphExportOrderPreservation.sortByItemOrder(graph.nodes, in: graph)

        #expect(sorted.count == 3)
        #expect(sorted[0].id == n1.id)
        #expect(sorted[1].id == n2.id)
        #expect(sorted[2].id == n3.id)
    }

    @Test func testSortEdgesByItemOrder() throws {
        let nt1 = Notations.Ibis.NodeTypes.question
        let nt2 = Notations.Ibis.NodeTypes.answer
        let et1 = Notations.Ibis.EdgeTypes.questionToAnswer
        let n1 = Node(rawValue: "node1")
        let n2 = Node(rawValue: "node2")
        let n3 = Node(rawValue: "node3")

        var graph = VGraph()
        graph = try graph.add(nodeType: nt1)
        graph = try graph.add(nodeType: nt2)
        graph = try graph.add(edgeType: et1)
        graph = try graph.add(node: n1, type: nt1)
        graph = try graph.add(node: n2, type: nt2)
        graph = try graph.add(node: n3, type: nt1)
        let e1 = Edge(id: "e1", from: n1, to: n2)
        let e2 = Edge(id: "e2", from: n3, to: n2)
        graph = try graph.add(edge: e1, edgeType: et1)
        graph = try graph.add(edge: e2, edgeType: et1)

        // Edges should be sorted by their itemOrder
        let sorted = try GraphExportOrderPreservation.sortByItemOrder(graph.edges, in: graph)

        #expect(sorted.count == 2)
        #expect(sorted[0].from.id == n1.id)
        #expect(sorted[0].to.id == n2.id)
        #expect(sorted[1].from.id == n3.id)
        #expect(sorted[1].to.id == n2.id)
    }

    @Test func testSortGroupsByItemOrder() throws {
        let nt1 = NodeType(rawValue: "TestType")
        let g1 = Group(rawValue: "group1")
        let g2 = Group(rawValue: "group2")
        let n1 = Node(rawValue: "node1")
        let n2 = Node(rawValue: "node2")

        var graph = VGraph()
        graph = try graph.add(nodeType: nt1)
        graph = try graph.add(group: g1)
        graph = try graph.add(group: g2)
        graph = try graph.add(node: n1, type: nt1, group: g1)
        graph = try graph.add(node: n2, type: nt1, group: g2)

        // Get all groups including root
        let allGroups = graph.groups

        // Filter out the internal root group
        let nonRootGroups = allGroups.filter { $0.id.description != rootGroup }

        // Sort the filtered groups
        let sorted = try GraphExportOrderPreservation.sortByItemOrder(nonRootGroups, in: graph)

        #expect(sorted.count == 2)
        #expect(sorted[0].id == g1.id)
        #expect(sorted[1].id == g2.id)
    }

    private func twoAnsweredQuestions() throws -> VGraph {
        let question = Notations.Ibis.NodeTypes.question
        let answer = Notations.Ibis.NodeTypes.answer
        return try VGraph().defineStandardAttributes()
            .add(nodeType: question).add(nodeType: answer)
            .add(edgeType: Notations.Ibis.EdgeTypes.questionToAnswer)
            .add(node: Node("q1"), type: question).add(node: Node("a1"), type: answer)
            .add(node: Node("q2"), type: question).add(node: Node("a2"), type: answer)
            .add(edge: Edge(id: "e1", from: Node("q1"), to: Node("a1")), edgeType: Notations.Ibis.EdgeTypes.questionToAnswer)
            .add(edge: Edge(id: "e2", from: Node("q2"), to: Node("a2")), edgeType: Notations.Ibis.EdgeTypes.questionToAnswer)
    }

    /// A reattached edge is deleted and added again; it keeps its place.
    @Test func aReattachedEdgeKeepsItsPlace() throws {
        let moved = try twoAnsweredQuestions()
            .reattach(edge: Edge.Id("e1"), to: Node("a2"), edgeType: Notations.Ibis.EdgeTypes.questionToAnswer)
        let sorted = try GraphExportOrderPreservation.sortByItemOrder(moved.edges, in: moved)
        #expect(sorted.map { $0.id.description } == ["e1", "e2"])
    }

    /// Splitting puts the first segment where the old edge was and the second
    /// after everything already declared.
    @Test func aSplitEdgesFirstSegmentTakesItsPlace() throws {
        let (split, _) = try twoAnsweredQuestions()
            .splitting(Edge.Id("e1"), into: Notations.Ibis.NodeTypes.answer, incoming: nil, outgoing: nil)
        let sorted = try GraphExportOrderPreservation.sortByItemOrder(split.edges, in: split)
        #expect(sorted.map { $0.from.description } == ["q1", "q2", sorted[2].from.description])
        #expect(sorted[1].id.description == "e2")
        #expect(sorted[2].to.description == "a1")
    }
}
