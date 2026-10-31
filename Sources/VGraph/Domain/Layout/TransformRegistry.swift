// Named transform resolution for dynamic notations: users reference transforms by
// name in vnotation blocks, and this registry maps those names to steps.

public enum TransformRegistry {

    /// Resolve a named transform to its step, so a `vnotation`-declared transform
    /// records itself like any other.
    public static func resolveStep(name: String) throws(VError) -> TransformStep? {
        switch name {
        case "mergeRelations":
            return Notations.ConceptMap.mergeStep
        case "identity":
            return nil
        default:
            throw VError.parsingError("Unknown transform '\(name)'. Available: mergeRelations, identity")
        }
    }

    public static func resolve(name: String) throws(VError) -> GraphTransform {
        guard let step = try resolveStep(name: name) else { return TransformPipeline.identity }
        return step.asTransform
    }
}
