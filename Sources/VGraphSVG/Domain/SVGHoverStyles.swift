// `:has()` is used so a rule reaches related siblings regardless of document
// order (edges are emitted before nodes).

import VGraph

enum SVGHoverStyles {

    /// The [[Edge end]] handles: inert and invisible until their edge is
    /// hovered. One static rule rather than a per-graph one, because a handle is
    /// a *descendant* of its edge's `<g>` — which is also what makes it
    /// self-sustaining, hovering the handle keeping the edge hovered.
    ///
    /// Inert matters as much as invisible: Graphviz clips a spline to the node's
    /// rim, so a handle overlaps node pixels, and a drag from there is `connect`
    /// (ADR-0012). Gating `pointer-events` leaves the rim exactly as it was
    /// except while the pointer is already on that edge (ADR-0021).
    static let edgeEndRules = """
        .\(SVGElementId.edgeEndClass){opacity:0;pointer-events:none;}
        .\(SVGElementId.edgeClass):hover .\(SVGElementId.edgeEndClass)\
        {opacity:1;pointer-events:auto;cursor:grab;}
        """

    /// Bare rules; the caller wraps them in `<style>`. Empty when the graph has
    /// no edges, so a `<style>` block is never emitted for nothing.
    static func rules(graph: VGraph) throws(VError) -> String {
        guard !graph.edges.isEmpty else { return "" }

        let topology = GraphTopology(edges: graph.edges)
        let carriers = try Neighborhood.carriers(in: graph)
        func glow(_ hovered: String, _ lit: Neighborhood) -> String {
            SVGBuilder.neighborGlowRule(
                scope: "svg:has(#\(SVGBuilder.cssEscapeIdent(hovered)):hover) ",
                edgeIds: lit.edges.map { $0.id },
                nodeElementIds: lit.nodes.map { SVGElementId.displayNode($0, in: graph) })
        }

        var rules = ""
        for node in graph.nodes {
            let lit = Neighborhood(
                from: [.leaving(node, by: topology.incidentEdges(of: node))], topology: topology, carriers: carriers)
            if lit.edges.isEmpty && lit.nodes.isEmpty { continue }
            rules += glow(SVGElementId.displayNode(node, in: graph), lit)
        }
        for edge in graph.edges {
            let lit = Neighborhood(
                from: [.arriving(edge.from, .against), .arriving(edge.to, .along)], topology: topology, carriers: carriers)
            rules += glow(SVGElementId.edge(edge.id.id), lit)
        }
        return rules
    }
}
