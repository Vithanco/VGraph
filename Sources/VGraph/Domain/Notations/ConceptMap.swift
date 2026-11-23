extension Notations {

    public struct ConceptMap: NotationDeclaration {

        public static var namedQualityChecks: [QualityCheckSpec] { [.noParallelEdges] }

        public static let id: Identifier<Notation> = .init(rawValue: "ConceptMap")
        public static let description =
            "Defines and connects concepts using labelled relations, forming falsifiable propositions that align vocabulary and reveal knowledge structure."

        // MARK: - Self-description

        public static let purpose: String = """
            Concept Maps define a domain's vocabulary by placing key terms (Concepts) in \
            relation to each other through labelled linking phrases (Relations). Each \
            Concept–Relation–Concept triple forms a falsifiable proposition — a sentence \
            you can verify or dispute — which makes misalignments in team vocabulary \
            visible and addressable. This makes them superior to a traditional glossary, \
            where long lists of definitions are rarely read critically.
            """

        public static let whenToUse: [String] = [
            "Defining the vocabulary of a new project or domain so all stakeholders share the same meaning for key terms.",
            "Onboarding new team members: walk through each proposition together and surface any disagreements.",
            "Detecting conceptual misalignment early: a disputed proposition reveals a hidden assumption before it causes problems.",
            "Structuring your own understanding of an unfamiliar field before writing, presenting, or designing.",
            "Answering a focused question by mapping out all concepts that are relevant to the answer.",
        ]

        public static let history: String = """
            Concept Maps were developed by Joseph D. Novak at Cornell University in the 1970s, \
            originally as a tool to track children's evolving understanding of science concepts. \
            Novak grounded the method in David Ausubel's assimilation theory of cognitive learning. \
            The technique has since spread into fields ranging from education and knowledge \
            management to systems engineering and knowledge representation.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "The theory underlying concept maps and how to construct and use them (Novak & Cañas)",
                url: "https://www.academia.edu/688215/The_theory_underlying_concept_maps_and_how_to_construct_and_use_them"
            ),
            NotationReference(
                title: "Concept map (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Concept_map"
            ),
        ]

        // Color palette — from Vithanco Diagram Style Guide
        public static let conceptFill = SemanticColor(id: "conceptmap.concept.fill", lightHex: "#e8f5f3")
        public static let conceptBorder = SemanticColor(id: "conceptmap.concept.border", lightHex: "#1a9488")
        public static let conceptText = SemanticColor(id: "conceptmap.concept.text", lightHex: "#0a5048")
        // EmphasizedConcept uses a warmer teal to stand out
        public static let emphFill = SemanticColor(id: "conceptmap.emphasis.fill", lightHex: "#fdeef1")
        public static let emphBorder = SemanticColor(id: "conceptmap.emphasis.border", lightHex: "#c84060")
        public static let emphText = SemanticColor(id: "conceptmap.emphasis.text", lightHex: "#8a1830")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.concept, Self.emphasizedConcept, Self.relation]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        concept,
                        description:
                            "A noun or term placed in relation to others. Concepts are connected through Relations to form falsifiable propositions."),
                    NodeTypeDefinition(
                        emphasizedConcept,
                        description: "A highlighted concept to draw attention to key terms. Use sparingly for maximum impact."),
                    NodeTypeDefinition(
                        relation,
                        description:
                            "A verb or linking phrase connecting two concepts. Together with source and target, forms a falsifiable proposition."),
                ]
            }

            private static let conceptId = "Concept"
            private static let emphasizedConceptId = "EmphasizedConcept"
            private static let relationId = "Relation"

            public static let concept: NodeType = NodeType(rawValue: conceptId)
            public static let emphasizedConcept: NodeType = NodeType(rawValue: emphasizedConceptId)
            public static let relation: NodeType = NodeType(rawValue: relationId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.conceptToRelation,
                    Self.relationToConcept,
                    Self.emphasizedConceptToRelation,
                    Self.relationToEmphasizedConcept,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        conceptToRelation,
                        description: "A Concept connects to a Relation, forming the source of a proposition."),
                    EdgeTypeDefinition(
                        relationToConcept,
                        description: "A Relation points to a Concept, completing the proposition."),
                    EdgeTypeDefinition(
                        emphasizedConceptToRelation,
                        description: "An Emphasized Concept connects to a Relation, forming the source of a proposition."),
                    EdgeTypeDefinition(
                        relationToEmphasizedConcept,
                        description: "A Relation points to an Emphasized Concept, completing the proposition."),
                ]
            }

            // From Concept to Relation: tail only (concept side has the connection point)
            public static let conceptToRelation: EdgeType = EdgeType(
                id: "concept_to_relation",
                from: Notations.ConceptMap.NodeTypes.concept,
                to: Notations.ConceptMap.NodeTypes.relation)

            // From Relation to Concept: head only (concept side has the arrow)
            public static let relationToConcept: EdgeType = EdgeType(
                id: "relation_to_concept",
                from: Notations.ConceptMap.NodeTypes.relation,
                to: Notations.ConceptMap.NodeTypes.concept)

            // From EmphasizedConcept to Relation: tail only
            public static let emphasizedConceptToRelation: EdgeType = EdgeType(
                id: "emphasized_concept_to_relation",
                from: Notations.ConceptMap.NodeTypes.emphasizedConcept,
                to: Notations.ConceptMap.NodeTypes.relation)

            // From Relation to EmphasizedConcept: head only
            public static let relationToEmphasizedConcept: EdgeType = EdgeType(
                id: "relation_to_emphasized_concept",
                from: Notations.ConceptMap.NodeTypes.relation,
                to: Notations.ConceptMap.NodeTypes.emphasizedConcept)
        }

        public static var values: [TypeValues] {
            let fromConcept = [Attributes.Edge.dir("back"), Attributes.Edge.arrowHead("none"), Attributes.Edge.arrowTail("dot")]
            let toConcept = [Attributes.Edge.dir("forward"), Attributes.Edge.arrowHead("normal"), Attributes.Edge.arrowTail("none")]
            return [
                .badge(NodeTypes.concept, "Concept", icon: "concept", fill: conceptFill, border: conceptBorder, text: conceptText),
                .preset(NodeTypes.emphasizedConcept, .contentNode(fill: emphFill, border: emphBorder, textColor: emphText)),
                // Relation: ghost pill — subtle tinted capsule, visually subordinate
                .preset(NodeTypes.relation, .ghostPill, fontsize: 11),
                // Each subject–object pair is its own proposition (ADR-0037).
                .nodeType(NodeTypes.relation, [Attributes.Node.addsToNeighborhood(.onward)]),
                .edgeType(EdgeTypes.conceptToRelation, fromConcept),
                .edgeType(EdgeTypes.relationToConcept, toConcept),
                .edgeType(EdgeTypes.emphasizedConceptToRelation, fromConcept),
                .edgeType(EdgeTypes.relationToEmphasizedConcept, toConcept),
                // Top-to-bottom layout works well for concept maps
                .diagram([Attributes.Group.layoutDirection(.topToBottom)]),
            ]
        }

        public static var step: TransformStep? { mergeStep }

        // MARK: - Quality Checks

        /// Relations are verb phrases and may run longer; the word limit is for concepts.
        static var labelLengthCheck: QualityCheck { QualityCheckRegistry.labelLengthCheck(maxWords: 3, among: concepts(in:)) }

        public static var qualityChecks: [QualityCheck] {
            [
                conceptRelationRatio,
                conceptCountCheck,
                labelLengthCheck,
                vagueRelationsCheck,
                relationTopologyChecks,
            ]
        }

        /// Concept and Emphasized Concept: both are what a proposition is about.
        private static func concepts(in graph: VGraph) -> [Node] {
            graph.nodes.filter { node in
                (try? graph.nodeType(for: node)).map { $0 == NodeTypes.concept || $0 == NodeTypes.emphasizedConcept }
                    ?? false
            }
        }

        static func conceptRelationRatio(_ graph: VGraph) -> [MessageWithSeverity] {
            let conceptCount = concepts(in: graph).count
            let relationCount = graph.nodes(ofType: NodeTypes.relation).count
            guard conceptCount > 0 else { return [] }
            return [
                MessageWithSeverity(
                    message:
                        "Concepts: \(conceptCount), Relations: \(relationCount), Ratio: \(twoDecimals(Double(relationCount) / Double(conceptCount)))",
                    severity: .info
                )
            ]

            /// Without Foundation's formatter, and always two digits after the point.
            func twoDecimals(_ ratio: Double) -> String {
                let hundredths = Int((ratio * 100).rounded())
                let fraction = hundredths % 100
                return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction)"
            }
        }

        static func conceptCountCheck(_ graph: VGraph) -> [MessageWithSeverity] {
            let conceptCount = concepts(in: graph).count
            if conceptCount > 0, conceptCount < 5 {
                return [
                    MessageWithSeverity(
                        message: "Only \(conceptCount) concepts — consider adding more to fully explore the guiding question",
                        severity: .warning
                    )
                ]
            }
            if conceptCount > 25 {
                return [
                    MessageWithSeverity(
                        message: "\(conceptCount) concepts — consider splitting into sub-maps for readability",
                        severity: .warning
                    )
                ]
            }
            return []
        }

        /// Blocklist of vague relation labels that produce unfalsifiable propositions.
        private static let vagueRelationLabels: Set<String> = [
            "relates to", "is related to", "is connected to",
            "involves", "is involved in", "is associated with",
            "is linked to", "pertains to", "concerns",
            "has something to do with", "is about",
        ]

        static func vagueRelationsCheck(_ graph: VGraph) -> [MessageWithSeverity] {
            graph.nodes(ofType: NodeTypes.relation).compactMap { node in
                guard let label = try? graph.get(node: node, attribute: Attributes.Node.label),
                    vagueRelationLabels.contains(label.lowercased())
                else { return nil }
                return MessageWithSeverity(
                    message: "Relation \"\(label)\" is too vague — use a specific verb that forms a falsifiable proposition",
                    severity: .warning,
                    target: .node(node.description)
                )
            }
        }

        // MARK: - Topology-Dependent Checks (Composite)

        static func relationTopologyChecks(_ graph: VGraph) -> [MessageWithSeverity] {
            let topology = GraphTopology(edges: graph.edges)
            return unconnectedConcepts(graph, topology: topology)
                + orphanClusters(graph, topology: topology)
                + redundantPropositions(graph, topology: topology)
                + unreusedRelations(graph, topology: topology)
                + mappedRelations(graph, topology: topology)
                + incompleteRelations(graph, topology: topology)
        }

        static func unconnectedConcepts(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            concepts(in: graph).filter { !topology.connectedNodes.contains($0) }.map { node in
                MessageWithSeverity(
                    message: "Concept \"\(graph.name(of: node))\" is not connected to any relation",
                    severity: .warning,
                    target: .node(node.description)
                )
            }
        }

        /// Ignores singleton components (already caught by unconnectedConcepts/disconnectedNodes).
        static func orphanClusters(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            let components = topology.connectedComponents(nodes: graph.nodes)
            let nonTrivial = components.filter { $0.count > 1 }
            guard nonTrivial.count > 1 else { return [] }
            return [
                MessageWithSeverity(
                    message: "Map has \(nonTrivial.count) disconnected clusters — consider connecting them or splitting into separate maps",
                    severity: .warning
                )
            ]
        }

        /// Two relations in opposite directions that express the same fact (e.g. "A causes B" +
        /// "B is caused by A").
        static func redundantPropositions(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            struct Proposition: Hashable {
                let from: Node
                let to: Node

                var reversed: Proposition { Proposition(from: to, to: from) }
            }

            // Relations in document order, their ends by id: each pair is named the way it was first drawn, every run.
            let stated = graph.nodes(ofType: NodeTypes.relation).flatMap { relation in
                let label = graph.name(of: relation)
                return (topology.incomingSources[relation] ?? []).sorted().flatMap { source in
                    (topology.outgoingTargets[relation] ?? []).sorted().map { target in
                        (proposition: Proposition(from: source, to: target), label: label)
                    }
                }
            }
            let labelsByProposition = Dictionary(stated.map { ($0.proposition, [$0.label]) }, uniquingKeysWith: +)

            var reported: Set<Set<Node>> = []
            return stated.compactMap { statement in
                let proposition = statement.proposition
                guard let forwardLabels = labelsByProposition[proposition],
                    let reverseLabels = labelsByProposition[proposition.reversed],
                    reported.insert([proposition.from, proposition.to]).inserted
                else { return nil }
                return MessageWithSeverity(
                    message:
                        "\"\(graph.name(of: proposition.from))\" and \"\(graph.name(of: proposition.to))\" are linked in both directions (\(forwardLabels.joined(separator: ", ")) / \(reverseLabels.joined(separator: ", "))) — keep only the more meaningful direction",
                    severity: .warning)
            }
        }

        /// If two Relation nodes have the same label and same outgoing targets, they can be merged.
        static func unreusedRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            let relationsByLabel = Dictionary(
                graph.nodes(ofType: NodeTypes.relation).compactMap { relation in
                    (try? graph.get(node: relation, attribute: Attributes.Node.label)).map { ($0, [relation]) }
                },
                uniquingKeysWith: +)

            return relationsByLabel.sorted { $0.key < $1.key }.compactMap { label, relations in
                guard relations.count > 1, Set(relations.map { topology.outgoingTargets[$0] ?? [] }).count == 1
                else { return nil }
                return MessageWithSeverity(
                    message:
                        "Relations with label \"\(label)\" appear \(relations.count) times with same targets -- consider reusing a single relation node",
                    severity: .warning
                )
            }
        }

        /// A relation with several concepts on each side makes n * m propositions that all
        /// must be valid. Flags circular propositions (same concept on both sides) as errors.
        static func mappedRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            graph.nodes(ofType: NodeTypes.relation).compactMap { relation in
                let sources = topology.incomingSources[relation] ?? []
                let targets = topology.outgoingTargets[relation] ?? []
                guard sources.count >= 2, targets.count >= 2 else { return nil }

                let label = graph.name(of: relation)
                let overlap = sources.intersection(targets)
                guard overlap.isEmpty else {
                    let overlapLabels = overlap.map { graph.name(of: $0) }.sorted()
                    return MessageWithSeverity(
                        message:
                            "Relation \"\(label)\" has \(sources.count) inbound and \(targets.count) outbound concepts with circular propositions: \(overlapLabels.joined(separator: ", ")) appear(s) on both sides",
                        severity: .error,
                        target: .node(relation.description)
                    )
                }
                return MessageWithSeverity(
                    message:
                        "Relation \"\(label)\" has \(sources.count) inbound and \(targets.count) outbound concepts, creating \(sources.count * targets.count) propositions -- verify all are valid",
                    severity: .warning,
                    target: .node(relation.description)
                )
            }
        }

        /// A complete proposition requires at least one source concept and one target concept.
        static func incompleteRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            return graph.nodes(ofType: NodeTypes.relation).compactMap { relation in
                guard let missing = missingEnd(of: relation) else { return nil }
                return MessageWithSeverity(
                    message: "Relation \"\(graph.name(of: relation))\" \(missing)",
                    severity: .error,
                    target: .node(relation.description)
                )
            }

            func missingEnd(of relation: Node) -> String? {
                let hasIncoming = !(topology.incomingSources[relation] ?? []).isEmpty
                let hasOutgoing = !(topology.outgoingTargets[relation] ?? []).isEmpty
                switch (hasIncoming, hasOutgoing) {
                case (false, false): return "has no incoming or outgoing concepts — it forms no proposition"
                case (false, true): return "has no incoming concept — proposition has no source"
                case (true, false): return "has no outgoing concept — proposition has no target"
                case (true, true): return nil
                }
            }
        }
    }

}
