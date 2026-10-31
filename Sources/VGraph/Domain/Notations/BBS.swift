extension Notations {

    public struct Bbs: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "BBS")
        public static let description =
            "Plans project execution backwards from investment objectives through benefits and business changes to enabling deliverables."

        // MARK: - Self-description

        public static let purpose: String = """
            The Benefits Breakdown Structure plans a project or investment backwards from the \
            strategic outcomes you want. Starting with Investment Objectives (the why), it traces \
            forward to Benefits (the value delivered), then to Business Changes (what the \
            organisation must do differently), and finally to Enabling Deliverables (what the \
            project builds). This chain makes every deliverable traceable to a benefit and every \
            benefit traceable to a strategic objective — exposing deliverables that don't connect \
            to real value.
            """

        public static let whenToUse: [String] = [
            "Justifying a project investment by making the path from deliverables to strategic outcomes explicit.",
            "Prioritising deliverables: those that don't connect to a benefit can be cut or deferred.",
            "Portfolio management: ensuring each initiative traces to an organisational objective.",
            "Post-project benefit reviews: checking whether promised benefits actually materialised.",
            "Stakeholder alignment: showing executives and delivery teams how their work connects to strategy.",
        ]

        public static let history: String = """
            The Benefits Breakdown Structure is based on Gerald Bradley's Benefits Dependency \
            Network, introduced in his book "Benefit Realisation Management" (2006, 2nd ed. 2010). \
            It was adopted and popularised by the UK government's Managing Successful Programmes \
            (MSP) framework. The underlying idea — that projects should be justified by the \
            benefits they enable, not the outputs they produce — connects to the broader benefits \
            management movement in programme and portfolio management.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Benefit Realisation Management — Gerald Bradley",
                url: "https://www.goodreads.com/book/show/6778892-benefit-realisation-management"
            )
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let ioFill = SemanticColor(id: "bbs.io.fill", lightHex: "#e8f0ff")
        public static let ioBorder = SemanticColor(id: "bbs.io.border", lightHex: "#2858d0")
        public static let ioText = SemanticColor(id: "bbs.io.text", lightHex: "#0a2878")
        public static let benFill = SemanticColor(id: "bbs.benefit.fill", lightHex: "#ebfdf2")
        public static let benBorder = SemanticColor(id: "bbs.benefit.border", lightHex: "#209858")
        public static let benText = SemanticColor(id: "bbs.benefit.text", lightHex: "#0a5028")
        public static let bcFill = SemanticColor(id: "bbs.businessCase.fill", lightHex: "#fff4e5")
        public static let bcBorder = SemanticColor(id: "bbs.businessCase.border", lightHex: "#c87820")
        public static let bcText = SemanticColor(id: "bbs.businessCase.text", lightHex: "#6a3c08")
        public static let enFill = SemanticColor(id: "bbs.enabler.fill", lightHex: "#f0ebff")
        public static let enBorder = SemanticColor(id: "bbs.enabler.border", lightHex: "#7038d0")
        public static let enText = SemanticColor(id: "bbs.enabler.text", lightHex: "#3a1878")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.investmentObjective, Self.benefit, Self.businessChange, Self.enabler]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        investmentObjective,
                        description: "The strategic intent of the initiative, linked to the organisation's strategy — the 'why' of the investment."),
                    NodeTypeDefinition(
                        benefit,
                        description:
                            "An advantage gained by a stakeholder. Benefits are realised through changed business processes, not directly by the project."
                    ),
                    NodeTypeDefinition(
                        businessChange,
                        description:
                            "A changed process that creates the expected benefit each time it is executed. The mechanism through which benefits are delivered."
                    ),
                    NodeTypeDefinition(
                        enabler,
                        description: "A one-off project deliverable that enables the business process to change. The tangible output of the project."),
                ]
            }

            private static let investmentObjectiveId = "InvestmentObjective"
            private static let benefitId = "Benefit"
            private static let businessChangeId = "BusinessChange"
            private static let enablerId = "Enabler"

            public static let investmentObjective: NodeType = NodeType(string: investmentObjectiveId)
            public static let benefit: NodeType = NodeType(string: benefitId)
            public static let businessChange: NodeType = NodeType(string: businessChangeId)
            public static let enabler: NodeType = NodeType(string: enablerId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.investmentObjectiveToBenefit,
                    Self.benefitToBusinessChange,
                    Self.businessChangeToEnabler,
                    Self.investmentObjectiveToInvestmentObjective,
                    Self.benefitToBenefit,
                    Self.businessChangeToBusinessChange,
                    Self.enablerToEnabler,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        investmentObjectiveToBenefit,
                        description: "A Benefit is necessary for achieving the Investment Objective."),
                    EdgeTypeDefinition(
                        benefitToBusinessChange,
                        description: "A Business Change enables the realisation of a Benefit."),
                    EdgeTypeDefinition(
                        businessChangeToEnabler,
                        description: "An Enabler is a prerequisite for implementing the Business Change."),
                    EdgeTypeDefinition(
                        investmentObjectiveToInvestmentObjective,
                        description: "One Investment Objective supports another."),
                    EdgeTypeDefinition(
                        benefitToBenefit,
                        description: "One Benefit depends on another Benefit."),
                    EdgeTypeDefinition(
                        businessChangeToBusinessChange,
                        description: "One Business Change is a prerequisite for another."),
                    EdgeTypeDefinition(
                        enablerToEnabler,
                        description: "One Enabler is a prerequisite for another."),
                ]
            }

            // Cross-type edges (hierarchy) - Enabler -> BusinessChange -> Benefit -> InvestmentObjective
            public static let investmentObjectiveToBenefit: EdgeType = EdgeType(
                id: "requires_benefit",
                from: Notations.Bbs.NodeTypes.benefit,
                to: Notations.Bbs.NodeTypes.investmentObjective)

            public static let benefitToBusinessChange: EdgeType = EdgeType(
                id: "requires_business_change",
                from: Notations.Bbs.NodeTypes.businessChange,
                to: Notations.Bbs.NodeTypes.benefit)

            public static let businessChangeToEnabler: EdgeType = EdgeType(
                id: "requires_enabler",
                from: Notations.Bbs.NodeTypes.enabler,
                to: Notations.Bbs.NodeTypes.businessChange)

            public static let investmentObjectiveToInvestmentObjective: EdgeType = EdgeType(
                id: "objective_requires_objective",
                from: Notations.Bbs.NodeTypes.investmentObjective,
                to: Notations.Bbs.NodeTypes.investmentObjective)

            public static let benefitToBenefit: EdgeType = EdgeType(
                id: "benefit_requires_benefit",
                from: Notations.Bbs.NodeTypes.benefit,
                to: Notations.Bbs.NodeTypes.benefit)

            public static let businessChangeToBusinessChange: EdgeType = EdgeType(
                id: "change_requires_change",
                from: Notations.Bbs.NodeTypes.businessChange,
                to: Notations.Bbs.NodeTypes.businessChange)

            public static let enablerToEnabler: EdgeType = EdgeType(
                id: "enabler_requires_enabler",
                from: Notations.Bbs.NodeTypes.enabler,
                to: Notations.Bbs.NodeTypes.enabler)
        }

        /// For BBS, the layout direction is set to left-to-right to better visualize the flow from
        /// Investment Objectives → Benefits → Business Changes → Enablers.
        public static var values: [TypeValues] {
            [
                .badge(NodeTypes.investmentObjective, "IO", icon: "investment-objective", fill: ioFill, border: ioBorder, text: ioText),
                .badge(NodeTypes.benefit, "Benefit", icon: "benefit", fill: benFill, border: benBorder, text: benText),
                .badge(NodeTypes.businessChange, "Business Change", icon: "business-change", fill: bcFill, border: bcBorder, text: bcText),
                .badge(NodeTypes.enabler, "Enabler", icon: "enabler", fill: enFill, border: enBorder, text: enText),
                .diagram([Attributes.Group.layoutDirection(.leftToRight)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }

    }

}
