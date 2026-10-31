extension Notations {

    public struct ImpactMapping: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "ImpactMapping")
        public static let description =
            "Plans how to achieve a goal by mapping Actors, their potential Impacts, and Deliverables that support them."

        // MARK: - Self-description

        public static let purpose: String = """
            Impact Mapping aligns software delivery to business goals by making the reasoning \
            behind every deliverable explicit. The four-level structure — Why (the Goal), Who \
            (the Actors), How (the Impacts on those actors), and What (the Deliverables) — forces \
            teams to ask whether each feature actually changes actor behaviour in a way that \
            contributes to the goal. Deliverables with no Impact path are candidates for cutting.
            """

        public static let whenToUse: [String] = [
            "Planning a product release or sprint: connecting deliverables to actors and business goals before committing.",
            "Deciding what to cut when scope is constrained: only deliverables with a clear impact path survive.",
            "Stakeholder alignment: making the link between a business goal and an engineering task visible to everyone.",
            "Retrospectives: checking whether the delivered features actually changed actor behaviour as expected.",
            "Challenging assumptions: mapping forces the team to name who will behave differently and how.",
        ]

        public static let history: String = """
            Impact Mapping was created by Gojko Adzic and described in his book "Impact Mapping: \
            Making a Big Impact With Software Products and Projects" (2012). The method draws on \
            Outcome Mapping (used in international development), Lean thinking, and Theory of \
            Constraints. Adzic developed it to address the common failure mode where teams deliver \
            features on time but still miss their business goals.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Impact Mapping — Gojko Adzic",
                url: "https://www.impactmapping.org/book.html"
            ),
            NotationReference(
                title: "Impact mapping (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Impact_mapping"
            ),
        ]

        // Color palette — Vithanco Diagram Style Guide §07
        public static let goalFill = SemanticColor(id: "impactmap.goal.fill", lightHex: "#fdeef1")
        public static let goalBorder = SemanticColor(id: "impactmap.goal.border", lightHex: "#c03858")
        public static let goalText = SemanticColor(id: "impactmap.goal.text", lightHex: "#7a0818")
        public static let actorFill = SemanticColor(id: "impactmap.actor.fill", lightHex: "#e5f7f5")
        public static let actorBorder = SemanticColor(id: "impactmap.actor.border", lightHex: "#1a9488")
        public static let actorText = SemanticColor(id: "impactmap.actor.text", lightHex: "#0a5048")
        public static let impactFill = SemanticColor(id: "impactmap.impact.fill", lightHex: "#fdf8de")
        public static let impactBorder = SemanticColor(id: "impactmap.impact.border", lightHex: "#9a8a18")
        public static let impactText = SemanticColor(id: "impactmap.impact.text", lightHex: "#504808")
        public static let delFill = SemanticColor(id: "impactmap.deliverable.fill", lightHex: "#e0eef8")
        public static let delBorder = SemanticColor(id: "impactmap.deliverable.border", lightHex: "#2070a8")
        public static let delText = SemanticColor(id: "impactmap.deliverable.text", lightHex: "#083858")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.goal, Self.actor, Self.impact, Self.deliverable]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        goal,
                        description: "The goal you are aiming at — the 'Why' of the impact map."),
                    NodeTypeDefinition(
                        actor,
                        description: "Any system or person that could help or hinder achieving the goal — the 'Who'."),
                    NodeTypeDefinition(
                        impact,
                        description: "How an Actor could impact the goal, positively or negatively — the 'How'."),
                    NodeTypeDefinition(
                        deliverable,
                        description: "What could be done to support an Actor in making the desired impact — the 'What'."),
                ]
            }

            private static let goalId = "Goal"
            private static let actorId = "Actor"
            private static let impactId = "Impact"
            private static let deliverableId = "Deliverable"

            public static let goal: NodeType = NodeType(string: goalId)
            public static let actor: NodeType = NodeType(string: actorId)
            public static let impact: NodeType = NodeType(string: impactId)
            public static let deliverable: NodeType = NodeType(string: deliverableId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.goalToActor,
                    Self.actorToImpact,
                    Self.impactToDeliverable,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        goalToActor,
                        description: "A Goal has Actors who can help or hinder its achievement."),
                    EdgeTypeDefinition(
                        actorToImpact,
                        description: "An Actor creates an Impact on the Goal."),
                    EdgeTypeDefinition(
                        impactToDeliverable,
                        description: "A Deliverable enables an Actor to create the desired Impact."),
                ]
            }

            public static let goalToActor: EdgeType = EdgeType(
                id: "goal_to_actor",
                from: Notations.ImpactMapping.NodeTypes.goal,
                to: Notations.ImpactMapping.NodeTypes.actor)

            public static let actorToImpact: EdgeType = EdgeType(
                id: "actor_to_impact",
                from: Notations.ImpactMapping.NodeTypes.actor,
                to: Notations.ImpactMapping.NodeTypes.impact)

            public static let impactToDeliverable: EdgeType = EdgeType(
                id: "impact_to_deliverable",
                from: Notations.ImpactMapping.NodeTypes.impact,
                to: Notations.ImpactMapping.NodeTypes.deliverable)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.goal, "Goal", icon: "goal", fill: goalFill, border: goalBorder, text: goalText),
                .badge(NodeTypes.actor, "Actor", icon: "actor", fill: actorFill, border: actorBorder, text: actorText),
                .badge(NodeTypes.impact, "Impact", icon: "impact", fill: impactFill, border: impactBorder, text: impactText),
                .badge(NodeTypes.deliverable, "Deliverable", icon: "deliverable", fill: delFill, border: delBorder, text: delText),
                // Left-to-right layout works well for the Goal → Actor → Impact → Deliverable flow
                .diagram([Attributes.Group.layoutDirection(.leftToRight)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }

    }

}
