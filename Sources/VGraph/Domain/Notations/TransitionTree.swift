extension Notations {

    /// Transition Tree (TRT) is an implementation planning tool from Theory of Constraints.
    /// It uses cause-and-effect logic to answer "HOW TO CAUSE the change?" by providing
    /// a detailed, step-by-step set of actions needed to implement the desired change
    /// within an organization.
    /// TRT bridges the gap between knowing what to change (from FRT) and actually
    /// implementing those changes through concrete action steps.
    public struct TransitionTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "TRT")
        public static let description =
            "Provides a step-by-step action plan for implementing change by linking concrete actions to their expected effects, answering 'How to cause the change?'"
        public static var diagramLogic: DiagramLogic { .sufficientCause }

        // MARK: - Self-description

        public static let purpose: String = """
            The Transition Tree is the most granular of the TOC Thinking Process tools. It \
            specifies each action required to implement a change, the existing reality that \
            action acts on, and the effect it produces — using sufficient-cause logic. Unlike \
            a task list, every step in a TRT is a logical claim you can verify and challenge. \
            The TRT bridges the gap between the strategic milestone plan (PRT) and actual \
            execution, answering: "How to cause the change, step by step?"
            """

        public static let whenToUse: [String] = [
            "Implementation planning: converting a Prerequisite Tree milestone plan into concrete, ordered actions.",
            "Communicating a change plan to the team executing it — making the 'why this action' visible, not just 'what to do'.",
            "Reviewing an action plan for logical soundness before execution begins.",
            "Post-implementation review: checking whether actions produced the expected effects and updating the tree.",
            "As the final step in a full TOC Thinking Process sequence (CRT → EC → FRT → PRT → TRT).",
        ]

        public static let history: String = """
            The Transition Tree is the fifth and most tactical of the TOC Thinking Process tools \
            developed by Eliyahu Goldratt. It represents the implementation layer of the full TOC \
            analysis sequence and is described in H. William Dettmer's "The Logical Thinking \
            Process" (2007). In practice, the TRT is used less frequently than the other tools \
            because its level of detail is only warranted for complex, high-stakes change initiatives.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "The Logical Thinking Process — H. William Dettmer",
                url: "https://www.goodreads.com/book/show/839658.The_Logical_Thinking_Process"
            )
        ]

        // Color palette — Vithanco Diagram Style Guide §02/§08 (matches CRT + FRT DesirableEffect)
        public static let udeFill = SemanticColor(id: "trt.ude.fill", lightHex: "#fdeef1")
        public static let udeBorder = SemanticColor(id: "trt.ude.border", lightHex: "#c84060")
        public static let udeText = SemanticColor(id: "trt.ude.text", lightHex: "#8a1830")
        public static let imeFill = SemanticColor(id: "trt.intermediate.fill", lightHex: "#edfdf6")
        public static let imeBorder = SemanticColor(id: "trt.intermediate.border", lightHex: "#20a068")
        public static let imeText = SemanticColor(id: "trt.intermediate.text", lightHex: "#0a5838")
        public static let deFill = SemanticColor(id: "trt.desiredEffect.fill", lightHex: "#d8fce0")
        public static let deBorder = SemanticColor(id: "trt.desiredEffect.border", lightHex: "#18a848")
        public static let deText = SemanticColor(id: "trt.desiredEffect.text", lightHex: "#085028")
        public static let givFill = SemanticColor(id: "trt.given.fill", lightHex: "#edf0fd")
        public static let givBorder = SemanticColor(id: "trt.given.border", lightHex: "#4858c8")
        public static let givText = SemanticColor(id: "trt.given.text", lightHex: "#202878")
        public static let chgFill = SemanticColor(id: "trt.change.fill", lightHex: "#fdf6ed")
        public static let chgBorder = SemanticColor(id: "trt.change.border", lightHex: "#c07820")
        public static let chgText = SemanticColor(id: "trt.change.text", lightHex: "#784808")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [
                    Self.undesirableEffect,
                    Self.intermediateEffect,
                    Self.desirableEffect,
                    Self.given,
                    Self.changeable,
                    Self.andJunctor,
                ]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        undesirableEffect,
                        description:
                            "An obstacle or resistance condition that must be overcome before the next action can succeed. Grounds the plan in observable reality."
                    ),
                    NodeTypeDefinition(
                        intermediateEffect,
                        description:
                            "An expected result of a concrete action. Each action produces an effect that enables the next step in the implementation chain."
                    ),
                    NodeTypeDefinition(
                        desirableEffect,
                        description:
                            "The target condition the plan aims to reach. Confirms that the sequence of actions achieves the intended outcome."),
                    NodeTypeDefinition(
                        given,
                        description:
                            "A condition already present in the environment that enables or constrains the planned actions — not itself an action."),
                    NodeTypeDefinition(
                        changeable,
                        description:
                            "A concrete action taken by the implementer. The primary building block of the Transition Tree — actions drive all subsequent effects."
                    ),
                    NodeTypeDefinition(
                        andJunctor,
                        description: "Conjunctive cause — all inputs must be present together to produce the downstream effect."),
                ]
            }

            private static let undesirableEffectId = "UndesirableEffect"
            private static let intermediateEffectId = "IntermediateEffect"
            private static let desirableEffectId = "DesirableEffect"
            private static let givenId = "Given"
            private static let changeableId = "Changeable"
            private static let andJunctorId = "AndJunctor"

            public static let undesirableEffect: NodeType = NodeType(string: undesirableEffectId)
            public static let intermediateEffect: NodeType = NodeType(string: intermediateEffectId)
            public static let desirableEffect: NodeType = NodeType(string: desirableEffectId)
            public static let given: NodeType = NodeType(string: givenId)
            public static let changeable: NodeType = NodeType(string: changeableId)
            public static let andJunctor: NodeType = NodeType(string: andJunctorId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.undesirableCausesUndesirable,
                    Self.undesirableCausesIntermediate,
                    Self.undesirableCausesDesirable,
                    Self.intermediateCausesUndesirable,
                    Self.intermediateCausesIntermediate,
                    Self.intermediateCausesDesirable,
                    Self.desirableCausesUndesirable,
                    Self.desirableCausesIntermediate,
                    Self.desirableCausesDesirable,
                    Self.givenCausesUndesirable,
                    Self.givenCausesIntermediate,
                    Self.givenCausesDesirable,
                    Self.changeableCausesUndesirable,
                    Self.changeableCausesIntermediate,
                    Self.changeableCausesDesirable,
                    Self.undesirableToAndJunctor,
                    Self.intermediateToAndJunctor,
                    Self.desirableToAndJunctor,
                    Self.givenToAndJunctor,
                    Self.changeableToAndJunctor,
                    Self.andJunctorCausesUndesirable,
                    Self.andJunctorCausesIntermediate,
                    Self.andJunctorCausesDesirable,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        undesirableCausesUndesirable,
                        description: "Sufficient cause — an obstacle or resistance condition drives another obstacle."),
                    EdgeTypeDefinition(
                        undesirableCausesIntermediate,
                        description: "Sufficient cause — an obstacle, once overcome, leads to an Intermediate Effect."),
                    EdgeTypeDefinition(
                        undesirableCausesDesirable,
                        description: "Sufficient cause — overcoming an obstacle directly produces the target Desirable Effect."),
                    EdgeTypeDefinition(
                        intermediateCausesUndesirable,
                        description: "Sufficient cause — an action's result reveals or triggers another obstacle to address."),
                    EdgeTypeDefinition(
                        intermediateCausesIntermediate,
                        description: "Sufficient cause — one action result enables the next step in the implementation chain."),
                    EdgeTypeDefinition(
                        intermediateCausesDesirable,
                        description: "Sufficient cause — an action result leads to the target Desirable Effect."),
                    EdgeTypeDefinition(
                        desirableCausesUndesirable,
                        description:
                            "Sufficient cause — reaching a target state exposes a further obstacle. Captures cascading implementation challenges."),
                    EdgeTypeDefinition(
                        desirableCausesIntermediate,
                        description: "Sufficient cause — one Desirable Effect enables a further intermediate step."),
                    EdgeTypeDefinition(
                        desirableCausesDesirable,
                        description: "Sufficient cause — one Desirable Effect reinforces or leads to another. A virtuous-cycle step."),
                    EdgeTypeDefinition(
                        givenCausesUndesirable,
                        description: "Sufficient cause — a pre-existing environmental condition gives rise to an obstacle."),
                    EdgeTypeDefinition(
                        givenCausesIntermediate,
                        description: "Sufficient cause — a pre-existing condition contributes to an Intermediate Effect."),
                    EdgeTypeDefinition(
                        givenCausesDesirable,
                        description: "Sufficient cause — a pre-existing condition contributes to a Desirable Effect."),
                    EdgeTypeDefinition(
                        changeableCausesUndesirable,
                        description: "Sufficient cause — a concrete action encounters an obstacle. Documents expected resistance."),
                    EdgeTypeDefinition(
                        changeableCausesIntermediate,
                        description: "Sufficient cause — a concrete action produces an Intermediate Effect. The primary implementation link."),
                    EdgeTypeDefinition(
                        changeableCausesDesirable,
                        description: "Sufficient cause — a concrete action directly produces the target Desirable Effect."),
                    EdgeTypeDefinition(
                        undesirableToAndJunctor,
                        description: "An obstacle contributes to an AND junctor — all inputs required together to produce the downstream effect."),
                    EdgeTypeDefinition(
                        intermediateToAndJunctor,
                        description: "An Intermediate Effect contributes to an AND junctor."),
                    EdgeTypeDefinition(
                        desirableToAndJunctor,
                        description: "A Desirable Effect contributes to an AND junctor."),
                    EdgeTypeDefinition(
                        givenToAndJunctor,
                        description: "A Given condition contributes to an AND junctor."),
                    EdgeTypeDefinition(
                        changeableToAndJunctor,
                        description: "A concrete action contributes to an AND junctor — combined with other inputs to produce the downstream effect."),
                    EdgeTypeDefinition(
                        andJunctorCausesUndesirable,
                        description: "An AND junctor — when all inputs are present — produces an obstacle."),
                    EdgeTypeDefinition(
                        andJunctorCausesIntermediate,
                        description: "An AND junctor drives an Intermediate Effect when all inputs are present."),
                    EdgeTypeDefinition(
                        andJunctorCausesDesirable,
                        description: "An AND junctor drives a Desirable Effect when all inputs are present."),
                ]
            }

            public static let undesirableCausesUndesirable: EdgeType = EdgeType(
                id: "undesirable_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.undesirableEffect,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let undesirableCausesIntermediate: EdgeType = EdgeType(
                id: "undesirable_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.undesirableEffect,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let undesirableCausesDesirable: EdgeType = EdgeType(
                id: "undesirable_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.undesirableEffect,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)

            public static let intermediateCausesUndesirable: EdgeType = EdgeType(
                id: "intermediate_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.intermediateEffect,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let intermediateCausesIntermediate: EdgeType = EdgeType(
                id: "intermediate_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.intermediateEffect,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let intermediateCausesDesirable: EdgeType = EdgeType(
                id: "intermediate_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.intermediateEffect,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)

            public static let desirableCausesUndesirable: EdgeType = EdgeType(
                id: "desirable_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.desirableEffect,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let desirableCausesIntermediate: EdgeType = EdgeType(
                id: "desirable_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.desirableEffect,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let desirableCausesDesirable: EdgeType = EdgeType(
                id: "desirable_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.desirableEffect,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)

            public static let givenCausesUndesirable: EdgeType = EdgeType(
                id: "given_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.given,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let givenCausesIntermediate: EdgeType = EdgeType(
                id: "given_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.given,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let givenCausesDesirable: EdgeType = EdgeType(
                id: "given_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.given,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)

            public static let changeableCausesUndesirable: EdgeType = EdgeType(
                id: "changeable_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.changeable,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let changeableCausesIntermediate: EdgeType = EdgeType(
                id: "changeable_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.changeable,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let changeableCausesDesirable: EdgeType = EdgeType(
                id: "changeable_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.changeable,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)

            public static let undesirableToAndJunctor: EdgeType = EdgeType(
                id: "undesirable_to_and_junctor",
                from: Notations.TransitionTree.NodeTypes.undesirableEffect,
                to: Notations.TransitionTree.NodeTypes.andJunctor)
            public static let intermediateToAndJunctor: EdgeType = EdgeType(
                id: "intermediate_to_and_junctor",
                from: Notations.TransitionTree.NodeTypes.intermediateEffect,
                to: Notations.TransitionTree.NodeTypes.andJunctor)
            public static let desirableToAndJunctor: EdgeType = EdgeType(
                id: "desirable_to_and_junctor",
                from: Notations.TransitionTree.NodeTypes.desirableEffect,
                to: Notations.TransitionTree.NodeTypes.andJunctor)
            public static let givenToAndJunctor: EdgeType = EdgeType(
                id: "given_to_and_junctor",
                from: Notations.TransitionTree.NodeTypes.given,
                to: Notations.TransitionTree.NodeTypes.andJunctor)
            public static let changeableToAndJunctor: EdgeType = EdgeType(
                id: "changeable_to_and_junctor",
                from: Notations.TransitionTree.NodeTypes.changeable,
                to: Notations.TransitionTree.NodeTypes.andJunctor)

            public static let andJunctorCausesUndesirable: EdgeType = EdgeType(
                id: "and_junctor_causes_undesirable",
                from: Notations.TransitionTree.NodeTypes.andJunctor,
                to: Notations.TransitionTree.NodeTypes.undesirableEffect)
            public static let andJunctorCausesIntermediate: EdgeType = EdgeType(
                id: "and_junctor_causes_intermediate",
                from: Notations.TransitionTree.NodeTypes.andJunctor,
                to: Notations.TransitionTree.NodeTypes.intermediateEffect)
            public static let andJunctorCausesDesirable: EdgeType = EdgeType(
                id: "and_junctor_causes_desirable",
                from: Notations.TransitionTree.NodeTypes.andJunctor,
                to: Notations.TransitionTree.NodeTypes.desirableEffect)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.undesirableEffect, "UDE", icon: "undesirable-effect", fill: udeFill, border: udeBorder, text: udeText),
                .badge(NodeTypes.intermediateEffect, "IME", icon: "intermediate-effect", fill: imeFill, border: imeBorder, text: imeText),
                .badge(NodeTypes.desirableEffect, "DE", icon: "desirable-effect", fill: deFill, border: deBorder, text: deText),
                .badge(NodeTypes.given, "Given", icon: "given", fill: givFill, border: givBorder, text: givText),
                .badge(NodeTypes.changeable, "CHG", icon: "changeable", fill: chgFill, border: chgBorder, text: chgText),
                .junctor(NodeTypes.andJunctor, "and"),
                // Bottom-to-top layout: actions at bottom, desired effects flow upward
                .diagram([Attributes.Group.layoutDirection(.bottomToTop)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
