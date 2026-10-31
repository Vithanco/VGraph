// Loops are judged on the OriginGraph and drawn on the display graph (ADR-0027).
// Folding keeps the id of every edge that crosses a folded group and deletes the
// ones inside it, so a recorded loop projects by its surviving edges alone (a
// bundled edge survives as its bundle): none
// left means it ran wholly inside a fold, and a loop the model lacks was never
// recorded to begin with.

extension TransformStep.Id {
    public static var recordLoops: Self { "recordLoops" }
}

extension TLoop {
    /// Runs as a notation step, so before folding, and only for notations that mark
    /// loops: enumerating cycles is not free.
    public static var recordStep: TransformStep {
        TransformStep(.recordLoops) { (graph: VGraph) throws(VError) in
            if graph.completedSteps.contains(.recordLoops) { return graph }
            let loops = TLoop.fromLoops(graph.loopMarkers.selecting(from: graph.findLoops()), in: graph)
            return try graph.set(graphAttribute: Attributes.Group.recordedLoops.attribute(encode(loops)))
        }
    }

    // Control characters as separators: they cannot occur in a VGL id or label.
    private static let loopSeparator: Character = "\u{1E}"
    private static let fieldSeparator: Character = "\u{1F}"
    private static let noteSeparator: Character = "\u{1D}"

    /// Per loop: its style, its ambiguous links, then its edge ids.
    private static func encode(_ loops: [TLoop]) -> String {
        loops.map { loop in
            ([loop.loopStyle.value, loop.ambiguousLinks.joined(separator: String(noteSeparator))]
                + loop.edges.map { $0.id.id }).joined(separator: String(fieldSeparator))
        }.joined(separator: String(loopSeparator))
    }

    fileprivate static func decode(_ recorded: String)
        -> [(style: LoopStyle, ambiguousLinks: [String], edges: [Edge.Id])]
    {
        recorded.split(separator: loopSeparator).compactMap { entry in
            let fields = entry.split(separator: fieldSeparator, omittingEmptySubsequences: false).map { String($0) }
            guard fields.count >= 2, let style = try? LoopStyle.fromString(fields[0]) else { return nil }
            let notes = fields[1].split(separator: noteSeparator).map { String($0) }
            return (style, notes, fields.dropFirst(2).map { Edge.Id(string: $0) })
        }
    }
}

extension VGraph {
    /// The loops to mark on this graph: the model's, projected onto what is drawn,
    /// when the pipeline recorded them; otherwise the graph's own, since a graph
    /// that skipped the pipeline is the model.
    public var loopsToMark: [TLoop] {
        guard completedSteps.contains(.recordLoops) else {
            return TLoop.fromLoops(loopMarkers.selecting(from: findLoops()), in: self)
        }
        let recorded: String = (try? get(graphAttribute: Attributes.Group.recordedLoops)) ?? ""
        let bundles = bundleOfMember
        return TLoop.decode(recorded).compactMap { loop in
            let surviving = loop.edges.compactMap { get(edge: $0) ?? bundles[$0] }
            guard !surviving.isEmpty else { return nil }
            return TLoop(
                edges: surviving, nodes: surviving.map { $0.from }, loopStyle: loop.style,
                ambiguousLinks: loop.ambiguousLinks)
        }
    }
}
