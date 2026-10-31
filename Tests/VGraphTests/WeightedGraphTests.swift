// WeightedGraph is TypedGraph's storage, reached from everywhere else only
// through TypedGraph. These tests talk to it directly so a failure names the
// storage rather than whichever TypedGraph operation happened to use it.

import Testing

@testable import VGraph

typealias Storage = WeightedGraph<_Node>

/// Vertices in the order given, then edges as `(id, from, to)`.
func storage(_ nodes: [String], _ edges: [(String, String, String)] = []) -> Storage {
    var graph = Storage()
    for id in nodes { graph = graph.addVertex(Node(string: id)) }
    for (id, from, to) in edges { graph = graph.addEdge(Edge(string: id, from: from, to: to)) }
    return graph
}

/// Each loop as its node ids, starting at its earliest vertex.
func loopNodes(_ graph: Storage) -> [[String]] {
    graph.findLoops().loops.map { loop in loop.nodes.map { $0.id } }
}

/// `n` vertices, every one linked to every other: sum over k of C(n,k)·(k−1)!
/// loops, a known count that grows faster than any budget.
func complete(_ n: Int) -> Storage {
    let names = (0..<n).map { "n\($0)" }
    var edges: [(String, String, String)] = []
    for a in names { for b in names where a != b { edges.append(("\(a)_\(b)", a, b)) } }
    return storage(names, edges)
}

@Suite("WeightedGraph loop search")
struct WeightedGraphLoopTests {

    @Test("An acyclic graph has no loops")
    func acyclic() {
        let graph = storage(["a", "b", "c"], [("e1", "a", "b"), ("e2", "b", "c"), ("e3", "a", "c")])
        #expect(loopNodes(graph).isEmpty)
        #expect(graph.findLoops().isComplete)
    }

    @Test("A loop is reported once, starting at its earliest vertex")
    func oneLoopOnce() {
        let graph = storage(["a", "b", "c"], [("e2", "b", "c"), ("e3", "c", "a"), ("e1", "a", "b")])
        #expect(loopNodes(graph) == [["a", "b", "c"]])
    }

    @Test("A self-loop is a loop of one node")
    func selfLoop() {
        let graph = storage(["a", "b"], [("e1", "a", "a"), ("e2", "a", "b")])
        #expect(loopNodes(graph) == [["a"]])
    }

    /// ADR-0028: a loop is its nodes; each step keeps every edge that realises it.
    @Test("Parallel edges make one loop, the step holding both")
    func parallelEdges() {
        let graph = storage(["a", "b"], [("e1", "a", "b"), ("e2", "a", "b"), ("e3", "b", "a")])
        let loops = graph.findLoops().loops

        #expect(loops.map { loop in loop.nodes.map { $0.id } } == [["a", "b"]])
        #expect(loops.first?.steps.map { step in step.map { $0.id.id } } == [["e1", "e2"], ["e3"]])
    }

    @Test("Loops sharing a vertex are each found, shorter first")
    func overlappingLoops() {
        let graph = storage(
            ["a", "b", "c", "d"],
            [("ac", "a", "c"), ("cd", "c", "d"), ("da", "d", "a"), ("ab", "a", "b"), ("ba", "b", "a")])
        #expect(loopNodes(graph) == [["a", "b"], ["a", "c", "d"]])
    }

    @Test("Loops of one length are ordered by their earliest vertex")
    func separateLoops() {
        let graph = storage(
            ["a", "b", "c", "d"],
            [("cd", "c", "d"), ("dc", "d", "c"), ("ab", "a", "b"), ("ba", "b", "a")])
        #expect(loopNodes(graph) == [["a", "b"], ["c", "d"]])
    }

    @Test("No loop passes through a vertex twice")
    func noFigureEight() {
        let graph = storage(
            ["a", "b", "c"], [("ab", "a", "b"), ("ba", "b", "a"), ("bc", "b", "c"), ("cb", "c", "b")])
        #expect(loopNodes(graph) == [["a", "b"], ["b", "c"]])
    }

    /// 10 two-node, 20 three-node, 30 four-node and 24 five-node loops.
    @Test("Every loop of a complete graph on five vertices is found, once")
    func completeGraphIsExhaustive() {
        let result = complete(5).findLoops()
        #expect(result.isComplete)
        #expect(result.loops.count == 84)
        #expect(Set(result.loops.map { loop in loop.nodes.map { $0.id } }).count == 84)
        #expect(result.loops.map { $0.nodes.count } == result.loops.map { $0.nodes.count }.sorted())
    }

    /// The shape the old breadth-first search took half a second over: one loop,
    /// and a walk from every vertex that never closes.
    @Test("A long ring is one loop")
    func longRing() {
        let names = (0..<400).map { "n\($0)" }
        let graph = storage(names, names.indices.map { i in ("r\(i)", names[i], names[(i + 1) % 400]) })
        let result = graph.findLoops()
        #expect(result.isComplete)
        #expect(result.loops.count == 1)
        #expect(result.loops.first?.nodes.count == 400)
    }

