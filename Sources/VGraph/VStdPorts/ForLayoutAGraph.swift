/// Outbound port for computing a graph's layout.
///
/// Deliberately stated at the graph level, not in terms of any one engine's
/// interchange format: an implementation receives a `VGraph` and returns the
/// same graph with layout attributes applied (`layoutedPos` on nodes,
/// `layoutedPath` on edges). How it gets there — DOT round-trip, native
/// solver, precomputed fixture — is the adapter's business.
public protocol VForLayoutAGraph {
    func layout(graph: VGraph) throws(VError) -> VGraph
}
