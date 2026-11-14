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

        var adds: [Node: AddsToNeighborhood] = [:]
        for node in graph.nodes {
            guard let type = try? graph.nodeType(for: node),
                let value = try? graph.get(nodeType: type, attribute: Attributes.Node.addsToNeighborhood),
                value != .none
            else { continue }
            adds[node] = value
        }

        var rules = ""
        for node in graph.nodes {
            var walk = NeighbourhoodWalk(topology: topology, adds: adds, hovering: node)
            walk.cross(topology.incidentEdges(of: node), leaving: node)
            walk.drain()
            if walk.edges.isEmpty && walk.nodes.isEmpty { continue }
            let scope = "svg:has(#\(SVGBuilder.cssEscapeIdent(SVGElementId.displayNode(node, in: graph))):hover) "
            rules += SVGBuilder.neighborGlowRule(
                scope: scope, edgeIds: walk.edges, nodeElementIds: walk.nodes.map { SVGElementId.displayNode($0, in: graph) })
        }

        for edge in graph.edges {
            var walk = NeighbourhoodWalk(topology: topology, adds: adds, hovering: nil)
            walk.reach(edge.from, heading: .against)
            walk.drain()
            walk.reach(edge.to, heading: .along)
            walk.drain()
            let scope = "svg:has(#\(SVGBuilder.cssEscapeIdent(SVGElementId.edge(edge.id.id))):hover) "
            rules += SVGBuilder.neighborGlowRule(
                scope: scope, edgeIds: walk.edges, nodeElementIds: walk.nodes.map { SVGElementId.displayNode($0, in: graph) })
        }

        return rules
    }
}

/// What a hover lights: the hovered element's edges and their far ends, carried
/// on past every node whose type adds to the [[Neighbourhood]] (ADR-0037).
private struct NeighbourhoodWalk {

    /// Which way the walk crossed the edge that reached a node, which is the way
    /// an `onward` node passes it on.
    enum Heading { case along, against }

    /// A node passes the walk on once per way it can: `all` once, `onward` once
    /// per heading, since each heading reaches different ends.
    private struct Pass: Hashable {
        let node: Node
        let heading: Heading?
    }

    let topology: GraphTopology
    let adds: [Node: AddsToNeighborhood]
    private(set) var edges: [String] = []
    private(set) var nodes: [Node] = []
    private var edgeSeen = Set<Edge.Id>()
    private var nodeSeen = Set<Node>()
    private var passed = Set<Pass>()
    private var pending: [(node: Node, heading: Heading)] = []

    /// The hovered node is lit by its own `:hover` rule, so it is never listed,
    /// and its edges are all crossed already, so it never passes the walk on.
    init(topology: GraphTopology, adds: [Node: AddsToNeighborhood], hovering hovered: Node?) {
        self.topology = topology
        self.adds = adds
        if let hovered {
            nodeSeen.insert(hovered)
            passed = [Pass(node: hovered, heading: nil), Pass(node: hovered, heading: .along), Pass(node: hovered, heading: .against)]
        }
    }

    mutating func reach(_ node: Node, heading: Heading) {
        if nodeSeen.insert(node).inserted { nodes.append(node) }
        pending.append((node: node, heading: heading))
    }

    mutating func cross(_ some: [Edge], leaving node: Node) {
        for edge in some {
            if edgeSeen.insert(edge.id).inserted { edges.append(edge.id.id) }
            if edge.from == node {
                reach(edge.to, heading: .along)
            } else {
                reach(edge.from, heading: .against)
            }
        }
    }

    mutating func drain() {
        while let next = pending.popLast() {
            let node = next.node
            guard let way = adds[node] else { continue }
            switch way {
            case .none:
                continue
            case .all:
                guard passed.insert(Pass(node: node, heading: nil)).inserted else { continue }
                cross(topology.incidentEdges(of: node), leaving: node)
            case .onward:
                guard passed.insert(Pass(node: node, heading: next.heading)).inserted else { continue }
                let onward = topology.incidentEdges(of: node).filter { edge in
                    next.heading == .along ? edge.from == node : edge.to == node
                }
                cross(onward, leaving: node)
            }
        }
    }
}
