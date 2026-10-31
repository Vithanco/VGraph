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
    static func rules(graph: VGraph) -> String {
        guard !graph.edges.isEmpty else { return "" }

        let topology = GraphTopology(edges: graph.edges)

        let junctors = Set(
            graph.nodes.filter { node in
                guard let nt = try? graph.nodeType(for: node) else { return false }
                return (try? graph.get(nodeType: nt, attribute: Attributes.Node.isJunctor)) ?? false
            })

        var rules = ""
        for node in graph.nodes {
            let hood = transparentNeighbourhood(of: node, topology: topology, junctors: junctors)
            if hood.edges.isEmpty && hood.nodes.isEmpty { continue }
            let scope = "svg:has(#\(SVGBuilder.cssEscapeIdent(SVGElementId.displayNode(node, in: graph))):hover) "
            rules += SVGBuilder.neighborGlowRule(
                scope: scope, edgeIds: hood.edges, nodeElementIds: hood.nodes.map { SVGElementId.displayNode($0, in: graph) })
        }

        for edge in graph.edges {
            let scope = "svg:has(#\(SVGBuilder.cssEscapeIdent(SVGElementId.edge(edge.id.id))):hover) "
            var edges: [String] = []
            var nodes: [Node] = []
            for endpoint in [edge.from, edge.to] {
                nodes.append(endpoint)
                if junctors.contains(endpoint) {
                    let hood = transparentNeighbourhood(of: endpoint, topology: topology, junctors: junctors)
                    edges.append(contentsOf: hood.edges)
                    nodes.append(contentsOf: hood.nodes)
                }
            }
            rules += SVGBuilder.neighborGlowRule(
                scope: scope, edgeIds: edges, nodeElementIds: nodes.map { SVGElementId.displayNode($0, in: graph) })
        }

        return rules
    }

    /// Junctors are structural pass-throughs, so hovering one end of a chain has
    /// to keep walking through them to reach the real neighbours on the far side.
    private static func transparentNeighbourhood(
        of start: Node, topology: GraphTopology, junctors: Set<Node>
    ) -> (edges: [String], nodes: [Node]) {
        var edgeOut: [String] = []
        var edgeSeen = Set<Edge.Id>()
        var nodeOut: [Node] = []
        var nodeSeen = Set<Node>()
        var frontier: [Node] = [start]
        var expanded = Set<Node>([start])

        while let cur = frontier.popLast() {
            for edge in topology.incidentEdges(of: cur) {
                let other = edge.from == cur ? edge.to : edge.from
                if !edgeSeen.contains(edge.id) {
                    edgeSeen.insert(edge.id)
                    edgeOut.append(edge.id.id)
                }
                if junctors.contains(other) {
                    if !nodeSeen.contains(other) {
                        nodeSeen.insert(other)
                        nodeOut.append(other)
                    }
                    if !expanded.contains(other) {
                        expanded.insert(other)
                        frontier.append(other)
                    }
                } else if other != start && !nodeSeen.contains(other) {
                    nodeSeen.insert(other)
                    nodeOut.append(other)
                }
            }
        }
        return (edgeOut, nodeOut)
    }
}
