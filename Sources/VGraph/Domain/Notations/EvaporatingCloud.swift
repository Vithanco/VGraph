extension Notations {

    /// Evaporating Cloud (EC) is a conflict resolution tool from Theory of Constraints.
    /// It uses "In order to [X] we must provide [Y]" (necessary condition) logic to
    /// surface and challenge the assumptions behind a conflict, enabling breakthrough solutions.
    /// The EC answers "What is the conflict?" by modeling a shared objective, competing needs
    /// and wants, the resulting conflict, and the hidden assumptions that create it.
    public struct EvaporatingCloud: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "EC")
        public static let description =
            "Surfaces and resolves conflicts by exposing the hidden assumptions behind competing Wants, enabling win-win solutions that dissolve the conflict entirely."
        public static var diagramLogic: DiagramLogic { .necessaryCondition }

        // MARK: - Self-description

        public static let purpose: String = """
            The Evaporating Cloud maps a conflict as a necessary-condition tree: a shared \
            Objective depends on two competing Needs, each of which requires a Want — and the \
            two Wants are incompatible. The cloud forces you to make the hidden assumptions \
            behind each "In order to… we must…" link explicit. Because the conflict exists only \
            while those assumptions are accepted, invalidating even one assumption dissolves the \
            conflict entirely — making it "evaporate."
            """

        public static let whenToUse: [String] = [
            "When two parties appear stuck in an irresolvable conflict: map the structure before negotiating positions.",
            "When a constraint analysis reveals a core policy clash driving most problems in the system.",
            "Before negotiation: surfacing assumptions lets you challenge the conflict's root, not just trade concessions.",
            "Personal dilemmas: externalising an internal conflict reveals a third option that satisfies both needs.",
            "As a precursor to the Future Reality Tree: the cloud surfaces the injection (solution) that the FRT will validate.",
        ]

        public static let history: String = """
            Eliyahu Goldratt invented the Evaporating Cloud (also called the "Conflict Cloud") as \
            part of Theory of Constraints Thinking Processes, introduced in "The Goal" (1984) and \
            formalised in subsequent TOC literature. The name reflects the goal: rather than \
            compromising between two positions, you dissolve the conflict by surfacing and \
            invalidating the assumption that makes it appear irresolvable.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "It's Not Luck — Eliyahu Goldratt",
                url: "https://www.goodreads.com/book/show/157385.It_s_Not_Luck"
            ),
            NotationReference(
                title: "The Logical Thinking Process — H. William Dettmer",
                url: "https://www.goodreads.com/book/show/839658.The_Logical_Thinking_Process"
            ),
            NotationReference(
                title: "Evaporating cloud (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Evaporating_cloud"
            ),
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let objFill = SemanticColor(id: "ec.objective.fill", lightHex: "#d8fdf6")
        public static let objBorder = SemanticColor(id: "ec.objective.border", lightHex: "#00b898")
        public static let objText = SemanticColor(id: "ec.objective.text", lightHex: "#005848")
        public static let needFill = SemanticColor(id: "ec.need.fill", lightHex: "#dce6f8")
        public static let needBorder = SemanticColor(id: "ec.need.border", lightHex: "#2050b8")
        public static let needText = SemanticColor(id: "ec.need.text", lightHex: "#0a1e68")
        public static let wantFill = SemanticColor(id: "ec.want.fill", lightHex: "#fff3e5")
        public static let wantBorder = SemanticColor(id: "ec.want.border", lightHex: "#c07020")
        public static let wantText = SemanticColor(id: "ec.want.text", lightHex: "#6a3808")
        public static let asmFill = SemanticColor(id: "ec.assumption.fill", lightHex: "#f0ebff")
        public static let asmBorder = SemanticColor(id: "ec.assumption.border", lightHex: "#7038d0")
        public static let asmText = SemanticColor(id: "ec.assumption.text", lightHex: "#3a1878")
        public static let solFill = SemanticColor(id: "ec.solution.fill", lightHex: "#e5f2fd")
        public static let solBorder = SemanticColor(id: "ec.solution.border", lightHex: "#2888d0")
        public static let solText = SemanticColor(id: "ec.solution.text", lightHex: "#083878")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [
                    Self.commonObjective,
                    Self.need,
                    Self.want,
                    Self.conflict,
                    Self.orJunctor,
                    Self.assumption,
                    Self.solution,
                ]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        commonObjective,
                        description:
                            "The shared goal that both sides of the conflict genuinely want to achieve. Establishes that both parties are on the same side."
                    ),
                    NodeTypeDefinition(
                        need,
                        description: "A necessary condition each side must satisfy to achieve the Common Objective. Each need is real and legitimate."
                    ),
                    NodeTypeDefinition(
                        want,
                        description:
                            "The specific action or requirement each side insists on to satisfy their Need. The Wants are mutually exclusive — the conflict."
                    ),
                    NodeTypeDefinition(
                        conflict,
                        description:
                            "The explicit clash between the two Wants. Rendered as a symbol to make the conflict visible rather than implicit."),
                    NodeTypeDefinition(
                        orJunctor,
                        description:
                            "Disjunctive necessary condition — any one of the inputs satisfies the downstream condition. Use to express alternative paths within the cloud."
                    ),
                    NodeTypeDefinition(
                        assumption,
                        description:
                            "A hidden belief that makes a link in the cloud appear necessary. Challenging or invalidating an Assumption dissolves the conflict."
                    ),
                    NodeTypeDefinition(
                        solution,
                        description:
                            "An injection that breaks an Assumption, creating a path to satisfy both Needs simultaneously without the conflict."),
                ]
            }

            private static let commonObjectiveId = "CommonObjective"
            private static let needId = "Need"
            private static let wantId = "Want"
            private static let conflictId = "Conflict"
            private static let orJunctorId = "OrJunctor"
            private static let assumptionId = "Assumption"
            private static let solutionId = "Solution"

            public static let commonObjective: NodeType = NodeType(string: commonObjectiveId)
            public static let need: NodeType = NodeType(string: needId)
            public static let want: NodeType = NodeType(string: wantId)
            public static let conflict: NodeType = NodeType(string: conflictId)
            public static let orJunctor: NodeType = NodeType(string: orJunctorId)
            public static let assumption: NodeType = NodeType(string: assumptionId)
            public static let solution: NodeType = NodeType(string: solutionId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.objectiveToNeed,
                    Self.objectiveToOr,
                    Self.needToWant,
                    Self.needToOr,
                    Self.needToAssumption,
                    Self.needToSolution,
                    Self.wantToConflict,
                    Self.wantToOr,
                    Self.wantToAssumption,
                    Self.conflictToOr,
                    Self.conflictToAssumption,
                    Self.orToWant,
                    Self.orToConflict,
                    Self.orToOr,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        objectiveToNeed,
                        description: "Necessary condition — in order to achieve the Common Objective, this Need must be satisfied."),
                    EdgeTypeDefinition(
                        objectiveToOr,
                        description:
                            "The Common Objective feeds into an OR junctor — any single alternative input satisfies the downstream condition."),
                    EdgeTypeDefinition(
                        needToWant,
                        description: "Necessary condition — in order to satisfy this Need, the associated Want must be in place."),
                    EdgeTypeDefinition(
                        needToOr,
                        description: "A Need feeds into an OR junctor to express an alternative necessary condition."),
                    EdgeTypeDefinition(
                        needToAssumption,
                        description:
                            "Labels the hidden belief that makes the Need→Want link appear necessary. Challenging this Assumption can dissolve the conflict."
                    ),
                    EdgeTypeDefinition(
                        needToSolution,
                        description:
                            "A Solution that satisfies this Need without requiring the conflicting Want. The injection that evaporates the cloud."),
                    EdgeTypeDefinition(
                        wantToConflict,
                        description: "This Want is in direct conflict with the opposing Want. The edge makes the clash explicit."),
                    EdgeTypeDefinition(
                        wantToOr,
                        description: "A Want feeds into an OR junctor to express an alternative necessary condition."),
                    EdgeTypeDefinition(
                        wantToAssumption,
                        description:
                            "Labels the hidden belief behind the Want. Surfacing and invalidating this Assumption opens the path to resolution."),
                    EdgeTypeDefinition(
                        conflictToOr,
                        description: "The Conflict feeds into an OR junctor representing an alternative conflicting requirement."),
                    EdgeTypeDefinition(
                        conflictToAssumption,
                        description: "Labels a hidden belief that underlies the conflict itself. Challenging it may dissolve the entire cloud."),
                    EdgeTypeDefinition(
                        orToWant,
                        description: "An OR junctor produces a Want when any single input is satisfied."),
                    EdgeTypeDefinition(
                        orToConflict,
                        description: "An OR junctor produces the Conflict condition when any single input is present."),
                    EdgeTypeDefinition(
                        orToOr,
                        description: "One OR junctor feeds into another, allowing compound alternative conditions to be chained."),
                ]
            }

            public static let objectiveToNeed: EdgeType = EdgeType(
                id: "objective_to_need",
                from: Notations.EvaporatingCloud.NodeTypes.commonObjective,
                to: Notations.EvaporatingCloud.NodeTypes.need)

            public static let objectiveToOr: EdgeType = EdgeType(
                id: "objective_to_or",
                from: Notations.EvaporatingCloud.NodeTypes.commonObjective,
                to: Notations.EvaporatingCloud.NodeTypes.orJunctor)

            public static let needToWant: EdgeType = EdgeType(
                id: "need_to_want",
                from: Notations.EvaporatingCloud.NodeTypes.need,
                to: Notations.EvaporatingCloud.NodeTypes.want)

            public static let needToOr: EdgeType = EdgeType(
                id: "need_to_or",
                from: Notations.EvaporatingCloud.NodeTypes.need,
                to: Notations.EvaporatingCloud.NodeTypes.orJunctor)

            public static let needToAssumption: EdgeType = EdgeType(
                id: "need_to_assumption",
                from: Notations.EvaporatingCloud.NodeTypes.need,
                to: Notations.EvaporatingCloud.NodeTypes.assumption)

            public static let needToSolution: EdgeType = EdgeType(
                id: "need_to_solution",
                from: Notations.EvaporatingCloud.NodeTypes.need,
                to: Notations.EvaporatingCloud.NodeTypes.solution)

            public static let wantToConflict: EdgeType = EdgeType(
                id: "want_to_conflict",
                from: Notations.EvaporatingCloud.NodeTypes.want,
                to: Notations.EvaporatingCloud.NodeTypes.conflict)

            public static let wantToOr: EdgeType = EdgeType(
                id: "want_to_or",
                from: Notations.EvaporatingCloud.NodeTypes.want,
                to: Notations.EvaporatingCloud.NodeTypes.orJunctor)

            public static let wantToAssumption: EdgeType = EdgeType(
                id: "want_to_assumption",
                from: Notations.EvaporatingCloud.NodeTypes.want,
                to: Notations.EvaporatingCloud.NodeTypes.assumption)

            public static let conflictToOr: EdgeType = EdgeType(
                id: "conflict_to_or",
                from: Notations.EvaporatingCloud.NodeTypes.conflict,
                to: Notations.EvaporatingCloud.NodeTypes.orJunctor)

            public static let conflictToAssumption: EdgeType = EdgeType(
                id: "conflict_to_assumption",
                from: Notations.EvaporatingCloud.NodeTypes.conflict,
                to: Notations.EvaporatingCloud.NodeTypes.assumption)

            public static let orToWant: EdgeType = EdgeType(
                id: "or_to_want",
                from: Notations.EvaporatingCloud.NodeTypes.orJunctor,
                to: Notations.EvaporatingCloud.NodeTypes.want)

            public static let orToConflict: EdgeType = EdgeType(
                id: "or_to_conflict",
                from: Notations.EvaporatingCloud.NodeTypes.orJunctor,
                to: Notations.EvaporatingCloud.NodeTypes.conflict)

            public static let orToOr: EdgeType = EdgeType(
                id: "or_to_or",
                from: Notations.EvaporatingCloud.NodeTypes.orJunctor,
                to: Notations.EvaporatingCloud.NodeTypes.orJunctor)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.commonObjective, "Objective", icon: "common-objective", fill: objFill, border: objBorder, text: objText),
                .badge(NodeTypes.need, "Need", icon: "need", fill: needFill, border: needBorder, text: needText),
                .badge(NodeTypes.want, "Want", icon: "want", fill: wantFill, border: wantBorder, text: wantText),
                .icon(NodeTypes.conflict, "conflict"),
                .junctor(NodeTypes.orJunctor, "or"),
                .badge(NodeTypes.assumption, "Assumption", icon: "assumption", fill: asmFill, border: asmBorder, text: asmText),
                .badge(NodeTypes.solution, "Solution", icon: "solution", fill: solFill, border: solBorder, text: solText),
                // Left-to-right layout: Common Objective on left, Conflict on right
                .diagram([Attributes.Group.layoutDirection(.leftToRight)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
