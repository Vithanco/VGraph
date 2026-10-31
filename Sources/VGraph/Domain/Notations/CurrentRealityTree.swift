extension Notations {

    /// Current Reality Tree (CRT) is a root cause analysis tool from Theory of Constraints.
    /// It uses "If...Then..." logic to answer "WHAT to change?" by modeling cause-and-effect
    /// relationships between undesirable effects and their root causes.
    public struct CurrentRealityTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "CRT")
        public static let description =
            "Reveals root causes of problems by tracing cause-and-effect links from Undesirable Effects down to core drivers, answering 'What to change?'"
        public static var diagramLogic: DiagramLogic { .sufficientCause }

        // MARK: - Self-description

        public static let purpose: String = """
            The Current Reality Tree starts with a set of Undesirable Effects (UDEs) — problems \
            you can observe right now — and traces their cause-and-effect relationships downward \
            until you find the root cause that drives most or all of them. Because everything is \
            connected through "If… then…" sufficient-cause logic, every link in the tree is \
            verifiable. Identifying the root cause answers the first Theory of Constraints \
            question: "What to change?"
            """

        public static let whenToUse: [String] = [
            "Root cause analysis when multiple symptoms suggest a shared underlying cause.",
            "Organisational problem-solving: finding the core policy or constraint that generates most UDEs.",
            "Before designing a solution: confirming what the actual root cause is, not just the most visible symptom.",
            "Team alignment: building shared understanding of why things are the way they are, using logic everyone can challenge.",
            "As the first step in a full TOC Thinking Process analysis before the Evaporating Cloud (EC) and Future Reality Tree (FRT).",
        ]

        public static let history: String = """
            The Current Reality Tree is one of the five Thinking Process tools developed by \
            Eliyahu Goldratt as part of Theory of Constraints in the late 1980s and early 1990s. \
            Goldratt introduced the ideas in his business novel "The Goal" (1984) and formalised \
            the Thinking Processes in "It's Not Luck" (1994). H. William Dettmer later provided \
            a systematic guide in "The Logical Thinking Process" (2007), which remains the \
            standard reference for practitioners.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "The Goal — Eliyahu Goldratt",
                url: "https://www.goodreads.com/book/show/113934.The_Goal"
            ),
            NotationReference(
                title: "The Logical Thinking Process — H. William Dettmer",
                url: "https://www.goodreads.com/book/show/839658.The_Logical_Thinking_Process"
            ),
            NotationReference(
                title: "Theory of Constraints (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Theory_of_constraints"
            ),
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let udeFill = SemanticColor(id: "crt.ude.fill", lightHex: "#fdeef1")
        public static let udeBorder = SemanticColor(id: "crt.ude.border", lightHex: "#c84060")
        public static let udeText = SemanticColor(id: "crt.ude.text", lightHex: "#8a1830")
        public static let imeFill = SemanticColor(id: "crt.intermediate.fill", lightHex: "#edfdf6")
        public static let imeBorder = SemanticColor(id: "crt.intermediate.border", lightHex: "#20a068")
        public static let imeText = SemanticColor(id: "crt.intermediate.text", lightHex: "#0a5838")
        // The guide gives Desirable Effect only to FRT/TRT; CRT borrows that palette.
        public static let deFill = SemanticColor(id: "crt.desiredEffect.fill", lightHex: "#d8fce0")
        public static let deBorder = SemanticColor(id: "crt.desiredEffect.border", lightHex: "#18a848")
        public static let deText = SemanticColor(id: "crt.desiredEffect.text", lightHex: "#085028")
        public static let givFill = SemanticColor(id: "crt.given.fill", lightHex: "#edf0fd")
        public static let givBorder = SemanticColor(id: "crt.given.border", lightHex: "#4858c8")
        public static let givText = SemanticColor(id: "crt.given.text", lightHex: "#202878")
        public static let chgFill = SemanticColor(id: "crt.change.fill", lightHex: "#fdf6ed")
        public static let chgBorder = SemanticColor(id: "crt.change.border", lightHex: "#c07820")
        public static let chgText = SemanticColor(id: "crt.change.text", lightHex: "#784808")

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
                            "A symptom or problem currently observed in the system — the 'undesirable effect' the analysis aims to eliminate."),
                    NodeTypeDefinition(
                        intermediateEffect,
                        description:
                            "A cause-and-effect step between root causes and the top-level undesirable effects. Neither the root cause nor the final symptom."
                    ),
                    NodeTypeDefinition(
                        desirableEffect,
                        description:
                            "A positive condition in the system. Included to show that some causes also produce good outcomes that must be preserved."
                    ),
                    NodeTypeDefinition(
                        given,
                        description:
                            "A condition taken as fixed by the environment — not under the organisation's control and not a candidate for change."),
                    NodeTypeDefinition(
                        changeable,
                        description:
                            "A root cause or condition that the organisation can influence. Candidate injection points for breaking the chain of undesirable effects."
                    ),
                    NodeTypeDefinition(
                        andJunctor,
                        description: "Conjunctive cause — all inputs to this junctor must be present simultaneously to produce the downstream effect."
                    ),
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
                        description: "Sufficient cause — one Undesirable Effect drives another Undesirable Effect."),
                    EdgeTypeDefinition(
                        undesirableCausesIntermediate,
                        description: "Sufficient cause — an Undesirable Effect drives an Intermediate Effect."),
                    EdgeTypeDefinition(
                        undesirableCausesDesirable,
                        description:
                            "Sufficient cause — an Undesirable Effect also produces a Desirable Effect (to be preserved when eliminating the UDE)."),
                    EdgeTypeDefinition(
                        intermediateCausesUndesirable,
                        description: "Sufficient cause — an Intermediate Effect drives an Undesirable Effect."),
                    EdgeTypeDefinition(
                        intermediateCausesIntermediate,
                        description: "Sufficient cause — one Intermediate Effect drives another Intermediate Effect."),
                    EdgeTypeDefinition(
                        intermediateCausesDesirable,
                        description: "Sufficient cause — an Intermediate Effect also produces a Desirable Effect."),
                    EdgeTypeDefinition(
                        desirableCausesUndesirable,
                        description: "Sufficient cause — a Desirable Effect has an unintended negative consequence."),
                    EdgeTypeDefinition(
                        desirableCausesIntermediate,
                        description: "Sufficient cause — a Desirable Effect drives an Intermediate Effect."),
                    EdgeTypeDefinition(
                        desirableCausesDesirable,
                        description: "Sufficient cause — one Desirable Effect reinforces another Desirable Effect."),
                    EdgeTypeDefinition(
                        givenCausesUndesirable,
                        description: "Sufficient cause — a fixed environmental condition drives an Undesirable Effect."),
                    EdgeTypeDefinition(
                        givenCausesIntermediate,
                        description: "Sufficient cause — a fixed environmental condition drives an Intermediate Effect."),
                    EdgeTypeDefinition(
                        givenCausesDesirable,
                        description: "Sufficient cause — a fixed environmental condition produces a Desirable Effect."),
                    EdgeTypeDefinition(
                        changeableCausesUndesirable,
                        description:
                            "Sufficient cause — a root cause under the organisation's control drives an Undesirable Effect. Primary injection candidate."
                    ),
                    EdgeTypeDefinition(
                        changeableCausesIntermediate,
                        description: "Sufficient cause — a Changeable condition drives an Intermediate Effect."),
                    EdgeTypeDefinition(
                        changeableCausesDesirable,
                        description: "Sufficient cause — a Changeable condition also produces a Desirable Effect to preserve."),
                    EdgeTypeDefinition(
                        undesirableToAndJunctor,
                        description:
                            "An Undesirable Effect contributes to an AND junctor — must combine with all other inputs to produce the downstream effect."
                    ),
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
                        description: "A Changeable condition contributes to an AND junctor."),
                    EdgeTypeDefinition(
                        andJunctorCausesUndesirable,
                        description: "An AND junctor — when all its inputs are present — drives an Undesirable Effect."),
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
                from: Notations.CurrentRealityTree.NodeTypes.undesirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let undesirableCausesIntermediate: EdgeType = EdgeType(
                id: "undesirable_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.undesirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let undesirableCausesDesirable: EdgeType = EdgeType(
                id: "undesirable_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.undesirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)

            public static let intermediateCausesUndesirable: EdgeType = EdgeType(
                id: "intermediate_causes_undesirable",
                from: Notations.CurrentRealityTree.NodeTypes.intermediateEffect,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let intermediateCausesIntermediate: EdgeType = EdgeType(
                id: "intermediate_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.intermediateEffect,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let intermediateCausesDesirable: EdgeType = EdgeType(
                id: "intermediate_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.intermediateEffect,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)

            public static let desirableCausesUndesirable: EdgeType = EdgeType(
                id: "desirable_causes_undesirable",
                from: Notations.CurrentRealityTree.NodeTypes.desirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let desirableCausesIntermediate: EdgeType = EdgeType(
                id: "desirable_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.desirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let desirableCausesDesirable: EdgeType = EdgeType(
                id: "desirable_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.desirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)

            public static let givenCausesUndesirable: EdgeType = EdgeType(
                id: "given_causes_undesirable",
                from: Notations.CurrentRealityTree.NodeTypes.given,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let givenCausesIntermediate: EdgeType = EdgeType(
                id: "given_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.given,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let givenCausesDesirable: EdgeType = EdgeType(
                id: "given_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.given,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)

            public static let changeableCausesUndesirable: EdgeType = EdgeType(
                id: "changeable_causes_undesirable",
                from: Notations.CurrentRealityTree.NodeTypes.changeable,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let changeableCausesIntermediate: EdgeType = EdgeType(
                id: "changeable_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.changeable,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let changeableCausesDesirable: EdgeType = EdgeType(
                id: "changeable_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.changeable,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)

            public static let undesirableToAndJunctor: EdgeType = EdgeType(
                id: "undesirable_to_and_junctor",
                from: Notations.CurrentRealityTree.NodeTypes.undesirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.andJunctor)
            public static let intermediateToAndJunctor: EdgeType = EdgeType(
                id: "intermediate_to_and_junctor",
                from: Notations.CurrentRealityTree.NodeTypes.intermediateEffect,
                to: Notations.CurrentRealityTree.NodeTypes.andJunctor)
            public static let desirableToAndJunctor: EdgeType = EdgeType(
                id: "desirable_to_and_junctor",
                from: Notations.CurrentRealityTree.NodeTypes.desirableEffect,
                to: Notations.CurrentRealityTree.NodeTypes.andJunctor)
            public static let givenToAndJunctor: EdgeType = EdgeType(
                id: "given_to_and_junctor",
                from: Notations.CurrentRealityTree.NodeTypes.given,
                to: Notations.CurrentRealityTree.NodeTypes.andJunctor)
            public static let changeableToAndJunctor: EdgeType = EdgeType(
                id: "changeable_to_and_junctor",
                from: Notations.CurrentRealityTree.NodeTypes.changeable,
                to: Notations.CurrentRealityTree.NodeTypes.andJunctor)

            public static let andJunctorCausesUndesirable: EdgeType = EdgeType(
                id: "and_junctor_causes_undesirable",
                from: Notations.CurrentRealityTree.NodeTypes.andJunctor,
                to: Notations.CurrentRealityTree.NodeTypes.undesirableEffect)
            public static let andJunctorCausesIntermediate: EdgeType = EdgeType(
                id: "and_junctor_causes_intermediate",
                from: Notations.CurrentRealityTree.NodeTypes.andJunctor,
                to: Notations.CurrentRealityTree.NodeTypes.intermediateEffect)
            public static let andJunctorCausesDesirable: EdgeType = EdgeType(
                id: "and_junctor_causes_desirable",
                from: Notations.CurrentRealityTree.NodeTypes.andJunctor,
                to: Notations.CurrentRealityTree.NodeTypes.desirableEffect)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.undesirableEffect, "UDE", icon: "undesirable-effect", fill: udeFill, border: udeBorder, text: udeText),
                .badge(NodeTypes.intermediateEffect, "IME", icon: "intermediate-effect", fill: imeFill, border: imeBorder, text: imeText),
                .badge(NodeTypes.desirableEffect, "DE", icon: "desirable-effect", fill: deFill, border: deBorder, text: deText),
                .badge(NodeTypes.given, "Given", icon: "given", fill: givFill, border: givBorder, text: givText),
                .badge(NodeTypes.changeable, "CHG", icon: "changeable", fill: chgFill, border: chgBorder, text: chgText),
                .junctor(NodeTypes.andJunctor, "and"),
                // Bottom-to-top layout: causes at bottom, effects flow upward
                .diagram([Attributes.Group.layoutDirection(.bottomToTop)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
