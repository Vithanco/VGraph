// Finding a graph's loops (ADR-0028). A loop is a cycle of vertices; each step
// keeps every edge that realises it, so parallel edges make one loop rather than
// one per combination. Johnson's algorithm (1975) finds them all, with work
// proportional to what it reports. Past a cap — on loops or on work — the result
// is instead the shortest loops, found breadth first, and says it is incomplete:
// a dense graph has more loops than anything could list.

extension WeightedGraph {

    public struct Loop: Sendable {
        /// Starting at the loop's earliest vertex, in the graph's vertex order.
        public let nodes: [V]
        /// `steps[i]` holds every edge from `nodes[i]` to the next node round.
        public let steps: [[W]]
    }

    public struct LoopSearch: Sendable {
        /// Shortest first; loops of one length in vertex order.
        public let loops: [Loop]
        /// False when the cap was reached: `loops` are then the shortest there are,
        /// not all of them.
        public let isComplete: Bool
    }

    public func findLoops(maxLoops: Int = 100, workBudget: Int = 200_000) -> LoopSearch {
        let successors = collapsedSuccessors()
        let found: [[Int]]
        let complete: Bool
        if let all = johnson(successors, maxLoops: maxLoops, workBudget: workBudget) {
            found = all
            complete = true
        } else {
            found = shortestFirst(successors, maxLoops: maxLoops, workBudget: workBudget)
            complete = false
        }
        let ordered = found.sorted { a, b in a.count != b.count ? a.count < b.count : a.lexicographicallyPrecedes(b) }
        return LoopSearch(loops: ordered.map(loop(through:)), isComplete: complete)
    }

    /// Each vertex's distinct successors by position, in the order first reached.
    private func collapsedSuccessors() -> [[Int]] {
        var position: [V: Int] = [:]
        for (index, vertex) in vertices.enumerated() { position[vertex] = index }
        return vertices.map { vertex in
            var seen = Set<Int>()
            var result: [Int] = []
            for edge in outgoing[vertex] ?? [] {
                if let target = position[edge.to], seen.insert(target).inserted { result.append(target) }
            }
            return result
        }
    }

    private func loop(through positions: [Int]) -> Loop {
        let nodes = positions.map { vertices[$0] }
        let steps = nodes.indices.map { i in
            let to = nodes[(i + 1) % nodes.count]
            return (outgoing[nodes[i]] ?? []).filter { $0.to == to }
        }
        return Loop(nodes: nodes, steps: steps)
    }

    // MARK: - Johnson

    /// Every elementary cycle, each starting at its least vertex; `nil` once more
    /// than `maxLoops` are found or the work runs out. Iterative throughout: the
    /// wasm stack is small and a ring would recurse once per vertex.
    private func johnson(_ successors: [[Int]], maxLoops: Int, workBudget: Int) -> [[Int]]? {
        let count = successors.count
        let component = stronglyConnectedComponents(successors)
        var loops: [[Int]] = []
        var work = 0
        var blocked = [Bool](repeating: false, count: count)
        var blockedBy = [[Int]](repeating: [], count: count)

        for start in 0..<count {
            // Only the start's component, and only vertices from it on: a loop
            // through an earlier vertex was found when that one was the start.
            let within = { (v: Int) in v >= start && component[v] == component[start] }
            let reachable = successors[start].filter(within)
            if reachable.isEmpty { continue }

            for v in 0..<count where within(v) {
                blocked[v] = false
                blockedBy[v] = []
            }

            var path = [start]
            blocked[start] = true
            var frames: [(vertex: Int, next: Int, closed: Bool)] = [(start, 0, false)]

            while let top = frames.last {
                let next = successors[top.vertex].dropFirst(top.next).first
                if let w = next {
                    frames[frames.count - 1].next += 1
                    guard within(w) else { continue }
                    work += 1
                    if work > workBudget { return nil }
                    if w == start {
                        loops.append(path)
                        if loops.count > maxLoops { return nil }
                        frames[frames.count - 1].closed = true
                    } else if !blocked[w] {
                        path.append(w)
                        blocked[w] = true
                        frames.append((w, 0, false))
                    }
                    continue
                }

                // Every successor tried: a vertex that closed a loop is free again;
                // one that did not stays blocked until a vertex it leads to frees.
                frames.removeLast()
                path.removeLast()
                if top.closed {
                    unblock(top.vertex, &blocked, &blockedBy)
                    if !frames.isEmpty { frames[frames.count - 1].closed = true }
                } else {
                    for w in successors[top.vertex] where within(w) && !blockedBy[w].contains(top.vertex) {
                        blockedBy[w].append(top.vertex)
                    }
                }
            }
        }
        return loops
    }

