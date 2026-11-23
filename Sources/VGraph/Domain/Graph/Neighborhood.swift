/// A [[Neighbourhood]]: edges and their far ends, carried on past every node
/// whose type adds to it (ADR-0037). Hover draws it; a selector's reach adds it
/// (ADR-0038).
public struct Neighborhood {

    /// Which way the walk crossed the edge that reached a node, which is the way
    /// an `onward` node passes it on.
    public enum Heading: Hashable, Sendable {
        case along, against

        /// Whether `edge` takes the walk on from `node` in this heading.
        func continues(_ edge: Edge, from node: Node) -> Bool {
            self == .along ? edge.from == node : edge.to == node
        }
    }

    /// Where a walk begins. A node it leaves is a start: never listed, and it
    /// never passes the walk on, since its edges are named here.
    public enum Entry {
        case leaving(Node, by: [Edge])
        case arriving(Node, Heading)
    }

    /// Where the walk ended at a node that does not carry it, and which way it
    /// was going.
    struct Stop: Hashable {
        let node: Node
        let heading: Heading
    }

    public let edges: [Edge.Id]
    /// Every node reached, in the order reached, without the starts.
    public let nodes: [Node]
    let stops: Set<Stop>

    /// Entries are walked in order, each to its end before the next.
    public init(from entries: [Entry], topology: GraphTopology, carriers: [Node: AddsToNeighborhood]) {
        var walk = Walk(topology: topology, carriers: carriers)
        for case .leaving(let start, _) in entries { walk.begin(at: start) }
        for entry in entries {
            switch entry {
            case .leaving(let start, let by): walk.cross(by, leaving: start)
            case .arriving(let node, let heading): walk.reach(node, heading: heading)
            }
            walk.drain()
        }
        edges = walk.edges
        nodes = walk.nodes
        stops = walk.stops
    }

    /// The nodes in `graph` whose type carries the walk past them.
    public static func carriers(in graph: VGraph) throws(VError) -> [Node: AddsToNeighborhood] {
        let reach = try graph.nodes.map { (node) throws(VError) in
            (node: node, adds: try graph.get(nodeType: graph.nodeType(for: node), attribute: Attributes.Node.addsToNeighborhood))
        }
        let carrying = reach.filter { $0.adds != AddsToNeighborhood.none }
        return Dictionary(carrying.map { ($0.node, $0.adds) }, uniquingKeysWith: { _, last in last })
    }
}

private struct Walk {

    /// A node passes the walk on once per way it can: `all` once, `onward` once
    /// per heading, since each heading reaches different ends.
    private struct Pass: Hashable {
        let node: Node
        let heading: Neighborhood.Heading?
    }

    let topology: GraphTopology
    let carriers: [Node: AddsToNeighborhood]
    private(set) var edges: [Edge.Id] = []
    private(set) var nodes: [Node] = []
    private(set) var stops = Set<Neighborhood.Stop>()
    private var edgeSeen = Set<Edge.Id>()
    private var nodeSeen = Set<Node>()
    private var passed = Set<Pass>()
    private var pending: [(node: Node, heading: Neighborhood.Heading)] = []

    init(topology: GraphTopology, carriers: [Node: AddsToNeighborhood]) {
        self.topology = topology
        self.carriers = carriers
    }

    mutating func begin(at start: Node) {
        nodeSeen.insert(start)
        passed.formUnion([Pass(node: start, heading: nil), Pass(node: start, heading: .along), Pass(node: start, heading: .against)])
    }

    mutating func reach(_ node: Node, heading: Neighborhood.Heading) {
        if nodeSeen.insert(node).inserted { nodes.append(node) }
        if carriers[node] == nil { stops.insert(Neighborhood.Stop(node: node, heading: heading)) }
        pending.append((node: node, heading: heading))
    }

    mutating func cross(_ crossing: [Edge], leaving node: Node) {
        for edge in crossing {
            if edgeSeen.insert(edge.id).inserted { edges.append(edge.id) }
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
            switch carriers[node] {
            case nil, .none?:
                continue
            case .all?:
                guard passed.insert(Pass(node: node, heading: nil)).inserted else { continue }
                cross(topology.incidentEdges(of: node), leaving: node)
            case .onward?:
                guard passed.insert(Pass(node: node, heading: next.heading)).inserted else { continue }
                cross(topology.incidentEdges(of: node).filter { next.heading.continues($0, from: node) }, leaving: node)
            }
        }
    }
}
