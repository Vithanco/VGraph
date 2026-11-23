import VGraph

extension VGraph {
    /// Satisfies a step's prerequisites without running its predecessors.
    public func marking(_ steps: [TransformStep.Id]) throws(VError) -> VGraph {
        var result = self
        for step in steps {
            result = try result.recordingCompletion(of: step)
        }
        return result
    }
}
