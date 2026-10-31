public protocol HasReadableNames: CaseIterable & Identifiable & NameDescribable & VProtocol & AttributeType {
    var readableName: String { get }
    var alias: String { get }
    /// The programmatic/VGL name for this value, derived from the Swift enum case name.
    var value: String { get }
    var toolTip: String { get }
    static var typeName: String { get }
}

extension HasReadableNames {
    public var id: Self {
        return self
    }

    public var alias: String {
        return readableName
    }

    // Note: `value` and `readableName` have no default implementation — under
    // Embedded Swift `"\(self)"` does not return the enum case name (no reflection),
    // so every conformer must provide an explicit `switch self`. The pre-Embedded
    // reflection-based defaults were deleted in the Phase 1 embedded migration.

    // Closures (not key paths) — Embedded Swift doesn't support key paths.
    static var readableNames: [String] {
        return allCases.map { $0.readableName }
    }

    static var toolTips: [String] {
        return allCases.map { $0.toolTip }
    }
}

extension HasReadableNames {
    public var toolTip: String {
        return readableName
    }
    public static func fromString(_ string: String) throws(VError) -> Self {
        if let result = Self.allCases.first(where: { $0.readableName == string || $0.alias == string || $0.value == string }) {
            return result
        }
        throw VError.conversionError(from: string, to: Self.typeName)
    }
    public static func toString(_ value: Self) -> String {
        return value.readableName
    }

    public var asString: String {
        return alias
    }
}
