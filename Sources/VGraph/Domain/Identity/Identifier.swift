/// Based on https://www.swiftbysundell.com/posts/type-safe-identifiers-in-swift

public struct Identifier<Value>: VProtocol, Comparable {
    public static func < (lhs: Identifier<Value>, rhs: Identifier<Value>) -> Bool {
        return lhs.description < rhs.description
    }

    public var id: String

    public func add(_ suffix: String) -> Identifier<Value> {
        return Identifier<Value>(rawValue: self.id + "." + suffix)
    }

    public init(rawValue: String) {
        self.id = rawValue
    }

    public func starts(with firstChars: String) -> Bool {
        return id.starts(with: firstChars)
    }

    public func starts(withID firstChars: Identifier<Value>) -> Bool {
        return starts(with: firstChars.id)
    }

}

extension Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        id = value
    }

    public init(string value: String) {
        id = value
    }

}

extension Identifier: CustomStringConvertible {
    public var description: String {
        return id
    }
}

public protocol UseIdentifier: Equatable & Identifiable & Hashable & Comparable {
    var id: Identifier<Self> { get }
}

extension UseIdentifier {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.id < rhs.id
    }
}

extension UseIdentifier where ID: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
