extension VGraph {
    static func derivedPairs(edges: [(from: String, to: String)], visible: Set<String>) -> [(from: String, to: String)] {
        var successors: [String: [String]] = [:]
        var real: Set<String> = []
        for edge in edges {
            successors[edge.from, default: []].append(edge.to)
            if visible.contains(edge.from) && visible.contains(edge.to) { real.insert(pairKey(edge.from, edge.to)) }
        }
        var result: [(from: String, to: String)] = []
        for start in visible.sorted() {
            var stack = (successors[start] ?? []).filter { !visible.contains($0) }
            var seen: Set<String> = []
            var reached: Set<String> = []
            while let hidden = stack.popLast() {
                if !seen.insert(hidden).inserted { continue }
                for next in successors[hidden] ?? [] {
                    if visible.contains(next) { reached.insert(next) } else { stack.append(next) }
                }
            }
            for end in reached.sorted() where !real.contains(pairKey(start, end)) {
                result.append((from: start, to: end))
            }
        }
        return result
    }

    private static func pairKey(_ from: String, _ to: String) -> String { from + "\u{1F}" + to }

    func addingDerivedEdges(of origin: VGraph, visible: Set<String>) throws(VError) -> VGraph {
        let pairs = origin.edges.map { (from: $0.from.id, to: $0.to.id) }
        var result = self
        for pair in Self.derivedPairs(edges: pairs, visible: visible) {
            let fromType = try result.nodeType(for: Node(string: pair.from))
            let toType = try result.nodeType(for: Node(string: pair.to))
            let type = EdgeType(id: "\(EdgeType.derivedPrefix)\(fromType.id)__\(toType.id)", from: fromType, to: toType)
            if result.get(edgeType: type.id) == nil {
                result = try result.placing(
                    NotationContent(
                        edgeTypes: [type], values: [.edgeType(type, [Attributes.Edge.style(.dotted)])]),
                    in: .engine)
            }
            let edge = Edge(string: "derived-\(pair.from)-\(pair.to)", from: pair.from, to: pair.to)
            result = try result.add(edge: edge, edgeType: type)
        }
        return result
    }
}
