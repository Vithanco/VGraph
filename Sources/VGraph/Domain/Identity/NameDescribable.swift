public protocol NameDescribable {
    static var typeName: String { get }
}

// No default: under Embedded Swift `"\(type(of: self))"` does not yield the
// type's name, so every conformer declares it.
