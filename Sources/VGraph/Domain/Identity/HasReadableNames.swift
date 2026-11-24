public protocol HasReadableNames: CaseIterable & Identifiable & NameDescribable & VProtocol & AttributeType {
    var readableName: String { get }
    var alias: String { get }
    /// The programmatic/VGL name for this value.
    var value: String { get }
    static var typeName: String { get }
}

extension HasReadableNames {
    public var id: Self {
        return self
    }

    public var alias: String {
        return readableName
    }

    // No default `value` or `readableName`: under Embedded Swift `"\(self)"` does
    // not yield the case name, so every conformer spells them out.
}

extension HasReadableNames {
    public static func fromString(_ string: String) throws(VError) -> Self {
        if let result = Self.allCases.first(where: { $0.readableName == string || $0.alias == string || $0.value == string }) {
            return result
        }
        throw VError.conversionError(from: string, to: Self.typeName)
    }

    public var asString: String {
        return alias
    }
}
