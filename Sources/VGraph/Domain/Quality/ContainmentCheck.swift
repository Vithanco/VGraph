extension GenericQualityChecks {

    /// ADR-0032's one rule for placement, as a warning: ⌥ lets anything go, and
    /// this is what then says so.
    public static func containment(graph: VGraph) -> [MessageWithSeverity] {
        members(of: graph).compactMap { containmentFinding(for: $0, in: graph) }
    }

    /// A plain node or a detailed node: either can stand inside a detailed node.
    private struct Member {
        let id: String
        let type: NodeType
        let label: String
        let enclosing: Group?
    }

    private static func members(of graph: VGraph) -> [Member] {
        let nodes = graph.nodes.compactMap { node -> Member? in
            // `unknownNodeTypes` already reports it; where it stands is moot.
            guard let type = try? graph.nodeType(for: node), type != NodeType.unknown else { return nil }
            return Member(
                id: node.description, type: type, label: graph.name(of: node),
                enclosing: graph.group(of: node))
        }
        let detailedNodes = graph.groups.compactMap { group -> Member? in
            guard let type = graph.nodeType(of: group) else { return nil }
            return Member(
                id: group.id.id, type: type, label: graph.name(of: group),
                enclosing: graph.parentGroup(of: group))
        }
        return nodes + detailedNodes
    }

    private static func containmentFinding(for member: Member, in graph: VGraph) -> MessageWithSeverity? {
        guard !graph.allows(member.type, in: member.enclosing) else { return nil }
        let name = "\(member.type.description) \"\(member.label)\""
        guard let holder = graph.detailedNode(holding: member.enclosing), let holderType = graph.nodeType(of: holder) else {
            return warning(
                "\(name) is at the top level, but a \(member.type.description) belongs inside a "
                    + listed(graph.typesDetailed(by: member.type).map { $0.description }, joinedBy: "or"),
                about: member)
        }
        let allowed = graph.detailTypes(of: holderType)
        let details = allowed.isEmpty ? "which has no details" : "which is detailed by \(listed(allowed.map { $0.description }, joinedBy: "and"))"
        return warning(
            "\(name) is inside \(holderType.description) \"\(graph.name(of: holder))\", \(details)",
            about: member)
    }

    /// The rule as it holds in one notation: where each of its detail types belongs.
    public static func containmentRules(in graph: VGraph) -> [String] {
        graph.nodeTypes.compactMap { detailType in
            let holders = graph.typesDetailed(by: detailType)
            guard !holders.isEmpty else { return nil }
            return "\(withArticle(inWords(detailType.description), capitalised: true)) belongs inside "
                + "\(withArticle(listed(holders.map { inWords($0.description) }, joinedBy: "or")))."
        }
    }

    private static func warning(_ message: String, about member: Member) -> MessageWithSeverity {
        MessageWithSeverity(message: message, severity: .warning, target: .node(member.id))
    }
}
