extension Notations {

    /// Goal Tree (GT) is a strategic planning tool from Theory of Constraints.
    /// It uses necessity logic to define what a system must achieve: a single Goal,
    /// supported by 3-5 Critical Success Factors, which in turn require a network
    /// of Necessary Conditions. Invented by H. William Dettmer, it answers
    /// "What must we achieve to reach our Goal?"
    public struct GoalTree: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "GoalTree")
        public static var diagramLogic: DiagramLogic { .necessaryCondition }
        public static let description =
            "Defines what a system must achieve by articulating a single Goal, Critical Success Factors, and Necessary Conditions using necessity-based logic."

        // MARK: - Self-description

        public static let purpose: String = """
            A Goal Tree defines success for a system, team, or organisation using \
            necessary-condition logic: a single Goal at the top depends on 3-5 Critical Success \
            Factors, each of which requires a network of Necessary Conditions. Because every \
            element must be fully achieved for the goal to be reached, the tree reveals exactly \
            which conditions are met, which are not, and where the most critical gaps are.
            """

        public static let whenToUse: [String] = [
            "Defining what 'good' looks like for a system, team, or organisation before setting KPIs or OKRs.",
            "Strategic planning: identifying the must-achieve conditions that any strategy must address.",
            "Diagnosing underperformance: walking the tree reveals which Necessary Condition is not being met.",
            "Communicating organisational priorities in a verifiable, logical structure stakeholders can inspect.",
            "As a lighter entry point to TOC analysis — cleaner and faster to build than a CRT when the goal is already clear.",
        ]

        public static let history: String = """
            The Goal Tree was developed by H. William Dettmer as an evolution of the TOC Thinking \
            Processes, described in his book "The Logical Thinking Process" (2007) and further \
            elaborated in his work on strategic navigation. Dettmer designed the Goal Tree as a \
            simpler, more accessible entry point to TOC analysis than the full five-tool sequence, \
            making it useful as a standalone strategic planning tool outside of purely operational \
            contexts.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "The Logical Thinking Process — H. William Dettmer",
                url: "https://www.goodreads.com/book/show/839658.The_Logical_Thinking_Process"
            ),
            NotationReference(
                title: "Goal tree (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Goal_tree_(management)"
            ),
        ]

        // Color palette — Vithanco Diagram Style Guide §08
        public static let goalFill = SemanticColor(id: "goaltree.goal.fill", lightHex: "#deeeff")
        public static let goalBorder = SemanticColor(id: "goaltree.goal.border", lightHex: "#1878c8")
        public static let goalText = SemanticColor(id: "goaltree.goal.text", lightHex: "#083878")
        public static let csfFill = SemanticColor(id: "goaltree.csf.fill", lightHex: "#d8f8f8")
        public static let csfBorder = SemanticColor(id: "goaltree.csf.border", lightHex: "#0898b8")
        public static let csfText = SemanticColor(id: "goaltree.csf.text", lightHex: "#044858")
        public static let ncFill = SemanticColor(id: "goaltree.necessaryCondition.fill", lightHex: "#fdf3de")
        public static let ncBorder = SemanticColor(id: "goaltree.necessaryCondition.border", lightHex: "#c89028")
        public static let ncText = SemanticColor(id: "goaltree.necessaryCondition.text", lightHex: "#6a4808")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [
                    Self.goal,
                    Self.criticalSuccessFactor,
                    Self.necessaryCondition,
                ]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        goal,
                        description: "The ultimate purpose the system exists to achieve. Exactly one Goal sits at the top of the tree."),
                    NodeTypeDefinition(
                        criticalSuccessFactor,
                        description:
                            "A high-level outcome without which the Goal cannot be achieved. Typically 3 to 5 CSFs sit directly below the Goal."),
                    NodeTypeDefinition(
                        necessaryCondition,
                        description:
                            "An indispensable task or prerequisite supporting a CSF or another NC. NCs cascade into multiple levels of increasing detail."
                    ),
                ]
            }

            private static let goalId = "Goal"
            private static let criticalSuccessFactorId = "CriticalSuccessFactor"
            private static let necessaryConditionId = "NecessaryCondition"

            public static let goal: NodeType = NodeType(string: goalId)
            public static let criticalSuccessFactor: NodeType = NodeType(string: criticalSuccessFactorId)
            public static let necessaryCondition: NodeType = NodeType(string: necessaryConditionId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.csfToGoal,
                    Self.ncToCSF,
                    Self.ncToNC,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        csfToGoal,
                        description: "A CSF is necessary for the Goal. Read: 'In order to achieve the Goal, we must have this CSF.'"),
                    EdgeTypeDefinition(
                        ncToCSF,
                        description: "A NC is necessary for the CSF. Read: 'In order to achieve this CSF, we must have this NC.'"),
                    EdgeTypeDefinition(
                        ncToNC,
                        description: "A sub-NC is necessary for another NC, enabling cascading layers of prerequisites."),
                ]
            }

            public static let csfToGoal: EdgeType = EdgeType(
                id: "csf_to_goal",
                from: Notations.GoalTree.NodeTypes.criticalSuccessFactor,
                to: Notations.GoalTree.NodeTypes.goal)

            public static let ncToCSF: EdgeType = EdgeType(
                id: "nc_to_csf",
                from: Notations.GoalTree.NodeTypes.necessaryCondition,
                to: Notations.GoalTree.NodeTypes.criticalSuccessFactor)

            public static let ncToNC: EdgeType = EdgeType(
                id: "nc_to_nc",
                from: Notations.GoalTree.NodeTypes.necessaryCondition,
                to: Notations.GoalTree.NodeTypes.necessaryCondition)
        }

        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.goal, "Goal", icon: "goal", fill: goalFill, border: goalBorder, text: goalText),
                .badge(NodeTypes.criticalSuccessFactor, "CSF", icon: "critical-success-factor", fill: csfFill, border: csfBorder, text: csfText),
                .badge(NodeTypes.necessaryCondition, "NC", icon: "necessary-condition", fill: ncFill, border: ncBorder, text: ncText),
                // Top-to-bottom layout: Goal at top, NCs expand downward
                .diagram([Attributes.Group.layoutDirection(.topToBottom)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }

        // MARK: - Quality Checks

        public static var qualityChecks: [QualityCheck] {
            [exactlyOneGoal, csfCount]
        }

        static func exactlyOneGoal(_ graph: VGraph) -> [MessageWithSeverity] {
            let goalNodes = graph.nodes.filter { (try? graph.nodeType(for: $0)) == NodeTypes.goal }
            if goalNodes.count == 0 {
                return [
                    MessageWithSeverity(
                        message: "Goal Tree has no Goal node (exactly 1 required)",
                        severity: .error
                    )
                ]
            } else if goalNodes.count > 1 {
                return [
                    MessageWithSeverity(
                        message: "Goal Tree has \(goalNodes.count) Goal nodes (exactly 1 required)",
                        severity: .error
                    )
                ]
            }
            return []
        }

        /// Recommended: 3-5 Critical Success Factors.
        static func csfCount(_ graph: VGraph) -> [MessageWithSeverity] {
            let csfNodes = graph.nodes.filter {
                (try? graph.nodeType(for: $0)) == NodeTypes.criticalSuccessFactor
            }
            if csfNodes.count < 3 || csfNodes.count > 5 {
                return [
                    MessageWithSeverity(
                        message: "Goal Tree has \(csfNodes.count) Critical Success Factors (recommended: 3-5)",
                        severity: .info
                    )
                ]
            }
            return []
        }
    }

}
