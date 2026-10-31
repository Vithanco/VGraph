extension Notations {

    /// Prerequisite Tree (PRT) is a planning tool from Theory of Constraints.
    /// It uses "necessary condition thinking" to answer "HOW to cause the change?"
    /// by identifying obstacles that prevent achieving objectives and the intermediate
    /// objectives needed to overcome them.
    /// PRTs embody the principle to "Start with the End in Mind" - beginning with the
    /// desired objective and working backward to identify what must be accomplished first.
    public struct PrerequisiteTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "PRT")
        public static let description =
            "Identifies the obstacles that stand between the current reality and a desired objective, and defines the Intermediate Objectives needed to overcome each one."
        public static var diagramLogic: DiagramLogic { .necessaryCondition }

        // MARK: - Self-description

        public static let purpose: String = """
            The Prerequisite Tree begins with a desired Objective and asks: what stands in the \
            way? For each Obstacle you can identify, the tree requires you to define an \
            Intermediate Objective that overcomes it. The result is a network of milestones — \
            each grounded in a real obstacle — that provides a logical roadmap from the current \
            state to the desired goal. The PRT embodies "start with the end in mind" and answers \
            the TOC planning question: "How to cause the change?"
            """

        public static let whenToUse: [String] = [
            "Planning a large change initiative: identifying all significant obstacles before starting, so the path is realistic.",
            "Stakeholder buy-in: making the obstacle-and-milestone structure visible so everyone agrees on the roadmap.",
            "After the Future Reality Tree: translating desired effects into a milestone plan.",
            "Whenever necessary-condition thinking is needed: 'in order to achieve X, we must first achieve Y'.",
            "Identifying which obstacles are blocking multiple objectives simultaneously (high-leverage milestones).",
        ]

        public static let history: String = """
            The Prerequisite Tree is one of the five TOC Thinking Process tools developed by \
            Eliyahu Goldratt in the late 1980s and early 1990s. It uses Necessary Condition logic, \
            complementing the Sufficient Cause logic of the CRT and FRT. H. William Dettmer \
            describes the PRT in detail in "The Logical Thinking Process" (2007) and positions it \
            as the bridge between strategic planning (FRT) and tactical implementation (TRT).
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "The Logical Thinking Process — H. William Dettmer",
                url: "https://www.goodreads.com/book/show/839658.The_Logical_Thinking_Process"
            ),
            NotationReference(
                title: "Theory of Constraints (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Theory_of_constraints"
            ),
        ]

        // Color palette — Vithanco Diagram Style Guide §08
        public static let objFill = SemanticColor(id: "prt.objective.fill", lightHex: "#d8fce8")
        public static let objBorder = SemanticColor(id: "prt.objective.border", lightHex: "#18a858")
        public static let objText = SemanticColor(id: "prt.objective.text", lightHex: "#085828")
        public static let ioFill = SemanticColor(id: "prt.io.fill", lightHex: "#e0e0f8")
        public static let ioBorder = SemanticColor(id: "prt.io.border", lightHex: "#4848c8")
        public static let ioText = SemanticColor(id: "prt.io.text", lightHex: "#181878")
        public static let obsFill = SemanticColor(id: "prt.obstacle.fill", lightHex: "#f8e4e4")
        public static let obsBorder = SemanticColor(id: "prt.obstacle.border", lightHex: "#b84848")
        public static let obsText = SemanticColor(id: "prt.obstacle.text", lightHex: "#681818")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [
                    Self.objective,
                    Self.obstacle,
                    Self.intermediateObjective,
                    Self.orJunctor,
                ]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        objective,
                        description:
                            "The goal to be achieved — the top of the tree. Stated as a specific condition that will exist when the change is complete."
                    ),
                    NodeTypeDefinition(
                        obstacle,
                        description:
                            "A condition currently in the way of achieving an Objective or Intermediate Objective. Each obstacle must be named and overcome."
                    ),
                    NodeTypeDefinition(
                        intermediateObjective,
                        description:
                            "A condition that, when achieved, directly overcomes an Obstacle. IOs cascade downward to break the path clear to the main Objective."
                    ),
                    NodeTypeDefinition(
                        orJunctor,
                        description:
                            "Disjunctive necessary condition — any one of the connected alternatives is sufficient to satisfy the upstream requirement."
                    ),
                ]
            }

            private static let objectiveId = "Objective"
            private static let obstacleId = "Obstacle"
            private static let intermediateObjectiveId = "IntermediateObjective"
            private static let orJunctorId = "OR"

            public static let objective: NodeType = NodeType(string: objectiveId)
            public static let obstacle: NodeType = NodeType(string: obstacleId)
            public static let intermediateObjective: NodeType = NodeType(string: intermediateObjectiveId)
            public static let orJunctor: NodeType = NodeType(string: orJunctorId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.obstacleBlocksObjective,
                    Self.obstacleBlocksIntermediateObjective,
                    Self.intermediateObjectiveOvercomesObstacle,
                    Self.intermediateObjectiveToObjective,
                    Self.obstacleToOr,
                    Self.intermediateObjectiveToOr,
                    Self.orToObjective,
                    Self.orToIntermediateObjective,
                    Self.orToObstacle,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        obstacleBlocksObjective,
                        description:
                            "This Obstacle currently prevents the Objective from being achieved. Read: 'The Obstacle stands in the way of the Objective.'"
                    ),
                    EdgeTypeDefinition(
                        obstacleBlocksIntermediateObjective,
                        description: "This Obstacle currently prevents the Intermediate Objective from being achieved."),
                    EdgeTypeDefinition(
                        intermediateObjectiveOvercomesObstacle,
                        description: "Necessary condition — in order to overcome the Obstacle, this Intermediate Objective must be achieved first."),
                    EdgeTypeDefinition(
                        intermediateObjectiveToObjective,
                        description: "Necessary condition — this Intermediate Objective is a prerequisite for achieving the Objective directly."),
                    EdgeTypeDefinition(
                        obstacleToOr,
                        description: "An Obstacle feeds into an OR junctor — any one of the alternatives is sufficient to overcome it."),
                    EdgeTypeDefinition(
                        intermediateObjectiveToOr,
                        description: "An Intermediate Objective feeds into an OR junctor as one of the alternative paths."),
                    EdgeTypeDefinition(
                        orToObjective,
                        description: "An OR junctor — when any input is achieved — satisfies the Objective."),
                    EdgeTypeDefinition(
                        orToIntermediateObjective,
                        description: "An OR junctor — when any input is achieved — satisfies an Intermediate Objective."),
                    EdgeTypeDefinition(
                        orToObstacle,
                        description: "An OR junctor represents alternative obstacles, any one of which blocks the target."),
                ]
            }

            public static let obstacleBlocksObjective: EdgeType = EdgeType(
                id: "obstacle_blocks_objective",
                from: Notations.PrerequisiteTree.NodeTypes.obstacle,
                to: Notations.PrerequisiteTree.NodeTypes.objective)

            public static let obstacleBlocksIntermediateObjective: EdgeType = EdgeType(
                id: "obstacle_blocks_intermediate_objective",
                from: Notations.PrerequisiteTree.NodeTypes.obstacle,
                to: Notations.PrerequisiteTree.NodeTypes.intermediateObjective)

            public static let intermediateObjectiveOvercomesObstacle: EdgeType = EdgeType(
                id: "intermediate_objective_overcomes_obstacle",
                from: Notations.PrerequisiteTree.NodeTypes.intermediateObjective,
                to: Notations.PrerequisiteTree.NodeTypes.obstacle)

            public static let intermediateObjectiveToObjective: EdgeType = EdgeType(
                id: "intermediate_objective_to_objective",
                from: Notations.PrerequisiteTree.NodeTypes.intermediateObjective,
                to: Notations.PrerequisiteTree.NodeTypes.objective)

            public static let obstacleToOr: EdgeType = EdgeType(
                id: "obstacle_to_or",
                from: Notations.PrerequisiteTree.NodeTypes.obstacle,
                to: Notations.PrerequisiteTree.NodeTypes.orJunctor)

            public static let intermediateObjectiveToOr: EdgeType = EdgeType(
                id: "intermediate_objective_to_or",
                from: Notations.PrerequisiteTree.NodeTypes.intermediateObjective,
                to: Notations.PrerequisiteTree.NodeTypes.orJunctor)

            public static let orToObjective: EdgeType = EdgeType(
                id: "or_to_objective",
                from: Notations.PrerequisiteTree.NodeTypes.orJunctor,
                to: Notations.PrerequisiteTree.NodeTypes.objective)

            public static let orToIntermediateObjective: EdgeType = EdgeType(
                id: "or_to_intermediate_objective",
                from: Notations.PrerequisiteTree.NodeTypes.orJunctor,
                to: Notations.PrerequisiteTree.NodeTypes.intermediateObjective)

            public static let orToObstacle: EdgeType = EdgeType(
                id: "or_to_obstacle",
                from: Notations.PrerequisiteTree.NodeTypes.orJunctor,
                to: Notations.PrerequisiteTree.NodeTypes.obstacle)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.objective, "Objective", icon: "objective", fill: objFill, border: objBorder, text: objText),
                .badge(NodeTypes.obstacle, "Obstacle", icon: "obstacle", fill: obsFill, border: obsBorder, text: obsText),
                .badge(NodeTypes.intermediateObjective, "IO", icon: "intermediate-objective", fill: ioFill, border: ioBorder, text: ioText),
                .junctor(NodeTypes.orJunctor, "or"),
                // Bottom-to-top layout: obstacles at bottom, objectives flow upward
                .diagram([Attributes.Group.layoutDirection(.bottomToTop)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
