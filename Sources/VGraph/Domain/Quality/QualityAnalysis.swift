/// Analyses are pure functions: same graph → same result.
public typealias GraphAnalysis<Result> = (VGraph) -> Result

/// A [[Quality check]]: the rule it states, and what it reports where a graph breaks it.
public struct QualityCheck {
    /// Stable, so a page can link to one rule and a test can find it.
    public let name: String
    /// One sentence of what good looks like; published as written.
    public let rule: String
    public let findings: GraphAnalysis<[MessageWithSeverity]>
    /// Set only when no small document can break the rule; a notation running the
    /// check then owes no [[Counterexample]].
    public let noCounterexampleBecause: String?

    public init(
        _ name: String, rule: String, noCounterexampleBecause: String? = nil,
        findings: @escaping GraphAnalysis<[MessageWithSeverity]>
    ) {
        self.name = name
        self.rule = rule
        self.noCounterexampleBecause = noCounterexampleBecause
        self.findings = findings
    }

    public func callAsFunction(_ graph: VGraph) -> [MessageWithSeverity] {
        findings(graph)
    }
}

/// "a Plus", "an Answer": rule sentences name types the way prose does.
func withArticle(_ noun: String, capitalised: Bool = false) -> String {
    let vowel = noun.first.map { "AEIOUaeiou".contains($0) } ?? false
    return (capitalised ? (vowel ? "An" : "A") : (vowel ? "an" : "a")) + " " + noun
}

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
                            "\(owner) has \(attribute.definition.camelCaseKey) \"\(attribute.stringValue)\"\(inView), which is not a valid \(attribute.type)",
                        severity: .warning, target: target)
                }
        }
    }

    /// The document still loads, with the current spelling's value; this says
    /// which value it overruled, since saving drops it for good.
    public static func keysGivenTwice(graph: VGraph) -> [MessageWithSeverity] {
        let viewOfLayer = Dictionary(
            graph.views.map { (VGraph.layer(ofView: $0.name), " in view \"\($0.name)\"") }, uniquingKeysWith: { first, _ in first })
        return graph.notationDefinition.keysGivenTwice.map { message(of: $0, in: graph) }
            + graph.standingAttributesGivenTwice.map { message(of: $0.keys, in: graph, view: viewOfLayer[$0.layer] ?? "") }
    }

    private static func message(of twice: KeyGivenTwice, in graph: VGraph, view: String = "") -> MessageWithSeverity {
        let (owner, target) = graph.owner(of: twice.owner)
        return MessageWithSeverity(
            message:
                "\(owner) gives \(twice.key) twice\(view), as "
                + "\(twice.dropped.spelling): \(twice.dropped.value) and \(twice.kept.spelling): \(twice.kept.value)"
                + " — using \(twice.kept.value)",
            severity: .warning, target: target)
    }

    /// Also offered by `QualityCheckRegistry` under these names, which it reads
    /// from here, so `runsAlways` cannot miss them after a rename.
    static var disconnectedNodesCheck: QualityCheck {
        QualityCheck("disconnectedNodes", rule: "Every node is connected to at least one other.", findings: disconnectedNodes)
    }
    static var redundantJunctorCheck: QualityCheck {
        QualityCheck(
            "redundantJunctor", rule: "No junctor states what the diagram's logic already implies.",
            findings: redundantJunctor)
    }

    /// Named so that a `qualityCheck:` naming one of them can be recognised and
    /// not run a second time.
    public static var all: [QualityCheck] {
        [
            QualityCheck("badlyTypedValues", rule: "Every value fits the type of its attribute.", findings: badlyTypedValues),
            QualityCheck("keysGivenTwice", rule: "No attribute is given twice for the same item.", findings: keysGivenTwice),
            QualityCheck("unknownNodeTypes", rule: "Every node has a node type of the notation.", findings: unknownNodeTypes),
            QualityCheck("unknownEdgeTypes", rule: "Every edge has an edge type of the notation.", findings: unknownEdgeTypes),
            QualityCheck(
                "unknownGroupTypes", rule: "Every typed group has a group type of the notation.", findings: unknownGroupTypes),
            QualityCheck("unresolvableIcons", rule: "Every icon a node type names exists.", findings: unresolvableIcons),
            disconnectedNodesCheck, redundantJunctorCheck,
            QualityCheck(
                "brokenBounds", rule: "Every node and edge stays within the bounds of its type.", findings: brokenBounds),
            QualityCheck("containment", rule: "A nested element sits inside a type that details it.", findings: containment),
        ]
    }

    public static func runsAlways(_ spec: QualityCheckSpec) -> Bool {
        all.contains { $0.name == spec.name }
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