    /// A complete graph on twelve vertices has hundreds of millions of loops. What
    /// comes back is capped, marked incomplete, and the shortest there are.
    @Test("Past the cap, the shortest loops come back and the result says so")
    func capKeepsTheShortest() {
        let result = complete(12).findLoops(maxLoops: 50)
        #expect(!result.isComplete)
        #expect(result.loops.count == 50)
        #expect(result.loops.allSatisfy { $0.nodes.count == 2 })
    }

    @Test("A small work budget still returns loops, shortest first")
    func budgetKeepsTheShortest() {
        let result = complete(12).findLoops(maxLoops: 10_000, workBudget: 5_000)
        #expect(!result.isComplete)
        #expect(!result.loops.isEmpty)
        #expect(result.loops.map { $0.nodes.count } == result.loops.map { $0.nodes.count }.sorted())
    }

    @Test("The same graph gives the same loops in the same order")
    func deterministic() {
        #expect(loopNodes(complete(5)) == loopNodes(complete(5)))
    }
}

/// Each step of a loop as "from>to": a feedback link, whichever edges draw it.
func links(of loop: Storage.Loop) -> [String] {
    loop.nodes.indices.map { i in "\(loop.nodes[i].id)>\(loop.nodes[(i + 1) % loop.nodes.count].id)" }
}

@Suite("WeightedGraph independent loops")
struct WeightedGraphIndependentLoopTests {

    private func independent(_ graph: Storage) -> [[String]] {
        graph.findLoops().independentLoops.map { loop in loop.nodes.map { $0.id } }
    }

    /// Two short loops and a long one closing through c→a, which only the long
    /// one covers: all three are needed.
    @Test("A loop that brings an uncovered link is kept")
    func everyLoopNeeded() {
        let graph = storage(
            ["a", "b", "c"],
            [("ab", "a", "b"), ("ba", "b", "a"), ("bc", "b", "c"), ("cb", "c", "b"), ("ca", "c", "a")])
        #expect(independent(graph) == [["a", "b"], ["b", "c"], ["a", "b", "c"]])
    }

    /// Once n0↔n1 and n0↔n2 are in, n0→n1→n2→n0 brings one new link and n1↔n2
    /// brings two, so the longer loop goes first — fewest new, not shortest. Four
    /// loops, which is E − V + 1: choosing among *all* loops reaches the full set
    /// where Oliva's list of one shortest loop per pair falls short (Huang et al.).
    @Test("Fewest new links decides before length does")
    func fewestNewBeatsShortest() {
        #expect(independent(complete(3)) == [["n0", "n1"], ["n0", "n2"], ["n0", "n1", "n2"], ["n1", "n2"]])
    }

    @Test("An independent set covers every link on a loop, each loop adding one")
    func coverageAndNovelty() {
        let search = complete(5).findLoops()
        var covered = Set<String>()
        for loop in search.independentLoops {
            let fresh = Set(links(of: loop)).subtracting(covered)
            #expect(!fresh.isEmpty, "every chosen loop brings a new link")
            covered.formUnion(fresh)
        }
        #expect(covered == Set(search.loops.flatMap(links(of:))))
        // Never more than the cycle space allows: E − V + 1 = 20 − 5 + 1.
        #expect(search.independentLoops.count <= 16)
    }

    /// Oliva's rule: of the loops that bring anything new, the one bringing the
    /// fewest. a→b→a brings two links, a→b→c→a three; once the short loops are in,
    /// the long one brings only c→a and is taken over a longer rival bringing more.
    @Test("Of the loops bringing something new, the one bringing least is taken first")
    func fewestNewLinksFirst() {
        let graph = storage(
            ["a", "b", "c", "d"],
            [
                ("ab", "a", "b"), ("ba", "b", "a"), ("bc", "b", "c"), ("cb", "c", "b"), ("ca", "c", "a"),
                ("cd", "c", "d"), ("da", "d", "a"),
            ])
        #expect(independent(graph) == [["a", "b"], ["b", "c"], ["a", "b", "c"], ["a", "b", "c", "d"]])
    }

    @Test("The same graph gives the same independent set")
    func deterministic() {
        #expect(independent(complete(5)) == independent(complete(5)))
    }
}

