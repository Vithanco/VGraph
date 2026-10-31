import TestSupport
import Testing

@testable import VGraph

/// `treeStructure` counts edges, not distinct parents: two links from the same
/// node still make two parents. `noParallelEdges` is the check for that case.
@Suite("treeStructure")
struct TreeStructureCheckTests {

    typealias CLD = Notations.CausalLoopDiagram

    private func graph(_ nodes: [String], _ edges: [(String, String, String)]) throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try CLD.addNotation(addTo: graph)
        for id in nodes {
            let node = Node(string: id)
            graph = try graph.add(node: node, type: CLD.NodeTypes.stock)
            graph = try graph.set(node: node, attribute: Attributes.Node.label.attribute(id.uppercased()))
        }
        for (id, from, to) in edges {
            graph = try graph.add(edge: Edge(string: id, from: from, to: to), edgeType: CLD.EdgeTypes.same)
        }
        return graph
    }

    private func check(_ graph: VGraph) -> [MessageWithSeverity] {
        QualityCheckRegistry.treeStructureCheck(graph)
    }

    @Test("A tree passes")
    func treePasses() throws {
        let tree = try graph(["a", "b", "c"], [("e1", "a", "b"), ("e2", "a", "c")])
        #expect(check(tree).isEmpty)
    }

    @Test("Two parents warn on the child")
    func twoParentsWarn() throws {
        let messages = check(try graph(["a", "b", "c"], [("e1", "a", "c"), ("e2", "b", "c")]))
        #expect(messages.count == 1)
        #expect(messages.first?.severity == .warning)
        #expect(messages.first?.message == "Stock \"C\" has 2 parent nodes (tree structure expects at most 1)")
    }

    @Test("Two edges from one parent count twice")
    func parallelEdgesCountTwice() throws {
        let messages = check(try graph(["a", "b"], [("e1", "a", "b"), ("e2", "a", "b")]))
        #expect(messages.count == 1)
        #expect(messages.first?.message.contains("2 parent nodes") == true)
    }
}
