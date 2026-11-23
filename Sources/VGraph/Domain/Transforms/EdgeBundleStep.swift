// Several edges running the same way between the same two things on screen are
// drawn as one [[Edge bundle]] (ADR-0027). That happens only where folding has
// collapsed their ends into one box, so the step runs straight after it and
// looks only at edges touching a folded group's stand-in.

extension TransformStep.Id {
    public static var bundleEdges: Self { "bundleEdges" }
}

extension Attributes.Edge {
    /// How a redirected edge read before folding, "From → To (type)" — its ends
    /// are gone from the view graph, and a bundle lists its members this way.
    public static let foldedDescription = TypedAttributeDefinition<String>(
        id: "edge.foldedDescription",
        name: "Folded Description",
        description: "A redirected edge's original ends and type. Runtime-only.",
        defaultValue: "",
        target: .edge
    )

    /// A bundle's member edge ids, which the view graph no longer holds.
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
    try parallelEdgesAtStandIns(in: graph).filter { $0.edges.count > 1 }.folding(graph) { (result, parallel) throws(VError) in
        // A derived edge says only that its ends are related, so one says it for all.
        guard !parallel.ends.derived else {
            return try parallel.edges.dropFirst().folding(result) { (graph, edge) throws(VError) in
                try graph.deleting(edge: edge.id)
            }
        }
        return try bundle(parallel.edges, in: result)
    }
}

/// Edges touching a folded group's stand-in, grouped by their ends, in the order
/// each group's first edge comes.
private func parallelEdgesAtStandIns(in graph: VGraph) -> [(ends: EndsKey, edges: [Edge])] {
    let touching = graph.edges.filter { graph.isFoldedStandIn($0.from) || graph.isFoldedStandIn($0.to) }
    let ends = touching.map { edge in
        EndsKey(from: edge.from.id, to: edge.to.id, derived: (try? graph.edgeType(for: edge))?.isDerived == true)
    }
    let edgesByEnds = Dictionary(zip(ends, touching.map { [$0] }), uniquingKeysWith: +)
    let firstOccurrences = ends.enumerated().filter { index, key in ends.firstIndex(of: key) == index }.map { $0.element }
    return firstOccurrences.map { (ends: $0, edges: edgesByEnds[$0] ?? []) }
}

private func bundle(_ bundled: [Edge], in graph: VGraph) throws(VError) -> VGraph {
    let first = bundled[0]
    let descriptions = bundled.map { edge in
        (try? graph.get(edge: edge.id, attribute: Attributes.Edge.foldedDescription)) ?? edge.id.id
    }
    let (typed, type) = try bundleType(for: bundled, in: graph)
    let withoutMembers = try bundled.folding(typed) { (result, edge) throws(VError) in try result.deleting(edge: edge.id) }
    let bundle = Edge(string: "bundle__\(first.from.id)__\(first.to.id)", from: first.from.id, to: first.to.id)
    return try withoutMembers.adding(edge: bundle, edgeType: type)
        .setting(edge: bundle.id, attribute: Attributes.Edge.label.attribute("×\(bundled.count)"))
        .setting(
            edge: bundle.id,
            attribute: Attributes.Edge.bundledEdges.attribute(bundled.map { $0.id.id }.joined(separator: String(idSeparator)))
        )
        .setting(edge: bundle.id, attribute: Attributes.Edge.bundleMembers.attribute(descriptions.joined(separator: "\n")))
}

/// The members' own type when they share one. Otherwise no member's look can
/// speak for the rest, so the bundle gets a neutral type of its own.
private func bundleType(for bundled: [Edge], in graph: VGraph) throws(VError) -> (VGraph, EdgeType) {
    let types = try bundled.map { (edge: Edge) throws(VError) in try graph.edgeType(for: edge.id) }
    if types.allSatisfy({ $0.id == types[0].id }) { return (graph, types[0]) }
    let fromType = try graph.nodeType(for: bundled[0].from)
    let toType = try graph.nodeType(for: bundled[0].to)
    let neutral = EdgeType(id: "bundle__\(fromType.id)__\(toType.id)", from: fromType, to: toType)
    guard graph.get(edgeType: neutral.id) == nil else { return (graph, neutral) }
    return (try graph.adding(edgeType: neutral), neutral)
}

extension VGraph {
    /// Empty for anything but a bundle.
    public func bundledEdgeIds(of edge: Edge.Id) -> [Edge.Id] {
        let raw: String = (try? get(edge: edge, attribute: Attributes.Edge.bundledEdges)) ?? ""
        return raw.split(separator: idSeparator).map { Edge.Id(rawValue: String($0)) }
    }

    /// Each bundled edge id to the bundle drawing it.
    var bundleOfMember: [Edge.Id: Edge] {
        Dictionary(
            edges.flatMap { bundle in bundledEdgeIds(of: bundle.id).map { ($0, bundle) } },
            uniquingKeysWith: { _, last in last })
    }
}