/// The invariant everything else relies on: exactly one list per vertex, every
/// edge filed under its source with its target present, and the id index naming
/// each edge's source and nothing else.
func isConsistent(_ graph: Storage) -> Bool {
    guard Set(graph.vertices).count == graph.vertices.count,
        Set(graph.outgoing.keys) == Set(graph.vertices)
    else { return false }
    var indexed = 0
    for (source, list) in graph.outgoing {
        for edge in list {
            guard edge.from == source, graph.has(node: edge.to), graph.sourceOf[edge.id] == source
            else { return false }
            indexed += 1
        }
    }
    return indexed == graph.sourceOf.count && indexed == graph.edgeCount
}

func edgeIds(_ graph: Storage) -> [String] {
    graph.getEdges().map { $0.id.id }
}

@Suite("WeightedGraph building and reading")
struct WeightedGraphBuildTests {

    @Test("A new graph is empty")
    func empty() {
        let graph = Storage()
        #expect(graph.vertexCount == 0)
        #expect(graph.edgeCount == 0)
        #expect(graph.getEdges().isEmpty)
        #expect(isConsistent(graph))
    }

    @Test("Adding a vertex appends it with no edges, and leaves the original alone")
    func addVertex() {
        let before = storage(["a"])
        let after = before.addVertex(Node(string: "b"))

        #expect(after.vertices == [Node(string: "a"), Node(string: "b")])
        #expect(after.has(node: Node(string: "b")))
        #expect(before.vertices == [Node(string: "a")])
        #expect(isConsistent(after))
    }

    @Test("Adding a vertex that is already there changes nothing")
    func addVertexTwice() {
        let graph = storage(["a", "b"], [("e1", "a", "b")])
        #expect(graph.addVertex(Node(string: "a")) == graph)
    }

    @Test("Adding an edge files it under its source, and leaves the original alone")
    func addEdge() {
        let before = storage(["a", "b"])
        let after = before.addEdge(Edge(string: "e1", from: "b", to: "a"))

        #expect(after.outgoing[Node(string: "a")] == [])
        #expect(after.outgoing[Node(string: "b")]?.map { $0.id.id } == ["e1"])
        #expect(before.edgeCount == 0)
        #expect(isConsistent(after))
    }

    @Test("An edge with a missing end, or an id already used, is not added")
    func addEdgeRefused() {
        let graph = storage(["a", "b"], [("e1", "a", "b")])
        #expect(graph.addEdge(Edge(string: "e2", from: "a", to: "z")) == graph)
        #expect(graph.addEdge(Edge(string: "e2", from: "z", to: "a")) == graph)
        #expect(graph.addEdge(Edge(string: "e1", from: "b", to: "a")) == graph)
    }

    @Test("An edge is found by id, wherever it sits")
    func getEdgeById() {
        let graph = storage(["a", "b"], [("e1", "a", "b"), ("e2", "b", "a"), ("e3", "b", "b")])
        #expect(graph.get(edge: Edge.Id(string: "e3")) == Edge(string: "e3", from: "b", to: "b"))
        #expect(graph.get(edge: Edge.Id(string: "zz")) == nil)
        #expect(graph.has(edge: Edge.Id(string: "e2")))
        #expect(!graph.has(edge: Edge.Id(string: "zz")))
    }

    @Test("Removing an edge drops only it; an unknown id changes nothing")
    func removeEdge() {
        let graph = storage(["a", "b"], [("e1", "a", "b"), ("e2", "a", "b"), ("e3", "b", "a")])
        let after = graph.removeEdge(id: Edge.Id(string: "e2"))

        #expect(edgeIds(after) == ["e1", "e3"])
        #expect(isConsistent(after))
        #expect(graph.removeEdge(id: Edge.Id(string: "zz")) == graph)
        #expect(edgeIds(graph) == ["e1", "e2", "e3"])
    }

    @Test("Edges are listed by source vertex, then in the order added")
    func edgeListOrder() {
        let graph = storage(["a", "b"], [("e1", "b", "a"), ("e2", "a", "b"), ("e3", "b", "b"), ("e4", "a", "a")])
        #expect(edgeIds(graph) == ["e2", "e4", "e1", "e3"])
        #expect(graph.edgeCount == 4)
        #expect(graph.vertexCount == 2)
    }

    @Test("A vertex is found by id")
    func hasNode() {
        let graph = storage(["a", "b"])
        #expect(graph.has(node: Node(string: "b")))
        #expect(!graph.has(node: Node(string: "z")))
    }

    @Test("Edges between two vertices come back in the order added, one direction only")
    func getEdges() {
        let graph = storage(["a", "b"], [("e1", "a", "b"), ("e2", "b", "a"), ("e3", "a", "b")])
        let a = Node(string: "a")
        let b = Node(string: "b")

        #expect(graph.getEdges(from: a, to: b)?.map { $0.id.id } == ["e1", "e3"])
        #expect(graph.getEdges(from: b, to: a)?.map { $0.id.id } == ["e2"])
        #expect(graph.getEdges(from: a, to: a) == [])
        #expect(graph.getEdges(from: a, to: Node(string: "z")) == nil)
        #expect(graph.getEdges(from: Node(string: "z"), to: a) == nil)
    }

