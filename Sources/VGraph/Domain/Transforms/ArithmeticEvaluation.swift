extension TransformStep.Id {
    public static var arithmeticEvaluate: Self { "arithmeticEvaluate" }
}

/// Deliberately local rather than recursive, which is safe only because no edge type
/// leads back out of an operator's result or out of an `Equals`: no operand can
/// depend on a computed value, so no cycle is constructible and none is checked for.
/// Adding chaining breaks that and needs a recursive walk with a `visited` guard —
/// the "not evaluable" safety net.
public enum ArithmeticEvaluation {

    /// Needed even for `Plus`, where `0.1 + 0.2 != 0.3` would mark a correct answer wrong.
    public static let epsilon: Double = 1e-9

    /// `computed` and `expected` stay separate so a wrong answer can be displayed in a
    /// fixed order rather than an arbitrary one: `expected` is the `Equals` node's own
    /// label, never just another equally-weighted incoming value. It is `nil` when two
    /// operators assert equality with no label between them (`7 − 4 = 2 + 1`).
    public enum Outcome: Equatable {
        case correct(value: Double)
        case incorrect(computed: [Double], expected: Double?)
    }

    public static func evaluate(_ graph: VGraph) -> [Node: Outcome] {
        let topology = GraphTopology(edges: graph.edges)
        let operatorValues = computeOperatorValues(in: graph, topology: topology)

        let judged = graph.nodes(ofType: Notations.Arithmetic.NodeTypes.equals).compactMap { equalsNode in
            outcome(of: equalsNode).map { (equalsNode, $0) }
        }
        return Dictionary(judged, uniquingKeysWith: { first, _ in first })

        func outcome(of equalsNode: Node) -> Outcome? {
            // No edge-type check: every edge type ending at an Equals is a result edge.
            let computed = topology.incomingEdges(of: equalsNode).compactMap { operatorValues[$0.from] }
            let expected = literalValue(of: equalsNode, in: graph)
            let allValues = computed + (expected.map { [$0] } ?? [])
            guard let reference = allValues.first, allValues.count >= 2 else { return nil }
            let allAgree = allValues.dropFirst().allSatisfy { abs($0 - reference) < epsilon }
            return allAgree ? .correct(value: reference) : .incorrect(computed: computed, expected: expected)
        }
    }

    private static func computeOperatorValues(in graph: VGraph, topology: GraphTopology) -> [Node: Double] {
        let computed = Notations.Arithmetic.operatorSpecs.flatMap { spec in
            graph.nodes(ofType: spec.type).compactMap { node -> (Node, Double)? in
                guard let first = operandValue(of: node, edgeType: spec.first, in: graph, topology: topology),
                    let second = operandValue(of: node, edgeType: spec.second, in: graph, topology: topology),
                    let value = spec.compute(first, second)
                else { return nil }
                return (node, value)
            }
        }
        return Dictionary(computed, uniquingKeysWith: { _, last in last })
    }

    private static func operandValue(
        of operatorNode: Node, edgeType: EdgeType, in graph: VGraph, topology: GraphTopology
    ) -> Double? {
        guard
            let edge = topology.incomingEdges(of: operatorNode).first(where: {
                (try? graph.edgeType(for: $0.id).id) == edgeType.id
            })
        else { return nil }
        return literalValue(of: edge.from, in: graph)
    }

    private static func literalValue(of node: Node, in graph: VGraph) -> Double? {
        guard let label: String = try? graph.get(node: node, attribute: Attributes.Node.label) else { return nil }
        return Double(label)
    }

    // MARK: - Painting

    static func equalsStyle(for outcome: Outcome) -> NodeStyleLayout {
        switch outcome {
        case .correct(let value):
            return Notations.Arithmetic.circleNodeStyle(
                fill: Notations.Arithmetic.equalsCorrectFill,
                border: Notations.Arithmetic.equalsCorrectBorder,
                content: .text("= \(formatValue(value))"))
        case .incorrect:
            return Notations.Arithmetic.circleNodeStyle(
                fill: Notations.Arithmetic.equalsIncorrectFill,
                border: Notations.Arithmetic.equalsIncorrectBorder,
                content: .icon("not-equal"))
        }
    }

    static func formatValue(_ value: Double) -> String {
        let nearestInt = value.rounded()
        if abs(value - nearestInt) < epsilon {
            return String(Int(nearestInt))
        }
        return String((value * 100).rounded() / 100)
    }

    /// Runs on the display pipeline's derived graph, never the OriginGraph, so none of
    /// this reaches the VGL file.
    ///
    /// Sets `style` rather than `color` because the layouts bake their own fill and
    /// border colours in, and a `color` override would never reach the rendered fill.
    public static var paintEqualsStep: TransformStep {
        TransformStep(.arithmeticEvaluate) { (graph: VGraph) throws(VError) in
            let outcomes = evaluate(graph)
            return try graph.nodes(ofType: Notations.Arithmetic.NodeTypes.equals).folding(graph) {
                (result, node) throws(VError) in
                guard let style = paint(node) else { return result }
                return try result.setting(node: node, attribute: Attributes.Node.style.attribute(style))
            }

            /// A judged Equals shows its verdict; an unjudged one with a value shows that value.
            func paint(_ node: Node) -> NodeStyleLayout? {
                if let outcome = outcomes[node] { return equalsStyle(for: outcome) }
                return literalValue(of: node, in: graph).map { expected in
                    Notations.Arithmetic.circleNodeStyle(
                        fill: Notations.Arithmetic.equalsNeutralFill,
                        border: Notations.Arithmetic.equalsNeutralBorder,
                        content: .text("= \(formatValue(expected))"))
                }
            }
        }
    }

    // MARK: - Quality check

    public static func notEvaluableCheck(graph: VGraph) -> [MessageWithSeverity] {
        let topology = GraphTopology(edges: graph.edges)
        return graph.nodes(ofType: Notations.Arithmetic.NodeTypes.divide).filter(dividesByZero).map { node in
            MessageWithSeverity(
                message: "Division by zero: \"\(graph.name(of: node))\" cannot be evaluated",
                severity: .warning,
                target: .node(node.description)
            )
        }

        /// The dividend's value is irrelevant here, but it must be present: an
        /// operator missing an operand is mid-puzzle, not a division by zero.
        func dividesByZero(_ divide: Node) -> Bool {
            guard
                operandValue(
                    of: divide, edgeType: Notations.Arithmetic.EdgeTypes.divideFirstOperand, in: graph, topology: topology)
                    != nil,
                let divisor = operandValue(
                    of: divide, edgeType: Notations.Arithmetic.EdgeTypes.divideSecondOperand, in: graph, topology: topology)
            else { return false }
            return abs(divisor) < epsilon
        }
    }
}
