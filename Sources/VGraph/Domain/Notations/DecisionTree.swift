extension Notations {

    public struct DecisionTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "DecisionTree")
        public static let description =
            "Models a decision process as a tree of questions, choices, and outcomes — executable to interactively guide users through a decision."

        // MARK: - Self-description

        public static let purpose: String = """
            Decision Trees store the questions and branching choices needed to reach a decision. \
            Unlike a written policy document, a Decision Tree makes every branch and outcome \
            explicit and navigable: each Decision Point poses a question, each Choice selects a \
            path, and each Outcome records a conclusion. The tree can be executed interactively, \
            guiding a user through the questions step by step until an outcome is reached.
            """

        public static let whenToUse: [String] = [
            "Documenting the decision logic of a business process so it can be reviewed, challenged, and executed consistently.",
            "Creating interactive step-by-step decision guides for support staff, onboarding flows, or diagnostic procedures.",
            "Clarifying branching logic before implementing it in code — the diagram exposes every case that the code must handle.",
            "Training materials: learners navigate the tree themselves and discover the correct outcome through the questions.",
        ]

        public static let history: String = """
            Decision trees have been used in operations research and statistics since the 1960s. \
            In machine learning they were formalised by the CART algorithm (Breiman et al., 1984). \
            As a business process and knowledge-capture tool, decision trees predate computers: \
            flowcharts for decision-making appeared in engineering and management literature from \
            the 1940s onward. The Vithanco notation adds interactive execution, letting the tree \
            function as a decision-support tool rather than just a static diagram.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Decision tree (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Decision_tree"
            )
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let dpFill = SemanticColor(id: "decisiontree.decisionPoint.fill", lightHex: "#fff8e8")
        public static let dpBorder = SemanticColor(id: "decisiontree.decisionPoint.border", lightHex: "#d08020")
        public static let dpText = SemanticColor(id: "decisiontree.decisionPoint.text", lightHex: "#6a3c08")
        public static let chFill = SemanticColor(id: "decisiontree.choice.fill", lightHex: "#e8eeff")
        public static let chBorder = SemanticColor(id: "decisiontree.choice.border", lightHex: "#2858d0")
        public static let chText = SemanticColor(id: "decisiontree.choice.text", lightHex: "#0a2878")
        public static let outFill = SemanticColor(id: "decisiontree.outcome.fill", lightHex: "#ebfdf2")
        public static let outBorder = SemanticColor(id: "decisiontree.outcome.border", lightHex: "#209858")
        public static let outText = SemanticColor(id: "decisiontree.outcome.text", lightHex: "#0a5028")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.decisionPoint, Self.choice, Self.outcome]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        decisionPoint,
                        description: "A question describing a decision point. Each question branches into two or more choices."),
                    NodeTypeDefinition(
                        choice,
                        description: "A potential path from a Decision Point. Leads either to another Decision Point or to a final Outcome."),
                    NodeTypeDefinition(
                        outcome,
                        description: "A terminal result of the decision process. No further branching occurs."),
                ]
            }

            private static let decisionPointId = "DecisionPoint"
            private static let choiceId = "Choice"
            private static let outcomeId = "Outcome"

            public static let decisionPoint: NodeType = NodeType(string: decisionPointId)
            public static let choice: NodeType = NodeType(string: choiceId)
            public static let outcome: NodeType = NodeType(string: outcomeId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.decisionToChoice,
                    Self.choiceToDecision,
                    Self.choiceToOutcome,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        decisionToChoice,
                        description: "A Decision Point branches into a Choice."),
                    EdgeTypeDefinition(
                        choiceToDecision,
                        description: "A Choice leads to a further Decision Point (nested question)."),
                    EdgeTypeDefinition(
                        choiceToOutcome,
                        description: "A Choice leads to a final Outcome (terminal result)."),
                ]
            }

            public static let decisionToChoice: EdgeType = EdgeType(
                id: "decision_to_choice",
                from: Notations.DecisionTree.NodeTypes.decisionPoint,
                to: Notations.DecisionTree.NodeTypes.choice)

            public static let choiceToDecision: EdgeType = EdgeType(
                id: "choice_to_decision",
                from: Notations.DecisionTree.NodeTypes.choice,
                to: Notations.DecisionTree.NodeTypes.decisionPoint)

            public static let choiceToOutcome: EdgeType = EdgeType(
                id: "choice_to_outcome",
                from: Notations.DecisionTree.NodeTypes.choice,
                to: Notations.DecisionTree.NodeTypes.outcome)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.decisionPoint, "Decision", icon: "decision-point", fill: dpFill, border: dpBorder, text: dpText),
                .badge(NodeTypes.choice, "Choice", icon: "choice", fill: chFill, border: chBorder, text: chText),
                .badge(NodeTypes.outcome, "Outcome", icon: "outcome", fill: outFill, border: outBorder, text: outText),
                // Top-to-bottom layout: questions at the top, outcomes at the bottom
                .diagram([Attributes.Group.layoutDirection(.topToBottom)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
