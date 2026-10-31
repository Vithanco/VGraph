extension Notations {

    public struct CausalLoopDiagram: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }

        /// Loop markers are the model's loops, so they are recorded before folding.
        public static var step: TransformStep? { TLoop.recordStep }

        public static var qualityChecks: [QualityCheck] { [unmarkedLoops] }

        /// Past the cap only the shortest loops get a marker (ADR-0028); the
        /// diagram should not look as if it had no others.
        static func unmarkedLoops(_ graph: VGraph) -> [MessageWithSeverity] {
            guard graph.loopMarkers != .none else { return [] }
            let search = graph.findLoops()
            guard !search.isComplete else { return [] }
            return [
                MessageWithSeverity(
                    message:
                        "This diagram has more loops than can be marked — only the \(search.loops.count) shortest are shown",
                    severity: .warning)
            ]
        }
        public static let id: Identifier<Notation> = .init(rawValue: "CLD")
        public static let description =
            "Models feedback systems using stocks and causal links to reveal reinforcing and balancing loops over time."

        // MARK: - Self-description

        public static let purpose: String = """
            Causal Loop Diagrams describe a system through stocks (variables) and directed causal \
            links labelled "same" (positive) or "opposite" (negative). The key insight is automatic \
            loop detection: reinforcing loops (even number of negative links) drive exponential \
            growth or collapse, while balancing loops (odd number of negative links) create \
            plateaus and oscillations. This makes CLDs uniquely suited for explaining long-term \
            system behaviour that snapshot analyses miss entirely.
            """

        public static let whenToUse: [String] = [
            "Understanding why a system behaves the way it does over time — especially when the behaviour feels counterintuitive.",
            "Identifying unintended consequences before an intervention: trace what happens when you push on one variable.",
            "Finding leverage points: reinforcing loops that amplify change and balancing loops that resist it.",
            "Communicating feedback dynamics to stakeholders who need to understand a systemic problem, not just its symptoms.",
            "Modelling business or organisational systems: growth engines, death spirals, arms races, and goal-seeking behaviour.",
        ]

        public static let history: String = """
            Causal Loop Diagrams grew out of the system dynamics field pioneered by Jay Forrester \
            at MIT in the 1950s and 1960s, originally used to model industrial and urban systems. \
            Donella Meadows later brought the technique to a broad audience through her book \
            "Thinking in Systems" (2008), and Peter Senge popularised the feedback-loop vocabulary \
            in "The Fifth Discipline" (1990). System archetypes — recurring CLD patterns — were \
            formalised by Senge and colleagues as reusable templates for common organisational \
            dynamics.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Thinking in Systems — Donella Meadows",
                url: "https://www.goodreads.com/book/show/3828902-thinking-in-systems"
            ),
            NotationReference(
                title: "System archetypes (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/System_archetype"
            ),
            NotationReference(
                title: "The Fifth Discipline — Peter Senge",
                url: "https://www.goodreads.com/book/show/255127.The_Fifth_Discipline"
            ),
        ]

        // Color palette — Vithanco Diagram Style Guide §09
        public static let stockFill = SemanticColor(id: "cld.stock.fill", lightHex: "#f0f0ec")
        public static let stockBorder = SemanticColor(id: "cld.stock.border", lightHex: "#707068")
        public static let stockText = SemanticColor(id: "cld.stock.text", lightHex: "#303028")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.stock]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        stock,
                        description: "A quantity or state in the system. Stock values change over time based on incoming causal links.")
                ]
            }

            private static let stockId = "Stock"

            public static let stock: NodeType = NodeType(string: stockId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.same,
                    Self.opposite,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        same,
                        description:
                            "Positive causal link — both stocks change in the same direction. If the source increases, the target increases too. Marked with '+'."
                    ),
                    EdgeTypeDefinition(
                        opposite,
                        description:
                            "Negative causal link — the stocks change in opposite directions. If the source increases, the target decreases. Marked with '−'."
                    ),
                ]
            }

            // Same/Positive causal link: both nodes change in the same direction
            public static let same: EdgeType = EdgeType(
                id: "same",
                from: Notations.CausalLoopDiagram.NodeTypes.stock,
                to: Notations.CausalLoopDiagram.NodeTypes.stock)

            // Opposite/Negative causal link: nodes change in opposite directions
            public static let opposite: EdgeType = EdgeType(
                id: "opposite",
                from: Notations.CausalLoopDiagram.NodeTypes.stock,
                to: Notations.CausalLoopDiagram.NodeTypes.stock)
        }

        public static var definitions: AttributeDefContainer { Attributes.Loop.definitions }

        public static var values: [TypeValues] {
            let polarity = [Attributes.Edge.len("2.5"), Attributes.Edge.labelangle("45"), Attributes.Edge.labeldistance("1.7")]
            return [
                .strip(NodeTypes.stock, fill: stockFill, border: stockBorder, text: stockText),
                .edgeType(
                    EdgeTypes.same,
                    [
                        Attribute(definition: Attributes.Loop.style, value: LoopStyle.reinforcing.asString),
                        Attributes.Edge.headLabel("+"),
                        Attributes.Edge.menuTitle("+  more → more"),
                    ] + polarity),
                .edgeType(
                    EdgeTypes.opposite,
                    [
                        Attribute(definition: Attributes.Loop.style, value: LoopStyle.balancing.asString),
                        Attributes.Edge.style(.dashed),
                        Attributes.Edge.headLabel("−"),
                        Attributes.Edge.menuTitle("−  more → less"),
                    ] + polarity),
                .diagram([
                    // neato (force-directed) suits circular feedback loops
                    Attributes.Group.layoutEngine("neato"),
                    Attributes.Group.overlap("scale"),
                    Attributes.Group.sep("+20"),
                    Attributes.Group.splines("curved"),
                ]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }
}
