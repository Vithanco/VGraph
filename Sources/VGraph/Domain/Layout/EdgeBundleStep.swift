// Several edges running the same way between the same two things on screen are
// drawn as one [[Edge bundle]] (ADR-0027). That happens only where folding has
// collapsed their ends into one box, so the step runs straight after it and
// looks only at edges touching a folded group's stand-in.

extension TransformStep.Id {
    public static var bundleEdges: Self { "bundleEdges" }
}

extension Attributes.Edge {
    /// How a redirected edge read before folding, "From → To (type)" — its ends
    /// are gone from the display graph, and a bundle lists its members this way.
    public static let foldedDescription = TypedAttributeDefinition<String>(
        id: "edge.foldedDescription",
        name: "Folded Description",
        description: "A redirected edge's original ends and type. Runtime-only.",
        defaultValue: "",
        target: .edge
    )

    /// A bundle's member edge ids, which the display graph no longer holds.
    public static let bundledEdges = TypedAttributeDefinition<String>(
        id: "edge.bundledEdges",
        name: "Bundled Edges",
        description: "The ids of the edges a bundle draws. Runtime-only.",
        defaultValue: "",
        target: .edge
    )

    /// A bundle's members, one per line, for its tooltip.
    public static let bundleMembers = TypedAttributeDefinition<String>(
        id: "edge.bundleMembers",
        name: "Bundle Members",
        description: "The folded descriptions of a bundle's members. Runtime-only.",
        defaultValue: "",
        target: .edge
    )
}

extension Notations.FoldGroups {
    public static var bundleStep: TransformStep {
        TransformStep(.bundleEdges, requires: [.foldGroups]) { (graph: VGraph) throws(VError) in
            try applyEdgeBundling(to: graph)
        }
    }
}

// A control character: it cannot occur in a VGL id.
private let idSeparator: Character = "\u{1F}"

private struct EndsKey: Hashable {
    let from: String
    let to: String
    let derived: Bool
}

public func applyEdgeBundling(to graph: VGraph) throws(VError) -> VGraph {
    var order: [EndsKey] = []
    var members: [EndsKey: [Edge]] = [:]
    for edge in graph.edges where graph.isFoldedStandIn(edge.from) || graph.isFoldedStandIn(edge.to) {
        let derived = (try? graph.edgeType(for: edge))?.isDerived == true
        let key = EndsKey(from: edge.from.id, to: edge.to.id, derived: derived)
        if members[key] == nil { order.append(key) }
        members[key, default: []].append(edge)
    }

    var result = graph
    for key in order {
        guard let grouped = members[key], grouped.count > 1 else { continue }
        if key.derived {
            for edge in grouped.dropFirst() { result = try result.delete(edge: edge.id) }
        } else {
            result = try bundle(grouped, in: result)
        }
    }
    return result
}

private func bundle(_ bundled: [Edge], in graph: VGraph) throws(VError) -> VGraph {
    let first = bundled[0]
    var result = graph

    let types = try bundled.map { (edge: Edge) throws(VError) in try graph.edgeType(for: edge.id) }
    let type: EdgeType
    if types.allSatisfy({ $0.id == types[0].id }) {
        type = types[0]
    } else {
        // No member's look can speak for the rest, so the bundle gets none.
        let fromType = try graph.nodeType(for: first.from)
        let toType = try graph.nodeType(for: first.to)
        let neutral = EdgeType(id: "bundle__\(fromType.id)__\(toType.id)", from: fromType, to: toType)
        if result.get(edgeType: neutral.id) == nil { result = try result.add(edgeType: neutral) }
        type = neutral
    }

    let descriptions = bundled.map { edge in
        (try? graph.get(edge: edge.id, attribute: Attributes.Edge.foldedDescription)) ?? edge.id.id
    }
    for edge in bundled { result = try result.delete(edge: edge.id) }

    let bundle = Edge(string: "bundle__\(first.from.id)__\(first.to.id)", from: first.from.id, to: first.to.id)
    result = try result.add(edge: bundle, edgeType: type)
    result = try result.set(edge: bundle.id, attribute: Attributes.Edge.label.attribute("×\(bundled.count)"))
    result = try result.set(
        edge: bundle.id,
        attribute: Attributes.Edge.bundledEdges.attribute(
            bundled.map { $0.id.id }.joined(separator: String(idSeparator))))
    return try result.set(
        edge: bundle.id, attribute: Attributes.Edge.bundleMembers.attribute(descriptions.joined(separator: "\n")))
}

extension VGraph {
    /// Empty for anything but a bundle.
    public func bundledEdgeIds(of edge: Edge.Id) -> [Edge.Id] {
        let raw: String = (try? get(edge: edge, attribute: Attributes.Edge.bundledEdges)) ?? ""
        return raw.split(separator: idSeparator).map { Edge.Id(string: String($0)) }
    }

    /// Each bundled edge id to the bundle drawing it.
    var bundleOfMember: [Edge.Id: Edge] {
        var result: [Edge.Id: Edge] = [:]
        for edge in edges {
            for member in bundledEdgeIds(of: edge.id) { result[member] = edge }
        }
        return result
    }
}
