public protocol NameDescribable {
    static var typeName: String { get }
}

// Note: `typeName` has no default implementation — under Embedded Swift
// `"\(type(of: self))"` does not yield a useful name (no reflection), so every
// conformer must declare `static let typeName: String = "..."` explicitly.
// The pre-Embedded reflection-based default was deleted in the Phase 1
// embedded migration.
