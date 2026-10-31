extension Notations {

    /// The C4 model (Simon Brown): software-architecture diagrams at four levels of
    /// zoom — System Context, Container, Component and Code. Each level details the one
    /// above (ADR-0032): an unfolded system is a boundary around its containers, a
    /// folded one is its card.
    public struct C4: NotationDeclaration {
        public static let id: Identifier<Notation> = .init(rawValue: "C4")

        public static let description =
            "Software-architecture diagrams (Simon Brown's C4 model): people, software systems, "
            + "containers and components inside nested boundaries, across four levels of zoom."

        public static let purpose: String = """
            The C4 model describes a software system's architecture as a hierarchy of four \
            diagrams — System Context, Container, Component and Code — so each audience sees \
            the right level of detail. Elements are people, software systems, containers \
            (apps/datastores) and components; relationships show how they collaborate; \
            boundaries group the elements that belong to a system or container.
            """

        public static let whenToUse: [String] = [
            "Explaining a system's place in its environment (people and neighbouring systems).",
            "Showing the containers (apps, services, datastores) that make up a system.",
            "Zooming into a container to show its components and their responsibilities.",
            "Onboarding: a map that stays legible from boardroom to code.",
        ]

        public static let history: String = """
            Simon Brown created the C4 model in the 2010s as a lightweight, notation-independent \
            way to describe software architecture, distilling ideas from UML and Philippe \
            Kruchten's "4+1" views into four simple levels.
            """

        public static let references: [NotationReference] = [
            NotationReference(title: "The C4 model for visualising software architecture", url: "https://c4model.com"),
            NotationReference(title: "Simon Brown — C4 model", url: "https://en.wikipedia.org/wiki/C4_model"),
        ]

        // MARK: - Colour palette (Structurizr-style hues; dark variants auto-derived)
        public static let personFill = SemanticColor(id: "c4.person.fill", lightHex: "#08427b")
        public static let systemFill = SemanticColor(id: "c4.system.fill", lightHex: "#1168bd")
        public static let containerFill = SemanticColor(id: "c4.container.fill", lightHex: "#438dd5")
        public static let componentFill = SemanticColor(id: "c4.component.fill", lightHex: "#85bbf0")
        public static let codeFill = SemanticColor(id: "c4.code.fill", lightHex: "#cfd8e6")
        public static let organisationFill = SemanticColor(id: "c4.organisation.fill", lightHex: "#999999")
        public static let onDark = SemanticColor(id: "c4.text.onDark", lightHex: "#ffffff")
        public static let onLight = SemanticColor(id: "c4.text.onLight", lightHex: "#111111")
        // Boundary chrome: a muted dashed outline with a transparent fill (Structurizr look),
        // distinct from the generic cluster's fill + border.
        public static let boundaryBorder = SemanticColor(id: "c4.boundary.border", lightHex: "#7a7a7a", darkHex: "#8f8f8f")
        public static let boundaryFill = SemanticColor(id: "c4.boundary.fill", lightHex: "#00000000", darkHex: "#00000000")

        /// A plain group: the people and systems one organisation owns, such as "Big Bank".
        public static let organisation = GroupType(string: "Organisation")

        public struct GroupTypes: NotationGroupTypes {
            public static var all: [GroupType] { [organisation] }

            public static var allDefinitions: [GroupTypeDefinition] {
                [
                    GroupTypeDefinition(
                        organisation,
                        description: "An organisation's own edge, around the people and software systems it owns.")
                ]
            }
        }

        public struct NodeTypes: NotationNodeTypes {
            public static let person = NodeType(string: "Person")
            public static let softwareSystem = NodeType(string: "SoftwareSystem")
            public static let container = NodeType(string: "Container")
            public static let component = NodeType(string: "Component")
            public static let codeElement = NodeType(string: "CodeElement")
            public static let database = NodeType(string: "Database")

            public static var all: [NodeType] {
                [person, softwareSystem, container, component, codeElement, database]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                [
                    NodeTypeDefinition(person, description: "A person who uses the software: a user, actor, role or persona."),
                    NodeTypeDefinition(
                        softwareSystem, description: "Something that delivers value to its users, owned by one team.",
                        detailedBy: [container, database]),
                    NodeTypeDefinition(
                        container, description: "A separately deployable or runnable unit: an application or a service.",
                        detailedBy: [component]),
                    NodeTypeDefinition(
                        component, description: "A grouping of related functionality behind a well-defined interface.",
                        detailedBy: [codeElement]),
                    NodeTypeDefinition(codeElement, description: "A class, interface, function or table that implements a component."),
                    NodeTypeDefinition(database, description: "A container that stores data: a database, schema or file store."),
                ]
            }
        }

        /// Only same-level relationships are declared; detailing gains the pairs with
        /// a detail at one end (ADR-0032), so a Person who uses a system may use its
        /// containers and components without a type of its own.
        public struct EdgeTypes: NotationEdgeTypes {
            public static let interactsWith = EdgeType(
                id: "interacts_with", from: NodeTypes.person, to: NodeTypes.person)
            public static let uses = EdgeType(
                id: "uses", from: NodeTypes.person, to: NodeTypes.softwareSystem)
            public static let deliversTo = EdgeType(
                id: "delivers_to", from: NodeTypes.softwareSystem, to: NodeTypes.person)
            public static let dependsOn = EdgeType(
                id: "depends_on", from: NodeTypes.softwareSystem, to: NodeTypes.softwareSystem)
            public static let communicatesWith = EdgeType(
                id: "communicates_with", from: NodeTypes.container, to: NodeTypes.container)
            public static let readsAndWrites = EdgeType(
                id: "reads_and_writes", from: NodeTypes.container, to: NodeTypes.database)
            public static let calls = EdgeType(
                id: "calls", from: NodeTypes.component, to: NodeTypes.component)
            public static let references = EdgeType(
                id: "references", from: NodeTypes.codeElement, to: NodeTypes.codeElement)

            public static var all: [EdgeType] {
                [interactsWith, uses, deliversTo, dependsOn, communicatesWith, readsAndWrites, calls, references]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                [
                    EdgeTypeDefinition(interactsWith, description: "One person works with another, e.g. asks Support Staff for help."),
                    EdgeTypeDefinition(
                        uses, description: "A person uses a software system, or one of its containers or components."),
                    EdgeTypeDefinition(
                        deliversTo,
                        description: "A software system, or one of its parts, delivers something to a person, e.g. sends e-mails."),
                    EdgeTypeDefinition(
                        dependsOn,
                        description: "A software system, or one of its parts, depends on another software system or its parts."),
                    EdgeTypeDefinition(
                        communicatesWith,
                        description: "One container calls or sends data to another, or to one of its components."),
                    EdgeTypeDefinition(
                        readsAndWrites, description: "A container, or one of its components, reads from or writes to a database."),
                    EdgeTypeDefinition(calls, description: "One component calls another, or code calls a component."),
                    EdgeTypeDefinition(references, description: "One code element references another."),
                ]
            }
        }

        public static var values: [TypeValues] {
            [
                card(NodeTypes.person, "Person", fill: personFill, textColor: onDark, shape: .person),
                card(NodeTypes.softwareSystem, "Software System", fill: systemFill, textColor: onDark),
                card(NodeTypes.container, "Container", fill: containerFill, textColor: onDark),
                card(NodeTypes.component, "Component", fill: componentFill, textColor: onLight),
                card(NodeTypes.codeElement, "Code", fill: codeFill, textColor: onLight),
                card(NodeTypes.database, "Container: Database", fill: containerFill, textColor: onDark, shape: .cylinder),
                .groupType(
                    organisation,
                    [
                        Attributes.Group.groupStyle(
                            GroupStyle(
                                folded: .c4Element(stereotype: "Organisation", fill: organisationFill, textColor: onDark),
                                unfolded: boundaryChrome))
                    ]),
                .nodeType(NodeTypes.softwareSystem, [Attributes.Group.boundaryChrome(boundaryChrome)]),
                .nodeType(NodeTypes.container, [Attributes.Group.boundaryChrome(boundaryChrome)]),
                .nodeType(NodeTypes.component, [Attributes.Group.boundaryChrome(boundaryChrome)]),
            ]
        }

        private static func card(
            _ nodeType: NodeType, _ stereotype: String, fill: SemanticColor, textColor: SemanticColor,
            shape: NodeShape = .box
        ) -> TypeValues {
            .preset(nodeType, .c4Element(stereotype: stereotype, fill: fill, textColor: textColor, shape: shape))
        }

        // MARK: - Quality Checks

        /// Nesting is the engine's containment check, which every notation gets.
        public static var qualityChecks: [QualityCheck] {
            [orphanElement, unlabelledRelationship]
        }

        static func orphanElement(_ graph: VGraph) -> [MessageWithSeverity] {
            let topology = GraphTopology(edges: graph.edges)
            var messages: [MessageWithSeverity] = []
            for node in graph.nodes where !topology.connectedNodes.contains(node) {
                messages.append(
                    MessageWithSeverity(
                        message:
                            "Element \"\(label(of: node, in: graph))\" has no relationships — every element should collaborate with at least one other",
                        severity: .warning,
                        target: .node(node.description)))
            }
            return messages
        }

        /// c4model.com's checklist: every arrow has a label stating its purpose.
        /// Code-level `references` are UML arrows (inheritance, realization), which
        /// the arrowhead already says.
        static func unlabelledRelationship(_ graph: VGraph) -> [MessageWithSeverity] {
            graph.edges.compactMap { edge in
                guard (try? graph.edgeType(for: edge.id)) != EdgeTypes.references else { return nil }
                let label = (try? graph.get(edge: edge.id, attribute: Attributes.Edge.label)) ?? ""
                guard label.isEmpty else { return nil }
                return MessageWithSeverity(
                    message:
                        "Relationship from \"\(Self.label(of: edge.from, in: graph))\" to \"\(Self.label(of: edge.to, in: graph))\" has no label — say what it is for",
                    severity: .warning,
                    target: .edge(from: edge.from.description, to: edge.to.description))
            }
        }

        static func label(of node: Node, in graph: VGraph) -> String {
            let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? ""
            return label.isEmpty ? node.description : label
        }

        private static let boundaryChrome = BoundaryChrome(
            cornerRadius: 8, borderDash: "8,4", borderColor: boundaryBorder, fill: boundaryFill)
    }
}
