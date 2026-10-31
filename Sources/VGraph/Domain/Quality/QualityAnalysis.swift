/// Analyses are pure functions: same graph → same result.
public typealias GraphAnalysis<Result> = (VGraph) -> Result

public typealias QualityCheck = GraphAnalysis<[MessageWithSeverity]>

public enum GenericQualityChecks {

    /// Check for nodes using the unknown node type (the parser fell back to __UNKNOWN_NODE_TYPE__).
    public static func unknownNodeTypes(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        for node in graph.nodes {
            guard let nodeType = try? graph.nodeType(for: node) else { continue }
            if nodeType == NodeType.unknown {
                let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
                messages.append(
                    MessageWithSeverity(
                        message: "Node \"\(label)\" uses an unknown node type for this notation",
                        severity: .error,
                        target: .node(node.description)
                    ))
            }
        }
        return messages
    }

    /// Check for edges using unknown edge types (the parser fell back to __UNKNOWN_EDGE_TYPE__).
    public static func unknownEdgeTypes(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        for edge in graph.edges {
            guard let edgeType = try? graph.edgeType(for: edge.id) else { continue }
            if edgeType.isUnknown {
                let fromLabel = (try? graph.get(node: edge.from, attribute: Attributes.Node.label)) ?? edge.from.description
                let toLabel = (try? graph.get(node: edge.to, attribute: Attributes.Node.label)) ?? edge.to.description
                messages.append(
                    MessageWithSeverity(
                        message: "Edge from \"\(fromLabel)\" to \"\(toLabel)\" uses an invalid edge type for this notation",
                        severity: .error,
                        target: .edge(from: edge.from.description, to: edge.to.description)
                    ))
            }
        }
        return messages
    }

    /// Check for groups using the unknown group type (the parser fell back to
    /// __UNKNOWN_GROUP_TYPE__). Targets `.graph` because a quality message can only
    /// point at a node or an edge; the highlighter colours the offending word in
    /// the source instead.
    public static func unknownGroupTypes(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        for group in graph.groups where graph.groupType(of: group)?.description == GroupType.unknownPrefix {
            let name = label(of: group, in: graph)
            messages.append(
                MessageWithSeverity(
                    message: "Group \"\(name)\" uses an unknown group type for this notation",
                    severity: .error,
                    target: .graph
                ))
        }
        return messages
    }

    public static func disconnectedNodes(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        let connectedNodes = Set(graph.edges.flatMap { [$0.from, $0.to] })
        for node in graph.nodes where !connectedNodes.contains(node) {
            let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
            messages.append(
                MessageWithSeverity(
                    message: "Node \"\(label)\" is disconnected (no edges)",
                    severity: .warning,
                    target: .node(node.description)
                ))
        }
        return messages
    }

    /// Warn when a notation uses a junctor that is already implicit under its diagram logic.
    /// Sufficient-cause logic: multiple unjoined causes are implicitly OR — `OrJunctor` is redundant.
    /// Necessary-condition logic: multiple unjoined inputs are implicitly AND — `AndJunctor` is redundant.
    public static func redundantJunctor(graph: VGraph) -> [MessageWithSeverity] {
        guard let logicString: String = try? graph.get(graphAttribute: Attributes.Group.diagramLogic),
            let logic = try? DiagramLogic.fromString(logicString)
        else { return [] }

        // Notations spell junctor node-type IDs differently (e.g. CRT uses "OrJunctor",
        // PrerequisiteTree uses "OR"). Match both spellings for each connective.
        let redundantTypeIds: Set<String>
        let implicitConnective: String
        switch logic {
        case .noLogic:
            return []
        case .sufficientCause:
            redundantTypeIds = ["OrJunctor", "OR"]
            implicitConnective = "OR"
        case .necessaryCondition:
            redundantTypeIds = ["AndJunctor", "AND"]
            implicitConnective = "AND"
        }

        var messages: [MessageWithSeverity] = []
        for node in graph.nodes {
            guard let nodeType = try? graph.nodeType(for: node),
                redundantTypeIds.contains(nodeType.id.description)
            else { continue }
            let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? node.description
            messages.append(
                MessageWithSeverity(
                    message:
                        "Node \"\(label)\" is a \(nodeType.id.description), but \(logic.readableName) logic already treats multiple unjoined inputs as implicit \(implicitConnective). Replace the junctor with direct edges.",
                    severity: .warning,
                    target: .node(node.description)
                ))
        }
        return messages
    }

    /// The diagram draws a missing-icon placeholder rather than failing (ADR-0022), so this
    /// is the only thing that says *which* name — a warning, not an error,
    /// because the document is valid and whole. Targets `.graph` for the reason
    /// `unknownGroupTypes` does: the mistake is on a node *type*, and a quality
    /// message can only point at a node or an edge.
    public static func unresolvableIcons(graph: VGraph) -> [MessageWithSeverity] {
        var messages: [MessageWithSeverity] = []
        for nodeType in graph.usedNodeTypes {
            // `Attributes.Node.style` is assembled further down the pipeline than
            // the parsed graph the editor reports on. `iconInfo` is here already.
            guard let nodeStyle: NodeStyle = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle),
                nodeStyle.needsIcon,
                let iconInfo: IconInfo = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.iconInfo),
                !iconInfo.iconName.isEmpty,
                graph.artwork(forIcon: iconInfo.iconName) == nil
            else { continue }

            messages.append(
                MessageWithSeverity(
                    message: "Node type \"\(nodeType.description)\" uses an unknown icon \"\(iconInfo.iconName)\"",
                    severity: .warning,
                    target: .graph
                ))
        }
        return messages
    }

    public static var all: [QualityCheck] {
        [
            unknownNodeTypes, unknownEdgeTypes, unknownGroupTypes, unresolvableIcons,
            disconnectedNodes, redundantJunctor, brokenBounds, containment,
        ]
    }

    public static func analyze(_ graph: VGraph) -> [MessageWithSeverity] {
        all.flatMap { $0(graph) }
    }
}

extension GenericQualityChecks {

    static func label(of node: Node, in graph: VGraph) -> String {
        let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? ""
        return label.isEmpty ? node.id : label
    }

    static func label(of group: Group, in graph: VGraph) -> String {
        let label = graph.label(of: .group(group)) ?? ""
        return label.isEmpty ? group.id.id : label
    }
}
