extension Notations {

    public struct Timeline: NotationDeclaration {

        public static var criteria: [QualityCheckSpec] { [.noParallelEdges] }
        public static let id: Identifier<Notation> = .init(rawValue: "Timeline")
        public static let description =
            "Visualises events across parallel tracks aligned to a shared time axis, with optional influence connections between events."

        // MARK: - Self-description

        public static let purpose: String = """
            Timeline diagrams visualise how events across different domains or parallel tracks \
            relate to each other chronologically and causally. Unlike a list of dates, a Timeline \
            lets you place parallel tracks side by side — countries, teams, systems — so you can \
            see at a glance what happened simultaneously and what influenced what. The alignGroup \
            attribute is the key mechanism: nodes sharing the same alignGroup value are placed at \
            the same position, regardless of which track they belong to.
            """

        public static let whenToUse: [String] = [
            "Historical analysis across multiple countries, regions, or actors to show parallel developments.",
            "Project management with parallel workstreams: surfacing dependencies and milestones that coincide.",
            "Product roadmaps across multiple feature tracks or teams.",
            "Incident timelines showing events across different systems to reconstruct a sequence of failures.",
            "Any narrative where 'what happened at the same time' is as important as 'what happened next'.",
        ]

        public static let history: String = """
            Timelines as a visualisation form date back to Joseph Priestley's "Chart of Biography" \
            (1765), often cited as the first modern timeline. The multi-track parallel timeline was \
            popularised in the 20th century through project management (Gantt charts, 1910s) and \
            historical atlases. The VGraph Timeline notation extends the concept with the \
            alignGroup mechanism, allowing any node type — not just time points — to be pinned to \
            a shared temporal position.
            """

        public static let references: [NotationReference] = [
            NotationReference(
                title: "Timeline (Wikipedia)",
                url: "https://en.wikipedia.org/wiki/Timeline"
            )
        ]

        // Color palette — Vithanco Diagram Style Guide §10
        //
        // TimePoint visuals are owned by `TimelineOverlayProvider` (axis +
        // guides + year labels). The Event visuals stay here because events
        // render through the standard pipeline. `sequence` edges are dropped
        // by the overlay's filterEdges, but `influenceEdgeColor` is still used
        // by surviving influence edges.
        public static let evFill = SemanticColor(id: "timeline.event.fill", lightHex: "#e4eef8")
        public static let evBorder = SemanticColor(id: "timeline.event.border", lightHex: "#3868a8")
        public static let evText = SemanticColor(id: "timeline.event.text", lightHex: "#183058")
        public static let influenceEdgeColor = VColor(hexString: "#606058") ?? VColor.gray

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.timePoint, Self.event]
            }

            public static var allDefinitions: [NodeTypeDefinition] {
                return [
                    NodeTypeDefinition(
                        timePoint,
                        description:
                            "A marker on the time axis labelling a point in time (e.g., '1805', 'Q3 2025'). Defines the temporal structure of the diagram."
                    ),
                    NodeTypeDefinition(
                        event,
                        description: "A generic event placed at a point in time. Extend with vnotation for domain-specific event types."),
                ]
            }

            private static let timePointId = "TimePoint"
            private static let eventId = "Event"

            public static let timePoint: NodeType = NodeType(string: timePointId)
            public static let event: NodeType = NodeType(string: eventId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] {
                return [
                    Self.sequence,
                    Self.influence,
                ]
            }

            public static var allDefinitions: [EdgeTypeDefinition] {
                return [
                    EdgeTypeDefinition(
                        sequence,
                        description: "Links TimePoints in chronological order, creating the time axis. Rendered as a thin gray arrow."),
                    EdgeTypeDefinition(
                        influence,
                        description: "Shows a causal or dependency link between events. Dashed line that does not distort the layout alignment."),
                ]
            }

            // TimePoint to TimePoint: creates the time axis
            public static let sequence: EdgeType = EdgeType(
                id: "sequence",
                from: Notations.Timeline.NodeTypes.timePoint,
                to: Notations.Timeline.NodeTypes.timePoint)

            // Event to Event: cross-track or within-track influence
            public static let influence: EdgeType = EdgeType(
                id: "influence",
                from: Notations.Timeline.NodeTypes.event,
                to: Notations.Timeline.NodeTypes.event)
        }

        public static var values: [TypeValues] {
            [
                // TimelineOverlayProvider draws a TimePoint and filters it from the
                // standard render, so this layout never renders. It only sizes the
                // bbox Graphviz reserves: the label text, padded 40pt below for the
                // year label the overlay draws there, measured in the overlay's
                // own font (DM Sans 12).
                .preset(
                    NodeTypes.timePoint,
                    .padded(VEdgeInsets(top: 5, left: 4, bottom: 40, right: 4), .nodeText(color: SemanticColor.ink2)),
                    fontsize: 12),
                .badge(NodeTypes.event, "Event", icon: "event", fill: evFill, border: evBorder, text: evText),
                // Sequence edges need no styling: they order the TimePoints for
                // Graphviz, and the overlay's axis replaces them when drawn.
                .edgeType(
                    EdgeTypes.influence,
                    [
                        Attributes.Edge.style(.dashed),
                        Attributes.Edge.color(influenceEdgeColor),
                        Attributes.Edge.constraint(false),
                        Attributes.Edge.dir("forward"),
                        Attributes.Edge.arrowHead("normal"),
                    ]),
                // Left-to-right layout: time flows horizontally
                .diagram([Attributes.Group.layoutDirection(.leftToRight)]),
            ]
        }

        public func addGraphConfiguration(addTo graph: VGraph) throws(VError) -> VGraph {
            return graph
        }
    }

}