    @Test("An edge exists only in its own direction, and never to a missing vertex")
    func edgeExists() {
        let graph = storage(["a", "b"], [("e1", "a", "b")])
        let a = Node(string: "a")
        let b = Node(string: "b")

        #expect(graph.edgeExists(from: a, to: b))
        #expect(!graph.edgeExists(from: b, to: a))
        #expect(!graph.edgeExists(from: a, to: a))
        #expect(!graph.edgeExists(from: a, to: Node(string: "z")))
        #expect(!graph.edgeExists(from: Node(string: "z"), to: b))
    }
}

@Suite("WeightedGraph vertex removal")
struct WeightedGraphRemovalTests {

    /// Every kind of edge relative to the removed vertex `b`: entirely below or
    /// above it, crossing it in both directions, into and out of it, and loops.
    private let everyCase = storage(
        ["a", "b", "c", "d"],
        [
            ("aa", "a", "a"), ("ab", "a", "b"), ("ac", "a", "c"),
            ("ba", "b", "a"), ("bb", "b", "b"), ("bd", "b", "d"),
            ("ca", "c", "a"), ("cb", "c", "b"), ("cd", "c", "d"),
            ("dd", "d", "d"),
        ])

    @Test("Removing a vertex drops its edges and renumbers the rest")
    func removeMiddle() {
        let after = everyCase.removeVertex(Node(string: "b"))

        #expect(after.vertices == ["a", "c", "d"].map { Node(string: $0) })
        #expect(edgeIds(after) == ["aa", "ac", "ca", "cd", "dd"])
        #expect(isConsistent(after))
    }

    @Test("Removing the first or the last vertex keeps the graph consistent")
    func removeEnds() {
        let first = everyCase.removeVertex(Node(string: "a"))
        #expect(edgeIds(first) == ["bb", "bd", "cb", "cd", "dd"])
        #expect(isConsistent(first))

        let last = everyCase.removeVertex(Node(string: "d"))
        #expect(edgeIds(last) == ["aa", "ab", "ac", "ba", "bb", "ca", "cb"])
        #expect(isConsistent(last))
    }

    @Test("Removing the only vertex leaves an empty graph")
    func removeOnly() {
        let after = storage(["a"], [("aa", "a", "a")]).removeVertex(Node(string: "a"))
        #expect(after.vertexCount == 0)
        #expect(after.edgeCount == 0)
        #expect(isConsistent(after))
    }

    @Test("Removal leaves the original graph untouched")
    func removalIsPure() {
        _ = everyCase.removeVertex(Node(string: "b"))
        #expect(everyCase.vertexCount == 4)
        #expect(edgeIds(everyCase) == ["aa", "ab", "ac", "ba", "bb", "bd", "ca", "cb", "cd", "dd"])
    }

    @Test("Removing an unknown vertex changes nothing")
    func removeUnknown() {
        #expect(everyCase.removeVertex(Node(string: "z")) == everyCase)
    }

    @Test("Loops are found correctly after a removal")
    func cyclesAfterRemoval() {
        // a→b→c→a and a→d→a; removing b leaves only the second.
        let graph = storage(
            ["a", "b", "c", "d"],
            [("ab", "a", "b"), ("bc", "b", "c"), ("ca", "c", "a"), ("ad", "a", "d"), ("da", "d", "a")])
        #expect(loopNodes(graph.removeVertex(Node(string: "b"))) == [["a", "d"]])
    }

    /// Random graphs, including loops and parallel edges, emptied one random
    /// vertex at a time. After each removal the graph must be consistent and hold
    /// exactly the edges that avoided every removed vertex, in their old order.
    @Test("Random removals keep the graph consistent", arguments: 0..<200)
    func randomRemovals(seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        let names = (0..<Int(rng.next() % 8 + 1)).map { "n\($0)" }
        let edges = (0..<Int(rng.next() % 16)).map { i in
            ("e\(i)", names[Int(rng.next() % UInt64(names.count))], names[Int(rng.next() % UInt64(names.count))])
        }
        var graph = storage(names, edges)
        var removed = Set<String>()

        while graph.vertexCount > 0 {
            let index = Int(rng.next() % UInt64(graph.vertexCount))
            removed.insert(graph.vertices[index].id)
            graph = graph.removeVertex(graph.vertices[index])

            let survivors = storage(names, edges).getEdges()
                .filter { !removed.contains($0.from.id) && !removed.contains($0.to.id) }
                .map { $0.id.id }
            #expect(isConsistent(graph), "seed \(seed)")
            #expect(edgeIds(graph) == survivors, "seed \(seed)")
        }
    }
}

/// Deterministic, so a failing seed can be replayed.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
