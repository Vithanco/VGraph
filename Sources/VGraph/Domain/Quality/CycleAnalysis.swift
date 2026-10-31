public struct CycleAnalysis {
    /// One edge per step: the first that realises it.
    public let cycles: [[Edge]]
    /// False when the graph has more loops than were searched for (ADR-0028).
    public let isComplete: Bool

    public static func analyze(_ graph: VGraph) -> CycleAnalysis {
        let search = graph.findLoops()
        return CycleAnalysis(
            cycles: search.loops.map { loop in loop.steps.compactMap { $0.first } }, isComplete: search.isComplete)
    }
}
