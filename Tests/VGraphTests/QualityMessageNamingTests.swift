import Testing

@testable import VGraph

/// A quality message names a node by its label, or by its id where it has none:
/// one rule, whichever check reports.
@Suite("Quality messages name unlabelled nodes by id")
struct QualityMessageNamingTests {

    private func ibisGraph(unlabeledQuestion id: String) throws(VError) -> VGraph {
        let graph = try Notations.Ibis.addNotation(to: VGraph())
            .using(notation: "IBIS")
        return try graph.adding(node: Node(rawValue: id), type: Notations.Ibis.NodeTypes.question)
    }

    @Test func aDisconnectedNodeIsNamedByItsId() throws {
        let graph = try ibisGraph(unlabeledQuestion: "q7")
        let messages = GenericQualityChecks.disconnectedNodes(graph: graph)
        #expect(messages.map { $0.message } == ["Node \"q7\" has no relationships — every node should collaborate with at least one other"])
    }

    @Test func anUnansweredQuestionIsNamedByItsId() throws {
        let graph = try ibisGraph(unlabeledQuestion: "q7")
        let messages = Notations.Ibis.unansweredQuestions(graph)
        #expect(messages.first?.message.hasPrefix("Question \"q7\" has no Answer") == true)
    }
}
