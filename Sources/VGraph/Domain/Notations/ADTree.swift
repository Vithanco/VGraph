extension Notations {

    /// Attack-Defense Tree (ADTree) is a security modelling methodology based on the formalism
    /// by Kordy, Mauw, Radomirovic & Schweitzer (2014). ADTrees extend classical attack trees
    /// by allowing defense nodes at any level, modelling the interaction between an attacker
    /// and a defender as an ongoing arms race.
    ///
    /// Disjunctive (OR) refinement is the implicit default for sufficient-cause logic:
    /// multiple unjoined children of the same parent each represent an alternative way
    /// to achieve the parent. Only the explicit AND junctor is needed.
    public struct ADTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "ADTree")
        public static let description =
            "Models security scenarios as a game between attacker and defender, with refinement and countermeasure edges at every level."
        public static var diagramLogic: DiagramLogic { .sufficientCause }

        // MARK: - Self-description

        public static let purpose: String = """
            Attack-Defense Trees model a security scenario as a two-player arms race: an attacker \
            trying to compromise a system and a defender countering at every level. Classic attack \
            trees capture only attacker strategies; ADTrees add defense nodes as direct \
            countermeasures to attacks — and attack nodes as countermeasures to defenses — at any \
            depth, giving you a single diagram that captures the full interplay of threats and \
            mitigations.
            """

        public static let whenToUse: [String] = [
            "Assessing the security of a system alongside its defences — showing which attacks are countered and where coverage is thin.",
            "Communicating security trade-offs to non-technical stakeholders: the red/green visual contrast makes gaps immediately readable.",
            "Threat modelling during design: map anticipated attacks, plan defences, then stress-test by asking how each defence could be circumvented.",
            "Layered security scenarios with recursive depth (attack → defence → counter-attack → counter-defence).",
        ]

        public static let history: String = """
            ADTrees were formalised by Barbara Kordy, Sjouke Mauw, Saša Radomirović, and Patrick \
            Schweitzer in "Attack-defense trees" (Journal of Logic and Computation, 2014). They \
            build on Bruce Schneier's attack trees (1999), which provided a systematic framework \
            for evaluating attack scenarios. By adding defense nodes at every level, ADTrees \
            generalise and unify earlier extensions to attack trees.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Attack-defense trees (Kordy, Mauw, Radomirović & Schweitzer, 2014)",
                url: "https://academic.oup.com/logcom/article-abstract/24/1/55/1077264"
            ),
            NotationReference(
                title: "Attack-defense trees — ResearchGate preprint",
                url: "https://www.researchgate.net/publication/268018467_Attack-defense_trees"
            ),
            NotationReference(
                title: "Schneier on Security: Attack Trees (1999)",
                url: "https://www.schneier.com/academic/archives/1999/12/attack_trees.html"
            ),
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let attackFill = SemanticColor(id: "adtree.attack.fill", lightHex: "#fdeef1")
        public static let attackBorder = SemanticColor(id: "adtree.attack.border", lightHex: "#c83040")
        public static let attackText = SemanticColor(id: "adtree.attack.text", lightHex: "#7a0818")
        public static let defenseFill = SemanticColor(id: "adtree.defense.fill", lightHex: "#ecfdf5")
        public static let defenseBorder = SemanticColor(id: "adtree.defense.border", lightHex: "#189858")
        public static let defenseText = SemanticColor(id: "adtree.defense.text", lightHex: "#085028")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [
                    Self.attack,
                    Self.defense,
                    Self.andJunctor,
                ]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        attack,
                        description: "An attacker's goal or sub-goal. Attack nodes can be refined into sub-goals and countered by Defense nodes."),
                    NodeTypeDefinition(
                        defense,
                        description: "A defender's countermeasure or sub-measure. Defense nodes can be refined and challenged by Attack nodes."),
                    NodeTypeDefinition(
                        andJunctor,
                        description: "Conjunctive refinement — all connected child conditions must be met for the parent goal to be achieved."),
                ]
            }

            private static let attackId = "Attack"
            private static let defenseId = "Defense"
            private static let andJunctorId = "AndJunctor"

            public static let attack: NodeType = NodeType(string: attackId)
            public static let defense: NodeType = NodeType(string: defenseId)
            public static let andJunctor: NodeType = NodeType(string: andJunctorId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.attackRefinesAttack,
                    Self.defenseRefinesDefense,

                    Self.defenseCountersAttack,
                    Self.attackCountersDefense,

                    Self.attackToAndJunctor,
                    Self.defenseToAndJunctor,
                    Self.andJunctorToAttack,
                    Self.andJunctorToDefense,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        attackRefinesAttack,
                        description:
                            "Refinement: an Attack is broken into a sub-goal of the same type. All sub-goals contribute to the parent attack."),
                    EdgeTypeDefinition(
                        defenseRefinesDefense,
                        description:
                            "Refinement: a Defense is broken into a sub-measure of the same type. All sub-measures contribute to the parent defense."),
                    EdgeTypeDefinition(
                        defenseCountersAttack,
                        description: "Countermeasure: a Defense node directly counters an Attack node, rendered as a dotted line."),
                    EdgeTypeDefinition(
                        attackCountersDefense,
                        description: "Counter-countermeasure: an Attack node circumvents a Defense node, rendered as a dotted line."),
                    EdgeTypeDefinition(
                        attackToAndJunctor,
                        description: "An Attack feeds into an AND junctor, meaning all sibling attacks must succeed together."),
                    EdgeTypeDefinition(
                        defenseToAndJunctor,
                        description: "A Defense feeds into an AND junctor, meaning all sibling defenses must succeed together."),
                    EdgeTypeDefinition(
                        andJunctorToAttack,
                        description: "An AND junctor feeds into an Attack, grouping conjunctive sub-goals under the parent attack."),
                    EdgeTypeDefinition(
                        andJunctorToDefense,
                        description: "An AND junctor feeds into a Defense, grouping conjunctive sub-measures under the parent defense."),
                ]
            }

            public static let attackRefinesAttack: EdgeType = EdgeType(
                id: "attack_refines_attack",
                from: Notations.ADTree.NodeTypes.attack,
                to: Notations.ADTree.NodeTypes.attack)

            public static let defenseRefinesDefense: EdgeType = EdgeType(
                id: "defense_refines_defense",
                from: Notations.ADTree.NodeTypes.defense,
                to: Notations.ADTree.NodeTypes.defense)

            public static let defenseCountersAttack: EdgeType = EdgeType(
                id: "defense_counters_attack",
                from: Notations.ADTree.NodeTypes.defense,
                to: Notations.ADTree.NodeTypes.attack)

            public static let attackCountersDefense: EdgeType = EdgeType(
                id: "attack_counters_defense",
                from: Notations.ADTree.NodeTypes.attack,
                to: Notations.ADTree.NodeTypes.defense)

            public static let attackToAndJunctor: EdgeType = EdgeType(
                id: "attack_to_and_junctor",
                from: Notations.ADTree.NodeTypes.attack,
                to: Notations.ADTree.NodeTypes.andJunctor)

            public static let defenseToAndJunctor: EdgeType = EdgeType(
                id: "defense_to_and_junctor",
                from: Notations.ADTree.NodeTypes.defense,
                to: Notations.ADTree.NodeTypes.andJunctor)

            public static let andJunctorToAttack: EdgeType = EdgeType(
                id: "and_junctor_to_attack",
                from: Notations.ADTree.NodeTypes.andJunctor,
                to: Notations.ADTree.NodeTypes.attack)

            public static let andJunctorToDefense: EdgeType = EdgeType(
                id: "and_junctor_to_defense",
                from: Notations.ADTree.NodeTypes.andJunctor,
                to: Notations.ADTree.NodeTypes.defense)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.attack, "Attack", icon: "attack", fill: attackFill, border: attackBorder, text: attackText),
                .badge(NodeTypes.defense, "Defense", icon: "defense", fill: defenseFill, border: defenseBorder, text: defenseText),
                .junctor(NodeTypes.andJunctor, "and"),
                .edgeType(EdgeTypes.defenseCountersAttack, [Attributes.Edge.style(.dotted)]),
                .edgeType(EdgeTypes.attackCountersDefense, [Attributes.Edge.style(.dotted)]),
                // Bottom-to-top layout: leaf actions at bottom, root goal at top
                .diagram([Attributes.Group.layoutDirection(.bottomToTop)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
