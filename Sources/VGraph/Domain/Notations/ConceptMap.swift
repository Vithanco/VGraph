extension Notations {

    public struct ConceptMap: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }

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

            public static let concept: NodeType = NodeType(string: conceptId)
            public static let emphasizedConcept: NodeType = NodeType(string: emphasizedConceptId)
            public static let relation: NodeType = NodeType(string: relationId)
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
                .edgeType(EdgeTypes.conceptToRelation, fromConcept),
                .edgeType(EdgeTypes.relationToConcept, toConcept),
                .edgeType(EdgeTypes.emphasizedConceptToRelation, fromConcept),
                .edgeType(EdgeTypes.relationToEmphasizedConcept, toConcept),
                // Top-to-bottom layout works well for concept maps
                .diagram([Attributes.Group.layoutDirection(.topToBottom)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }

        public static var step: TransformStep? { mergeStep }

        // MARK: - Quality Checks

        public static var qualityChecks: [QualityCheck] {
            [
                conceptRelationRatio,
                conceptCountCheck,
                labelLengthCheck,
                vagueRelationsCheck,
                relationTopologyChecks,
            ]
        }

        static func conceptRelationRatio(_ graph: VGraph) -> [MessageWithSeverity] {
            var conceptCount = 0
            var relationCount = 0
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node) else { continue }
                if nt == NodeTypes.concept || nt == NodeTypes.emphasizedConcept {
                    conceptCount += 1
                } else if nt == NodeTypes.relation {
                    relationCount += 1
                }
            }
            guard conceptCount > 0 else { return [] }
            let ratio = Double(relationCount) / Double(conceptCount)
            // Format ratio to 2 decimal places without Foundation
            let hundredths = Int((ratio * 100).rounded())
            let whole = hundredths / 100
            let frac = hundredths % 100
            let ratioStr = "\(whole).\(frac < 10 ? "0" : "")\(frac)"
            return [
                MessageWithSeverity(
                    message: "Concepts: \(conceptCount), Relations: \(relationCount), Ratio: \(ratioStr)",
                    severity: .info
                )
            ]
        }

        static func conceptCountCheck(_ graph: VGraph) -> [MessageWithSeverity] {
            var conceptCount = 0
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node) else { continue }
                if nt == NodeTypes.concept || nt == NodeTypes.emphasizedConcept {
                    conceptCount += 1
                }
            }
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

        static func labelLengthCheck(_ graph: VGraph) -> [MessageWithSeverity] {
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node) else { continue }
                guard nt == NodeTypes.concept || nt == NodeTypes.emphasizedConcept else { continue }
                guard let label = try? graph.get(node: node, attribute: Attributes.Node.label) else { continue }
                let wordCount = label.split(separator: " ").count
                if wordCount >= 4 {
                    messages.append(
                        MessageWithSeverity(
                            message: "Concept \"\(label)\" has \(wordCount) words (prefer 1-3 words)",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }

        /// Blocklist of vague relation labels that produce unfalsifiable propositions.
        private static let vagueRelationLabels: Set<String> = [
            "relates to", "is related to", "is connected to",
            "involves", "is involved in", "is associated with",
            "is linked to", "pertains to", "concerns",
            "has something to do with", "is about",
        ]

        static func vagueRelationsCheck(_ graph: VGraph) -> [MessageWithSeverity] {
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.relation else { continue }
                guard let label = try? graph.get(node: node, attribute: Attributes.Node.label) else { continue }
                let normalized = label.lowercased()
                if vagueRelationLabels.contains(normalized) {
                    messages.append(
                        MessageWithSeverity(
                            message: "Relation \"\(label)\" is too vague — use a specific verb that forms a falsifiable proposition",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }

        // MARK: - Topology-Dependent Checks (Composite)

        static func relationTopologyChecks(_ graph: VGraph) -> [MessageWithSeverity] {
            let topology = GraphTopology(edges: graph.edges)
            var messages: [MessageWithSeverity] = []
            messages.append(contentsOf: unconnectedConcepts(graph, topology: topology))
            messages.append(contentsOf: orphanClusters(graph, topology: topology))
            messages.append(contentsOf: redundantPropositions(graph, topology: topology))
            messages.append(contentsOf: unreusedRelations(graph, topology: topology))
            messages.append(contentsOf: mappedRelations(graph, topology: topology))
            messages.append(contentsOf: incompleteRelations(graph, topology: topology))
            return messages
        }

        static func unconnectedConcepts(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node) else { continue }
                guard nt == NodeTypes.concept || nt == NodeTypes.emphasizedConcept else { continue }
                if !topology.connectedNodes.contains(node) {
                    let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                    messages.append(
                        MessageWithSeverity(
                            message: "Concept \"\(label)\" is not connected to any relation",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
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

        /// in opposite directions that express the same fact (e.g. "A causes B" + "B is caused by A").
        static func redundantPropositions(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            struct Proposition: Hashable {
                let from: Node  // source concept
                let to: Node  // target concept
            }

            var propositionsByPair: [Proposition: [String]] = [:]  // pair → relation labels

            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.relation else { continue }
                let sources = topology.incomingSources[node] ?? []
                let targets = topology.outgoingTargets[node] ?? []
                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                for source in sources {
                    for target in targets {
                        let prop = Proposition(from: source, to: target)
                        propositionsByPair[prop, default: []].append(label)
                    }
                }
            }

            var messages: [MessageWithSeverity] = []
            var reported: Set<Set<Node>> = []
            for (prop, forwardLabels) in propositionsByPair {
                let reverseProp = Proposition(from: prop.to, to: prop.from)
                guard let reverseLabels = propositionsByPair[reverseProp] else { continue }
                let pairKey: Set<Node> = [prop.from, prop.to]
                guard !reported.contains(pairKey) else { continue }
                reported.insert(pairKey)

                let fromLabel = (try? graph.get(node: prop.from, attribute: Attributes.Node.label)) ?? prop.from.description
                let toLabel = (try? graph.get(node: prop.to, attribute: Attributes.Node.label)) ?? prop.to.description
                messages.append(
                    MessageWithSeverity(
                        message:
                            "\"\(fromLabel)\" and \"\(toLabel)\" are linked in both directions (\(forwardLabels.joined(separator: ", ")) / \(reverseLabels.joined(separator: ", "))) — keep only the more meaningful direction",
                        severity: .warning
                    ))
            }
            return messages
        }

        /// If two Relation nodes have the same label and same outgoing targets, they can be merged.
        static func unreusedRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            var relationsByLabel: [String: [Node]] = [:]
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.relation else { continue }
                guard let label = try? graph.get(node: node, attribute: Attributes.Node.label) else { continue }
                relationsByLabel[label, default: []].append(node)
            }

            var messages: [MessageWithSeverity] = []
            for (label, nodes) in relationsByLabel where nodes.count > 1 {
                let outgoingSets = nodes.map { topology.outgoingTargets[$0] ?? [] }
                if Set(outgoingSets).count == 1 {
                    messages.append(
                        MessageWithSeverity(
                            message:
                                "Relations with label \"\(label)\" appear \(nodes.count) times with same targets -- consider reusing a single relation node",
                            severity: .warning
                        ))
                }
            }
            return messages
        }

        /// This creates n * m propositions that all must be valid.
        /// Flags circular propositions (same concept on both sides) as errors.
        static func mappedRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            var messages: [MessageWithSeverity] = []

            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.relation else { continue }

                let sources = topology.incomingSources[node] ?? []
                let targets = topology.outgoingTargets[node] ?? []

                guard sources.count >= 2, targets.count >= 2 else { continue }

                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                let overlap = sources.intersection(targets)

                if !overlap.isEmpty {
                    let overlapLabels = overlap.compactMap { n -> String? in
                        (try? graph.get(node: n, attribute: Attributes.Node.label)) ?? n.description
                    }.sorted()
                    messages.append(
                        MessageWithSeverity(
                            message:
                                "Relation \"\(label)\" has \(sources.count) inbound and \(targets.count) outbound concepts with circular propositions: \(overlapLabels.joined(separator: ", ")) appear(s) on both sides",
                            severity: .error,
                            target: .node(node.description)
                        ))
                } else {
                    messages.append(
                        MessageWithSeverity(
                            message:
                                "Relation \"\(label)\" has \(sources.count) inbound and \(targets.count) outbound concepts, creating \(sources.count * targets.count) propositions -- verify all are valid",
                            severity: .warning,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }
        /// A complete proposition requires at least one source concept and one target concept.
        static func incompleteRelations(_ graph: VGraph, topology: GraphTopology) -> [MessageWithSeverity] {
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes {
                guard let nt = try? graph.nodeType(for: node), nt == NodeTypes.relation else { continue }
                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                let hasIncoming = !(topology.incomingSources[node] ?? []).isEmpty
                let hasOutgoing = !(topology.outgoingTargets[node] ?? []).isEmpty
                if !hasIncoming && !hasOutgoing {
                    messages.append(
                        MessageWithSeverity(
                            message: "Relation \"\(label)\" has no incoming or outgoing concepts — it forms no proposition",
                            severity: .error,
                            target: .node(node.description)
                        ))
                } else if !hasIncoming {
                    messages.append(
                        MessageWithSeverity(
                            message: "Relation \"\(label)\" has no incoming concept — proposition has no source",
                            severity: .error,
                            target: .node(node.description)
                        ))
                } else if !hasOutgoing {
                    messages.append(
                        MessageWithSeverity(
                            message: "Relation \"\(label)\" has no outgoing concept — proposition has no target",
                            severity: .error,
                            target: .node(node.description)
                        ))
                }
            }
            return messages
        }
    }

}
