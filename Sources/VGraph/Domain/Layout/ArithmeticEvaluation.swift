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

        var outcomes: [Node: Outcome] = [:]
        guard let equalsNodes = graph.typedGraph.nodeTypeMapping.getMany(one: Notations.Arithmetic.NodeTypes.equals)
        else { return outcomes }

        for equalsNode in equalsNodes {
            // No edge-type check: every edge type ending at an Equals is a result edge.
            let computed = topology.incomingEdges(of: equalsNode).compactMap { operatorValues[$0.from] }
            let expected = literalValue(of: equalsNode, in: graph)

            let allValues = computed + (expected.map { [$0] } ?? [])
            guard allValues.count >= 2 else { continue }

            let reference = allValues[0]
            let allAgree = allValues.dropFirst().allSatisfy { abs($0 - reference) < epsilon }
            outcomes[equalsNode] = allAgree ? .correct(value: reference) : .incorrect(computed: computed, expected: expected)
        }
        return outcomes
    }

    private static func computeOperatorValues(in graph: VGraph, topology: GraphTopology) -> [Node: Double] {
        var values: [Node: Double] = [:]
        for spec in Notations.Arithmetic.operatorSpecs {
            guard let nodes = graph.typedGraph.nodeTypeMapping.getMany(one: spec.type) else { continue }
            for node in nodes {
                guard let first = operandValue(of: node, edgeType: spec.first, in: graph, topology: topology),
                    let second = operandValue(of: node, edgeType: spec.second, in: graph, topology: topology),
                    let value = spec.compute(first, second)
                else { continue }
                values[node] = value
            }
        }
        return values
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
        // `Double("")` is 0 in Swift 6.4, and an empty label is no number at all.
        guard let label: String = try? graph.get(node: node, attribute: Attributes.Node.label), !label.isEmpty
        else { return nil }
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
        case .incorrect(_, _):
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
            var result = graph
            let outcomes = evaluate(graph)
            guard let equalsNodes = graph.typedGraph.nodeTypeMapping.getMany(one: Notations.Arithmetic.NodeTypes.equals)
            else { return result }

            for node in equalsNodes {
                if let outcome = outcomes[node] {
                    result = try result.set(node: node, attribute: Attributes.Node.style.attribute(equalsStyle(for: outcome)))
                } else if let expected = literalValue(of: node, in: graph) {
                    let style = Notations.Arithmetic.circleNodeStyle(
                        fill: Notations.Arithmetic.equalsNeutralFill,
                        border: Notations.Arithmetic.equalsNeutralBorder,
                        content: .text("= \(formatValue(expected))"))
                    result = try result.set(node: node, attribute: Attributes.Node.style.attribute(style))
                }
            }
            return result
        }
    }

    // MARK: - Quality check

    public static func notEvaluableCheck(graph: VGraph) -> [MessageWithSeverity] {
        let topology = GraphTopology(edges: graph.edges)
        var messages: [MessageWithSeverity] = []
        guard let divideNodes = graph.typedGraph.nodeTypeMapping.getMany(one: Notations.Arithmetic.NodeTypes.divide)
        else { return messages }

        for node in divideNodes {
            // The dividend's value is irrelevant here, but it must be present: an
            // operator missing an operand is mid-puzzle, not a division by zero.
            guard
                operandValue(
                    of: node, edgeType: Notations.Arithmetic.EdgeTypes.divideFirstOperand, in: graph,
                    topology: topology) != nil,
                let second = operandValue(
                    of: node, edgeType: Notations.Arithmetic.EdgeTypes.divideSecondOperand, in: graph,
                    topology: topology)
            else { continue }
            if abs(second) < epsilon {
                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                messages.append(
                    MessageWithSeverity(
                        message: "Division by zero: \"\(label)\" cannot be evaluated",
                        severity: .warning,
                        target: .node(node.description)
                    ))
            }
        }
        return messages
    }
}