    private func unblock(_ vertex: Int, _ blocked: inout [Bool], _ blockedBy: inout [[Int]]) {
        var pending = [vertex]
        while let v = pending.popLast() {
            guard blocked[v] else { continue }
            blocked[v] = false
            pending.append(contentsOf: blockedBy[v])
            blockedBy[v] = []
        }
    }

    /// A component number per vertex (Kosaraju, iteratively).
    private func stronglyConnectedComponents(_ successors: [[Int]]) -> [Int] {
        let count = successors.count
        var predecessors = [[Int]](repeating: [], count: count)
        for (v, targets) in successors.enumerated() {
            for w in targets { predecessors[w].append(v) }
        }

        var finished: [Int] = []
        var visited = [Bool](repeating: false, count: count)
        for root in 0..<count where !visited[root] {
            visited[root] = true
            var frames: [(vertex: Int, next: Int)] = [(root, 0)]
            while let top = frames.last {
                if top.next < successors[top.vertex].count {
                    let w = successors[top.vertex][top.next]
                    frames[frames.count - 1].next += 1
                    if !visited[w] {
                        visited[w] = true
                        frames.append((w, 0))
                    }
                } else {
                    finished.append(top.vertex)
                    frames.removeLast()
                }
            }
        }

        var component = [Int](repeating: -1, count: count)
        var label = 0
        for root in finished.reversed() where component[root] < 0 {
            var pending = [root]
            component[root] = label
            while let v = pending.popLast() {
                for w in predecessors[v] where component[w] < 0 {
                    component[w] = label
                    pending.append(w)
                }
            }
            label += 1
        }
        return component
    }

    // MARK: - Shortest first

    /// Loops in order of length, breadth first from each start, never below it:
    /// the fallback that makes a capped result the shortest loops rather than the
    /// first ones a depth-first search happened on.
    private func shortestFirst(_ successors: [[Int]], maxLoops: Int, workBudget: Int) -> [[Int]] {
        var loops: [[Int]] = []
        var work = 0
        var open: [[Int]] = successors.indices.map { [$0] }
        var next = 0
        while next < open.count {
            let path = open[next]
            next += 1
            let start = path[0]
            for w in successors[path[path.count - 1]] {
                work += 1
                if work > workBudget { return loops }
                if w == start {
                    loops.append(path)
                    if loops.count == maxLoops { return loops }
                } else if w > start && !path.contains(w) {
                    open.append(path + [w])
                }
            }
        }
        return loops
    }
}

extension WeightedGraph.LoopSearch {
    /// A set of loops that together cover every feedback link, shortest where
    /// possible — the `independent` loop markers (ADR-0028). Oliva's selection
    /// (2004): of the loops still bringing an uncovered link, take the one
    /// bringing the fewest, the shorter on a tie, until none brings any. In the
    /// order taken. It covers every link; it does not promise E − V + 1 loops,
    /// which this falls short of on dense graphs just as Oliva's procedure does.
    public var independentLoops: [WeightedGraph.Loop] {
        let linkSets = loops.map { loop in
            Set(loop.nodes.indices.map { i in Link(from: loop.nodes[i], to: loop.nodes[(i + 1) % loop.nodes.count]) })
        }
        var covered = Set<Link>()
        var taken: [WeightedGraph.Loop] = []
        var open = Array(loops.indices)
        while true {
            var best: (index: Int, fresh: Int)? = nil
            for index in open {
                let fresh = linkSets[index].subtracting(covered).count
                guard fresh > 0 else { continue }
                // `loops` is shortest first, so the first of equals is the shorter.
                if best == nil || fresh < best!.fresh { best = (index, fresh) }
            }
            guard let chosen = best else { return taken }
            taken.append(loops[chosen.index])
            covered.formUnion(linkSets[chosen.index])
            open.removeAll { $0 == chosen.index }
        }
    }

    private struct Link: Hashable {
        let from: WeightedGraph.V
        let to: WeightedGraph.V
    }
}
