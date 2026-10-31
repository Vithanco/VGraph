/// A directed multigraph keyed by vertex id. Edges are the domain edges
/// themselves; nothing refers to a vertex by position, so removing one never
/// renumbers anything.
/// original Idea  from SwiftGraph, but changed for our needs
public struct WeightedGraph<D: VProtocol>: VProtocol {

    public typealias V = Identifier<D>
    public typealias W = BaseEdge<D>

    /// In the order added. Edge order and cycle order both follow it.
    public let vertices: [V]
    /// Every vertex's outgoing edges in the order added — an empty list for none,
    /// so a key's presence is membership.
    let outgoing: [V: [W]]
    /// The vertex each edge leaves, so an edge is found without a scan.
    let sourceOf: [W.Id: V]

    public init() {
        self.init(vertices: [], outgoing: [:], sourceOf: [:])
    }

    private init(vertices: [V], outgoing: [V: [W]], sourceOf: [W.Id: V]) {
        self.vertices = vertices
        self.outgoing = outgoing
        self.sourceOf = sourceOf
    }

    public var vertexCount: Int { vertices.count }

    public var edgeCount: Int { sourceOf.count }

    func has(node: V) -> Bool {
        outgoing[node] != nil
    }

    func has(edge id: W.Id) -> Bool {
        sourceOf[id] != nil
    }

    func get(edge id: W.Id) -> W? {
        guard let source = sourceOf[id] else { return nil }
        return outgoing[source]?.first { $0.id == id }
    }

    /// By source vertex, then in the order added.
    func getEdges() -> [W] {
        vertices.flatMap { outgoing[$0] ?? [] }
    }

    /// `nil` when either vertex is missing; in the order added otherwise.
    public func getEdges(from: V, to: V) -> [W]? {
        guard has(node: to), let leaving = outgoing[from] else { return nil }
        return leaving.filter { $0.to == to }
    }

    public func edgeExists(from: V, to: V) -> Bool {
        !(getEdges(from: from, to: to) ?? []).isEmpty
    }

    /// Unchanged when the vertex is already there: ids are unique.
    public func addVertex(_ v: V) -> Self {
        guard !has(node: v) else { return self }
        var outgoing = self.outgoing
        outgoing[v] = []
        return WeightedGraph(vertices: vertices + [v], outgoing: outgoing, sourceOf: sourceOf)
    }

    /// Unchanged unless both ends are vertices and the id is new.
    func addEdge(_ edge: W) -> Self {
        guard has(node: edge.from), has(node: edge.to), !has(edge: edge.id) else { return self }
        var outgoing = self.outgoing
        outgoing[edge.from, default: []].append(edge)
        var sourceOf = self.sourceOf
        sourceOf[edge.id] = edge.from
        return WeightedGraph(vertices: vertices, outgoing: outgoing, sourceOf: sourceOf)
    }

    func removeEdge(id: W.Id) -> Self {
        guard let source = sourceOf[id] else { return self }
        var outgoing = self.outgoing
        outgoing[source]?.removeAll { $0.id == id }
        var sourceOf = self.sourceOf
        sourceOf[id] = nil
        return WeightedGraph(vertices: vertices, outgoing: outgoing, sourceOf: sourceOf)
    }

    /// Drops the vertex's edges in both directions. Only lists holding an edge
    /// into it are rewritten.
    public func removeVertex(_ vertex: V) -> Self {
        guard let leaving = outgoing[vertex] else { return self }
        var outgoing = self.outgoing
        var sourceOf = self.sourceOf
        outgoing[vertex] = nil
        for edge in leaving { sourceOf[edge.id] = nil }
        for (source, list) in outgoing where list.contains(where: { $0.to == vertex }) {
            for edge in list where edge.to == vertex { sourceOf[edge.id] = nil }
            outgoing[source] = list.filter { $0.to != vertex }
        }
        return WeightedGraph(
            vertices: vertices.filter { $0 != vertex }, outgoing: outgoing, sourceOf: sourceOf)
    }
}
