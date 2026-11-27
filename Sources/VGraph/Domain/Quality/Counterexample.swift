/// A document that breaks one check's rule and nothing else; see [[Counterexample]].
/// Held by the notation, not the check: a check several notations name needs one in
/// each notation's own types.
public struct Counterexample: Sendable {
    public let check: String
    public let source: String

    public init(_ check: String, _ source: String) {
        self.check = check
        self.source = source
    }
}

/// One rule a notation lists, with the check that holds it and that check's
/// counterexample when there are any. Bounds and nesting rules have neither.
public struct StatedRule: Sendable, Equatable {
    public let rule: String
    public let check: String?
    public let counterexample: String?

    public init(rule: String, check: String?, counterexample: String?) {
        self.rule = rule
        self.check = check
        self.counterexample = counterexample
    }
}
