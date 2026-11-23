/// Analyses are pure functions: same graph → same result.
public typealias GraphAnalysis<Result> = (VGraph) -> Result

public typealias QualityCheck = GraphAnalysis<[MessageWithSeverity]>

public enum GenericQualityChecks {

    /// Check for nodes using the unknown node type (the parser fell back to __UNKNOWN_NODE_TYPE__).
    public static func unknownNodeTypes(graph: VGraph) -> [MessageWithSeverity] {
        graph.nodes(ofType: NodeType.unknown).map { node in
            MessageWithSeverity(
                message: "Node \"\(graph.name(of: node))\" uses an unknown node type for this notation",
                severity: .error,
                target: .node(node.description)
            )
        }
    }

    /// Check for edges using unknown edge types (the parser fell back to __UNKNOWN_EDGE_TYPE__).
    public static func unknownEdgeTypes(graph: VGraph) -> [MessageWithSeverity] {
        graph.edges.filter { (try? graph.edgeType(for: $0.id))?.isUnknown == true }.map { edge in
            MessageWithSeverity(
                message:
                    "Edge from \"\(graph.name(of: edge.from))\" to \"\(graph.name(of: edge.to))\" uses an invalid edge type for this notation",
                severity: .error,
                target: .edge(from: edge.from.description, to: edge.to.description)
            )
        }
    }

    /// Check for groups using the unknown group type (the parser fell back to
    /// __UNKNOWN_GROUP_TYPE__). Targets `.graph` because a quality message can only
    /// point at a node or an edge; the highlighter colours the offending word in
    /// the source instead.
    public static func unknownGroupTypes(graph: VGraph) -> [MessageWithSeverity] {
        graph.groups.filter { graph.groupType(of: $0)?.isUnknown == true }.map { group in
            MessageWithSeverity(
                message: "Group \"\(graph.name(of: group))\" uses an unknown group type for this notation",
                severity: .error,
                target: .graph
            )
        }
    }

    public static func disconnectedNodes(graph: VGraph) -> [MessageWithSeverity] {
        let connectedNodes = Set(graph.edges.flatMap { [$0.from, $0.to] })
        return graph.nodes.filter { !connectedNodes.contains($0) }.map { node in
            MessageWithSeverity(
                message:
                    "Node \"\(graph.name(of: node))\" has no relationships — every node should collaborate with at least one other",
                severity: .warning,
                target: .node(node.description)
            )
        }
    }

    /// Warn when a notation uses a junctor that is already implicit under its diagram logic.
    /// Sufficient-cause logic: multiple unjoined causes are implicitly OR — `OrJunctor` is redundant.
    /// Necessary-condition logic: multiple unjoined inputs are implicitly AND — `AndJunctor` is redundant.
    public static func redundantJunctor(graph: VGraph) -> [MessageWithSeverity] {
        guard let logic = try? graph.get(attribute: Attributes.Group.diagramLogic) else { return [] }

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

        return graph.nodes.compactMap { node in
            guard let nodeType = try? graph.nodeType(for: node), redundantTypeIds.contains(nodeType.id.description)
            else { return nil }
            return MessageWithSeverity(
                message:
                    "Node \"\(graph.name(of: node))\" is a \(nodeType.id.description), but \(logic.readableName) logic already treats multiple unjoined inputs as implicit \(implicitConnective). Replace the junctor with direct edges.",
                severity: .warning,
                target: .node(node.description)
            )
        }
    }

    /// The diagram draws a missing-icon placeholder rather than failing (ADR-0022), so this
    /// is the only thing that says *which* name — a warning, not an error,
    /// because the document is valid and whole. Targets `.graph` for the reason
    /// `unknownGroupTypes` does: the mistake is on a node *type*, and a quality
    /// message can only point at a node or an edge.
    public static func unresolvableIcons(graph: VGraph) -> [MessageWithSeverity] {
        graph.usedNodeTypes.compactMap { nodeType in
            // `Attributes.Node.style` is assembled further down the pipeline than
            // the parsed graph the editor reports on. `iconInfo` is here already.
            guard let nodeStyle: NodeStyle = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle),
                nodeStyle.needsIcon,
                let iconInfo: IconInfo = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.iconInfo),
                !iconInfo.iconName.isEmpty,
                graph.artwork(forIcon: iconInfo.iconName) == nil
            else { return nil }
            return MessageWithSeverity(
                message: "Node type \"\(nodeType.description)\" uses an unknown icon \"\(iconInfo.iconName)\"",
                severity: .warning,
                target: .graph
            )
        }
    }

    /// A value that does not parse as its attribute's type is drawn as if unset,
    /// so a typo in VGL would otherwise go unnoticed. A warning, not a parse
    /// error: the document is still whole and keeps what the author wrote.
    public static func badlyTypedValues(graph: VGraph) -> [MessageWithSeverity] {
        let layers =
            [(AttributeLayer.vnotation, ""), (.model, "")]
            + graph.views.map { (VGraph.layer(ofView: $0.name), " in view \"\($0.name)\"") }
        return layers.flatMap { layer, inView in
            ((try? graph.attributeStore.attributes(in: layer)) ?? [])
                .filter { !$0.attribute.definition.accepts($0.attribute.stringValue) }
                .map { key, attribute in
                    let (owner, target) = graph.owner(of: key)
                    return MessageWithSeverity(
                        message:
                            "\(owner) has \(attribute.definition.vglKey) \"\(attribute.stringValue)\"\(inView), which is not a valid \(attribute.type)",
                        severity: .warning, target: target)
                }
        }
    }

    public static var all: [QualityCheck] {
        [
            badlyTypedValues,
            unknownNodeTypes, unknownEdgeTypes, unknownGroupTypes, unresolvableIcons,
            disconnectedNodes, redundantJunctor, brokenBounds, containment,
        ]
    }

    public static func analyze(_ graph: VGraph) -> [MessageWithSeverity] {
        all.flatMap { $0(graph) }
    }
}

extension VGraph {
    /// How a quality message names a store key, and where it points.
    fileprivate func owner(of key: ItemKey) -> (name: String, target: QualityTarget) {
        switch key.kind {
        case .node:
            let node = Node(rawValue: key.id)
            return ("Node \"\(name(of: node))\"", .node(node.description))
        case .edge:
            guard let edge = edges.first(where: { ItemKey($0.id) == key }) else { return ("Edge \"\(key.id)\"", .graph) }
            return ("Edge \"\(name(of: edge))\"", .edge(from: edge.from.description, to: edge.to.description))
        case .group: return ("Group \"\(name(of: Group(rawValue: key.id)))\"", .graph)
        case .root: return ("The diagram", .graph)
        case .nodeType: return ("Node type \"\(key.id)\"", .graph)
        case .edgeType: return ("Edge type \"\(key.id)\"", .graph)
        case .groupType: return ("Group type \"\(key.id)\"", .graph)
        }
    }
}
