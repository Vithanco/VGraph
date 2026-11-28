extension Notations {

    /// Rejected in design: integer-only values, and `=` as an edge rather than a node.
    ///
    /// `=` is a node so that several terms can meet and be asserted equal, which is
    /// how `7 − 4 = 2 + 1` is drawn with no answer node at all.
    public struct Arithmetic: NotationDeclaration {
        public static let id: Identifier<Notation> = .init(rawValue: "Arithmetic")
        public static let description =
            "A basic arithmetic notation — Number, Equals, and the four operators — for building and checking simple equations."

        // MARK: - Self-description

        public static let purpose: String = """
            Arithmetic represents a simple equation as a graph: Number nodes carry values, an \
            operator node (Plus, Minus, Times, Divide) takes two operands and produces a result, \
            and an Equals node asserts that everything connected to it shares the same value. \
            Built for a kids' maths game — the notation is deliberately small, with no chaining \
            of operators and no algebraic variables, just numbers, operators, and equality.
            """

        public static let whenToUse: [String] = [
            "Building a simple equation as a diagram: two operands, one operator, one result.",
            "A puzzle where one connection is missing and a value must be chosen to complete it correctly.",
            "Asserting that two expressions are equal (e.g. 7 − 4 = 2 + 1) without naming which side is 'the answer'.",
        ]

        public static let history: String = """
            Designed for VGraph's own kids' maths game rather than adapted from an external \
            standard. `=` is a node rather than an edge, so that several terms can meet at it \
            and be asserted equal.
            """

        public static let references: [NotationReference] = []

        // Color palette — every operator hue stays clear of green and red, which Equals
        // reserves for correct/incorrect feedback.
        public static let numberFill = SemanticColor(id: "arithmetic.number.fill", lightHex: "#eef2f7")
        public static let numberBorder = SemanticColor(id: "arithmetic.number.border", lightHex: "#64748b")
        public static let numberText = SemanticColor(id: "arithmetic.number.text", lightHex: "#1e293b")

        public static let plusFill = SemanticColor(id: "arithmetic.plus.fill", lightHex: "#dbeafe")
        public static let plusBorder = SemanticColor(id: "arithmetic.plus.border", lightHex: "#2563eb")

        public static let minusFill = SemanticColor(id: "arithmetic.minus.fill", lightHex: "#ede9fe")
        public static let minusBorder = SemanticColor(id: "arithmetic.minus.border", lightHex: "#7c3aed")

        public static let timesFill = SemanticColor(id: "arithmetic.times.fill", lightHex: "#ccfbf1")
        public static let timesBorder = SemanticColor(id: "arithmetic.times.border", lightHex: "#0d9488")

        public static let divideFill = SemanticColor(id: "arithmetic.divide.fill", lightHex: "#fef3c7")
        public static let divideBorder = SemanticColor(id: "arithmetic.divide.border", lightHex: "#d97706")

        public static let equalsNeutralFill = SemanticColor(id: "arithmetic.equals.neutral.fill", lightHex: "#f1f5f9")
        public static let equalsNeutralBorder = SemanticColor(id: "arithmetic.equals.neutral.border", lightHex: "#64748b")
        public static let equalsCorrectFill = SemanticColor(id: "arithmetic.equals.correct.fill", lightHex: "#dcfce7")
        public static let equalsCorrectBorder = SemanticColor(id: "arithmetic.equals.correct.border", lightHex: "#16a34a")
        public static let equalsIncorrectFill = SemanticColor(id: "arithmetic.equals.incorrect.fill", lightHex: "#fee2e2")
        public static let equalsIncorrectBorder = SemanticColor(id: "arithmetic.equals.incorrect.border", lightHex: "#dc2626")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.number, Self.equals, Self.plus, Self.minus, Self.times, Self.divide]
            }

            public static var operators: [NodeType] {
                return [Self.plus, Self.minus, Self.times, Self.divide]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(number, description: "A value — either given, or filled in as a candidate answer. Its label is its value."),
                    NodeTypeDefinition(
                        equals,
                        description:
                            "Asserts that everything connected to it — plus its own typed value, if any — shares the same value. Green and shows the value when they agree, red and shows what's wrong when they don't, neutral while incomplete."
                    ),
                    NodeTypeDefinition(plus, description: "Addition: takes two operands, produces their sum."),
                    NodeTypeDefinition(minus, description: "Subtraction: takes two operands, produces their difference."),
                    NodeTypeDefinition(times, description: "Multiplication: takes two operands, produces their product."),
                    NodeTypeDefinition(divide, description: "Division: takes two operands, produces their quotient."),
                ]
            }

            private static let numberId = "Number"
            private static let equalsId = "Equals"
            private static let plusId = "Plus"
            private static let minusId = "Minus"
            private static let timesId = "Times"
            private static let divideId = "Divide"

            public static let number: NodeType = NodeType(rawValue: numberId)
            public static let equals: NodeType = NodeType(rawValue: equalsId)
            public static let plus: NodeType = NodeType(rawValue: plusId)
            public static let minus: NodeType = NodeType(rawValue: minusId)
            public static let times: NodeType = NodeType(rawValue: timesId)
            public static let divide: NodeType = NodeType(rawValue: divideId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.plusFirstOperand, Self.plusSecondOperand, Self.plusResult,
                    Self.minusFirstOperand, Self.minusSecondOperand, Self.minusResult,
                    Self.timesFirstOperand, Self.timesSecondOperand, Self.timesResult,
                    Self.divideFirstOperand, Self.divideSecondOperand, Self.divideResult,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(plusFirstOperand, description: "The first number added.", sourceIs: "first operand"),
                    EdgeTypeDefinition(plusSecondOperand, description: "The second number added.", sourceIs: "second operand"),
                    EdgeTypeDefinition(plusResult, description: "The sum, asserted equal at the Equals node.", targetIs: "result"),
                    EdgeTypeDefinition(minusFirstOperand, description: "The number subtracted from.", sourceIs: "first operand"),
                    EdgeTypeDefinition(minusSecondOperand, description: "The number subtracted.", sourceIs: "second operand"),
                    EdgeTypeDefinition(minusResult, description: "The difference, asserted equal at the Equals node.", targetIs: "result"),
                    EdgeTypeDefinition(timesFirstOperand, description: "The first factor.", sourceIs: "first operand"),
                    EdgeTypeDefinition(timesSecondOperand, description: "The second factor.", sourceIs: "second operand"),
                    EdgeTypeDefinition(timesResult, description: "The product, asserted equal at the Equals node.", targetIs: "result"),
                    EdgeTypeDefinition(divideFirstOperand, description: "The dividend.", sourceIs: "first operand"),
                    EdgeTypeDefinition(divideSecondOperand, description: "The divisor.", sourceIs: "second operand"),
                    EdgeTypeDefinition(divideResult, description: "The quotient, asserted equal at the Equals node.", targetIs: "result"),
                ]
            }

            // first/second rather than left/right so a thirdOperand generalises later,
            // for n-ary function nodes (folded groups as functions).
            public static let plusFirstOperand: EdgeType = EdgeType(
                id: "plus_first_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.plus)
            public static let plusSecondOperand: EdgeType = EdgeType(
                id: "plus_second_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.plus)
            public static let plusResult: EdgeType = EdgeType(
                id: "plus_result", from: Notations.Arithmetic.NodeTypes.plus, to: Notations.Arithmetic.NodeTypes.equals)

            public static let minusFirstOperand: EdgeType = EdgeType(
                id: "minus_first_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.minus)
            public static let minusSecondOperand: EdgeType = EdgeType(
                id: "minus_second_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.minus)
            public static let minusResult: EdgeType = EdgeType(
                id: "minus_result", from: Notations.Arithmetic.NodeTypes.minus, to: Notations.Arithmetic.NodeTypes.equals)

            public static let timesFirstOperand: EdgeType = EdgeType(
                id: "times_first_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.times)
            public static let timesSecondOperand: EdgeType = EdgeType(
                id: "times_second_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.times)
            public static let timesResult: EdgeType = EdgeType(
                id: "times_result", from: Notations.Arithmetic.NodeTypes.times, to: Notations.Arithmetic.NodeTypes.equals)

            public static let divideFirstOperand: EdgeType = EdgeType(
                id: "divide_first_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.divide)
            public static let divideSecondOperand: EdgeType = EdgeType(
                id: "divide_second_operand", from: Notations.Arithmetic.NodeTypes.number, to: Notations.Arithmetic.NodeTypes.divide)
            public static let divideResult: EdgeType = EdgeType(
                id: "divide_result", from: Notations.Arithmetic.NodeTypes.divide, to: Notations.Arithmetic.NodeTypes.equals)
        }

        struct OperatorSpec {
            let type: NodeType
            let first: EdgeType
            let second: EdgeType
            let result: EdgeType
            let compute: (Double, Double) -> Double?
        }

        static var operatorSpecs: [OperatorSpec] {
            [
                OperatorSpec(
                    type: NodeTypes.plus, first: EdgeTypes.plusFirstOperand, second: EdgeTypes.plusSecondOperand,
                    result: EdgeTypes.plusResult, compute: { $0 + $1 }),
                OperatorSpec(
                    type: NodeTypes.minus, first: EdgeTypes.minusFirstOperand, second: EdgeTypes.minusSecondOperand,
                    result: EdgeTypes.minusResult, compute: { $0 - $1 }),
                OperatorSpec(
                    type: NodeTypes.times, first: EdgeTypes.timesFirstOperand, second: EdgeTypes.timesSecondOperand,
                    result: EdgeTypes.timesResult, compute: { $0 * $1 }),
                OperatorSpec(
                    type: NodeTypes.divide, first: EdgeTypes.divideFirstOperand, second: EdgeTypes.divideSecondOperand,
                    result: EdgeTypes.divideResult,
                    compute: { a, b in abs(b) < ArithmeticEvaluation.epsilon ? nil : a / b }),
            ]
        }

        // MARK: - Node styling
        //
        // A deliberate departure from `iconAccentStrip`, the house style elsewhere: it
        // frames user-authored prose, and an operator has none. `iconCircle` also
        // leaves `hasUserText` false, so an operator cannot be renamed by double-click.

        static var numberStyle: NodeStyleLayout {
            .contentNode(fill: numberFill, border: numberBorder, textColor: numberText)
        }

        static func circleNodeStyle(fill: SemanticColor, border: SemanticColor, content: CircleContent) -> NodeStyleLayout {
            .iconCircle(fill: fill, border: border, content: content, contentColor: border)
        }

        /// There is deliberately no correct/incorrect counterpart here: those carry the
        /// evaluated value, so they vary per instance and are built in
        /// `ArithmeticEvaluation.equalsStyle(for:)` instead.
        static var equalsNeutralStyle: NodeStyleLayout {
            circleNodeStyle(fill: equalsNeutralFill, border: equalsNeutralBorder, content: .icon("equals"))
        }

        // MARK: - Notation

        public static var step: TransformStep? { ArithmeticEvaluation.paintEqualsStep }
        public static var qualityChecks: [QualityCheck] {
            [
                QualityCheck(
                    "divisionByZero", rule: "A Divide never divides by zero.",
                    findings: ArithmeticEvaluation.notEvaluableCheck)
            ]
        }

        public static var values: [TypeValues] {
            // Without `.presetLayout`, `effectiveNodeLayout(for:)` never reads the
            // `style` attribute back and silently falls back to `.bareText`.
            let preset = NodeTypes.all.map { TypeValues.nodeType($0, [Attributes.Node.nodeStyle(.presetLayout)]) }
            let styles: [TypeValues] = [
                .nodeType(
                    NodeTypes.number,
                    [
                        Attributes.Node.style(numberStyle), Attributes.Node.fontname(.dmSans), Attributes.Node.fontsize(13),
                    ]),
                .nodeType(NodeTypes.equals, [Attributes.Node.style(equalsNeutralStyle)]),
                .nodeType(NodeTypes.plus, [Attributes.Node.style(circleNodeStyle(fill: plusFill, border: plusBorder, content: .icon("plus")))]),
                .nodeType(NodeTypes.minus, [Attributes.Node.style(circleNodeStyle(fill: minusFill, border: minusBorder, content: .icon("minus")))]),
                .nodeType(NodeTypes.times, [Attributes.Node.style(circleNodeStyle(fill: timesFill, border: timesBorder, content: .icon("times")))]),
                .nodeType(
                    NodeTypes.divide, [Attributes.Node.style(circleNodeStyle(fill: divideFill, border: divideBorder, content: .icon("divide")))]),
            ]
            // Each operand edge type already names one operator, so inDegreeMax bounds
            // that operator alone rather than operators collectively. No minimums, and
            // nothing bounding what arrives at an Equals: an incomplete puzzle is the
            // normal mid-play state, and several results meeting at one Equals is the
            // point of the node.
            let bounds = operatorSpecs.flatMap { spec in
                [
                    TypeValues.edgeType(spec.first, [Attributes.Edge.inDegreeMax(1)]),
                    TypeValues.edgeType(spec.second, [Attributes.Edge.inDegreeMax(1)]),
                    // The bound division-with-remainder will have to relax.
                    TypeValues.edgeType(spec.result, [Attributes.Edge.outDegreeMax(1)]),
                ]
            }
            // An equation is one claim, so hovering any part of it shows all of it;
            // a Number, which can sit in several, ends the walk (ADR-0037).
            let equation = NodeTypes.all.filter { $0 != NodeTypes.number }
                .map { TypeValues.nodeType($0, [Attributes.Node.addsToNeighborhood(.all)]) }
            // Left-to-right reads as the equation does, ending on the Equals.
            return preset + styles + bounds + equation + [.diagram([Attributes.Group.layoutDirection(.leftToRight)])]
        }

    }

}

extension Notations.Arithmetic {
    public static var counterexamples: [Counterexample] {
        [
            Counterexample(
                "divisionByZero",
                """
                vgraph sweets: Arithmetic "Sharing sweets" {
                    node sweets: Number "12";
                    node friends: Number "0";
                    node share: Divide;
                    node each: Equals "4";
                    edge sweets -> share: divide_first_operand;
                    edge friends -> share: divide_second_operand;
                    edge share -> each: divide_result;
                }
                """)
        ]
    }
}
