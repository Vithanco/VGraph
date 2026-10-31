//
//  ArithmeticEvaluationTests.swift
//  VGraph
//
//  Evaluation, bounds, and the non-evaluable quality check for the
//  Arithmetic notation.
//

import TestSupport
import Testing

@testable import VGraph

@Suite("Arithmetic evaluation")
struct ArithmeticEvaluationTests {

    typealias A = Notations.Arithmetic

    // MARK: - Fixtures

    private func blank() throws(VError) -> VGraph {
        var graph = try VGraph().defineStandardAttributes()
        graph = try A.addNotation(addTo: graph)
        return graph.using(notation: "Arithmetic")
    }

    private func number(_ id: String, _ value: String?, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: A.NodeTypes.number)
        if let value {
            result = try result.set(node: node, attribute: Attributes.Node.label.attribute(value))
        }
        return result
    }

    private func operatorNode(_ id: String, _ type: NodeType, in graph: VGraph) throws(VError) -> VGraph {
        try graph.add(node: Node(string: id), type: type)
    }

    private func equalsNode(_ id: String, _ expected: String?, in graph: VGraph) throws(VError) -> VGraph {
        let node = Node(string: id)
        var result = try graph.add(node: node, type: A.NodeTypes.equals)
        if let expected {
            result = try result.set(node: node, attribute: Attributes.Node.label.attribute(expected))
        }
        return result
    }

    private func edge(_ id: String, _ from: String, _ to: String, _ type: EdgeType, in graph: VGraph)
        throws(VError) -> VGraph
    {
        try graph.add(edge: Edge(string: id, from: from, to: to), edgeType: type)
    }

    /// `7 − x = 3`, typed directly onto `Equals`, with `x` filled by `secondValue`:
    /// 7 --first--> Minus --result--> Equals("3"), and `secondValue` --second--> Minus.
    private func minusPuzzle(secondValue: String) throws(VError) -> VGraph {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("candidate", secondValue, in: graph)
        graph = try operatorNode("op", A.NodeTypes.minus, in: graph)
        graph = try equalsNode("eq", "3", in: graph)
        graph = try edge("e1", "seven", "op", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "candidate", "op", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.minusResult, in: graph)
        return graph
    }

    // MARK: - Correct / incorrect / incomplete

    @Test("7 − 4 = 3 evaluates correct")
    func correctAnswerEvaluatesCorrect() throws {
        let graph = try minusPuzzle(secondValue: "4")
        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .correct(value: 3))
    }

    @Test("7 − 5 = 3 evaluates incorrect: computed 2, expected 3")
    func wrongAnswerEvaluatesIncorrect() throws {
        let graph = try minusPuzzle(secondValue: "5")
        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .incorrect(computed: [2], expected: 3))
    }

    @Test("A puzzle missing its second operand is absent from the outcome, not incorrect")
    func incompletePuzzleIsNeitherCorrectNorIncorrect() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try operatorNode("op", A.NodeTypes.minus, in: graph)
        graph = try equalsNode("eq", "3", in: graph)
        graph = try edge("e1", "seven", "op", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.minusResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == nil)
    }

    // MARK: - Both-sides-equal (two operator results into one Equals, no typed label)

    @Test("7 − 4 = 2 + 1 evaluates correct with no typed label on Equals at all")
    func bothSidesEqualWithNoLabel() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try number("one", "1", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "one", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .correct(value: 3))
    }

    @Test("7 − 4 = 2 + 2 evaluates incorrect with no typed label — both computed values carried")
    func bothSidesDisagreeWithNoLabel() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "four", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)

        // minus = 3, plus = 6
        let outcomes = ArithmeticEvaluation.evaluate(graph)
        guard case .incorrect(let computed, let expected) = outcomes[Node(string: "eq")] else {
            Issue.record("Expected .incorrect")
            return
        }
        #expect(Set(computed) == Set([3, 6]))
        #expect(expected == nil)
    }

    /// The painter sorts before it shows anything, but `Outcome` is public and
    /// carries the order as it stands. That is `VGraph.edges` order — grouped by
    /// source node — so Minus, added first, leads though its result edge is last.
    @Test("Computed values follow the operators' node order, not the edges' line order")
    func computedFollowsResultEdgeOrder() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "four", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .incorrect(computed: [3, 6], expected: nil))
    }

    // MARK: - Division

    @Test("6 : 2 = 3 evaluates correct")
    func divisionEvaluatesCorrect() throws {
        var graph = try blank()
        graph = try number("six", "6", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try operatorNode("op", A.NodeTypes.divide, in: graph)
        graph = try equalsNode("eq", "3", in: graph)
        graph = try edge("e1", "six", "op", A.EdgeTypes.divideFirstOperand, in: graph)
        graph = try edge("e2", "two", "op", A.EdgeTypes.divideSecondOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.divideResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .correct(value: 3))
    }

    @Test("7 : 2 = 3.5 evaluates correct — non-integer values compare within epsilon")
    func nonIntegerDivisionEvaluatesCorrect() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try operatorNode("op", A.NodeTypes.divide, in: graph)
        graph = try equalsNode("eq", "3.5", in: graph)
        graph = try edge("e1", "seven", "op", A.EdgeTypes.divideFirstOperand, in: graph)
        graph = try edge("e2", "two", "op", A.EdgeTypes.divideSecondOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.divideResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .correct(value: 3.5))
    }

    @Test("Division by zero reports a warning and produces no outcome")
    func divisionByZeroReportsWarning() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("zero", "0", in: graph)
        graph = try operatorNode("op", A.NodeTypes.divide, in: graph)
        graph = try equalsNode("eq", "3", in: graph)
        graph = try edge("e1", "seven", "op", A.EdgeTypes.divideFirstOperand, in: graph)
        graph = try edge("e2", "zero", "op", A.EdgeTypes.divideSecondOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.divideResult, in: graph)

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == nil)

        let messages = ArithmeticEvaluation.notEvaluableCheck(graph: graph)
        #expect(messages.count == 1)
        #expect(messages[0].severity == .warning)
    }

    // MARK: - Painting (TransformStep)

    @Test("A correct equation paints green and shows the agreed value, e.g. '= 3'")
    func paintStepShowsAgreedValueWhenCorrect() throws {
        let graph = try minusPuzzle(secondValue: "4")
        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)

        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        let expected = Notations.Arithmetic.circleNodeStyle(
            fill: Notations.Arithmetic.equalsCorrectFill, border: Notations.Arithmetic.equalsCorrectBorder, content: .text("= 3"))
        #expect(style.asString == expected.asString)
    }

    @Test("7 − 5 = 3 paints red with the not-equal icon")
    func paintStepShowsComputedThenExpectedWhenIncorrect() throws {
        let graph = try minusPuzzle(secondValue: "5")
        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)

        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(style.extractIcons() == ["not-equal"])
    }

    @Test("A typed-but-not-yet-evaluable Equals paints neutral, showing '= <expected>'")
    func paintStepShowsTypedExpectationBeforeEvaluable() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try operatorNode("op", A.NodeTypes.minus, in: graph)
        graph = try equalsNode("eq", "3", in: graph)
        graph = try edge("e1", "seven", "op", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e3", "op", "eq", A.EdgeTypes.minusResult, in: graph)

        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)
        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        let expected = Notations.Arithmetic.circleNodeStyle(
            fill: Notations.Arithmetic.equalsNeutralFill, border: Notations.Arithmetic.equalsNeutralBorder, content: .text("= 3"))
        #expect(style.asString == expected.asString)

        // Painting must not have mutated the graph passed in.
        let originalStyle: NodeStyleLayout = try graph.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(originalStyle.asString == Notations.Arithmetic.equalsNeutralStyle.asString)
    }

    @Test("A totally untouched Equals stays a bare '=' — nothing typed, nothing connected")
    func paintStepLeavesBlankEqualsUntouched() throws {
        var graph = try blank()
        graph = try equalsNode("eq", nil, in: graph)

        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)
        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(style.asString == Notations.Arithmetic.equalsNeutralStyle.asString)
    }

    @Test("Two disagreeing operator results with no typed label paint the not-equal icon")
    func paintStepShowsSortedPairWhenNoExpected() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "four", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)

        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)
        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(style.extractIcons() == ["not-equal"])
    }

    @Test("Three disagreeing operator results with no typed label paint the not-equal icon")
    func paintStepShowsBareNotEqualForThreeWayDisagreement() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try number("one", "1", in: graph)
        graph = try number("three", "3", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try operatorNode("timesOp", A.NodeTypes.times, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "one", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)
        graph = try edge("e7", "three", "timesOp", A.EdgeTypes.timesFirstOperand, in: graph)
        graph = try edge("e8", "two", "timesOp", A.EdgeTypes.timesSecondOperand, in: graph)
        graph = try edge("e9", "timesOp", "eq", A.EdgeTypes.timesResult, in: graph)

        // minus = 3, plus = 3, times = 6 — not all agree.
        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)
        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(style.extractIcons() == ["not-equal"])
    }

    @Test("Two operators both landing on the same wrong value paint the not-equal icon")
    func paintStepDedupesRepeatedComputedValues() throws {
        var graph = try blank()
        graph = try number("seven", "7", in: graph)
        graph = try number("four", "4", in: graph)
        graph = try number("two", "2", in: graph)
        graph = try number("one", "1", in: graph)
        graph = try operatorNode("minusOp", A.NodeTypes.minus, in: graph)
        graph = try operatorNode("plusOp", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", "9", in: graph)
        graph = try edge("e1", "seven", "minusOp", A.EdgeTypes.minusFirstOperand, in: graph)
        graph = try edge("e2", "four", "minusOp", A.EdgeTypes.minusSecondOperand, in: graph)
        graph = try edge("e3", "minusOp", "eq", A.EdgeTypes.minusResult, in: graph)
        graph = try edge("e4", "two", "plusOp", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e5", "one", "plusOp", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e6", "plusOp", "eq", A.EdgeTypes.plusResult, in: graph)

        // minus = 3, plus = 3, expected = 9 — both computed values are 3.
        let painted = try ArithmeticEvaluation.paintEqualsStep(graph)
        let style: NodeStyleLayout = try painted.get(node: Node(string: "eq"), attribute: Attributes.Node.style)
        #expect(style.extractIcons() == ["not-equal"])
    }

    @Test("formatValue rounds near-integers and trims a non-integer to two decimals")
    func formatValueRoundsSensibly() throws {
        #expect(ArithmeticEvaluation.formatValue(3.0) == "3")
        #expect(ArithmeticEvaluation.formatValue(3.0000000001) == "3")
        #expect(ArithmeticEvaluation.formatValue(3.5) == "3.5")
        #expect(ArithmeticEvaluation.formatValue(10.0 / 3.0) == "3.33")
    }

    // MARK: - Bounds

    @Test("A second edge of the same operand type on one operator is reported by graph analysis")
    func secondOperandOfSameTypeIsFlagged() throws {
        var graph = try blank()
        graph = try number("a", "1", in: graph)
        graph = try number("b", "2", in: graph)
        graph = try operatorNode("op", A.NodeTypes.plus, in: graph)
        graph = try edge("e1", "a", "op", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e2", "b", "op", A.EdgeTypes.plusFirstOperand, in: graph)

        let messages = GenericQualityChecks.brokenBounds(graph: graph)
        #expect(messages.contains { $0.severity == .warning || $0.severity == .error })
    }

    /// Flagged above, yet still evaluated: the operand drawn first is the one used.
    @Test("With two operands of the same type, the first in the document counts")
    func firstOperandOfSameTypeWins() throws {
        var graph = try blank()
        graph = try number("a", "1", in: graph)
        graph = try number("b", "2", in: graph)
        graph = try number("c", "10", in: graph)
        graph = try operatorNode("op", A.NodeTypes.plus, in: graph)
        graph = try equalsNode("eq", nil, in: graph)
        graph = try edge("e1", "a", "op", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e2", "b", "op", A.EdgeTypes.plusFirstOperand, in: graph)
        graph = try edge("e3", "c", "op", A.EdgeTypes.plusSecondOperand, in: graph)
        graph = try edge("e4", "op", "eq", A.EdgeTypes.plusResult, in: graph)
        graph = try graph.set(node: Node(string: "eq"), attribute: Attributes.Node.label.attribute("11"))

        let outcomes = ArithmeticEvaluation.evaluate(graph)
        #expect(outcomes[Node(string: "eq")] == .correct(value: 11))
    }
}
