extension Sequence {

    /// `reduce` for a step that throws `VError`; the standard one rethrows
    /// untyped, which a `throws(VError)` caller cannot propagate.
    func folding<Result>(
        _ initial: Result, _ step: (Result, Element) throws(VError) -> Result
    ) throws(VError) -> Result {
        var result = initial
        for element in self { result = try step(result, element) }
        return result
    }
}
