// Named transform resolution for dynamic notations: users reference transforms by
// name in vnotation blocks, and this registry maps those names to steps.

public enum TransformRegistry {

    /// One list for dispatch and for the names an unknown one is told about, so the
    /// two cannot drift.
    private static var transforms: [(name: String, step: TransformStep?)] {
        [("mergeRelations", Notations.ConceptMap.mergeStep), ("identity", nil)]
    }

    /// Resolve a named transform to its step, so a `vnotation`-declared transform
    /// records itself like any other.
    public static func resolveStep(name: String) throws(VError) -> TransformStep? {
        guard let transform = transforms.first(where: { $0.name == name }) else {
            throw VError.parsingError(
                "Unknown transform '\(name)'. Available: \(transforms.map { $0.name }.joined(separator: ", "))")
        }
        return transform.step
    }
}
