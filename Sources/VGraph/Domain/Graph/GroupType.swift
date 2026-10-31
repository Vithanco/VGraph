/// Phantom tag for `GroupType` — the group-level counterpart of `NodeType`.
public struct _GroupType: VProtocol, Sendable {}

/// A typed identifier for plain groups (e.g. C4's "Organisation").
/// A group's type is structure, held by `GroupStructure` and optional; a type's
/// default `GroupStyle` is registered with `set(groupType:attribute:)`.
public typealias GroupType = Identifier<_GroupType>

extension Identifier where Value == _GroupType {

    /// What the parser stamps when the document names a boundary kind the notation
    /// never registered — the group-level `NodeType.unknown`.
    public static var unknownPrefix: String { "__UNKNOWN_GROUP_TYPE__" }
    public static var unknown: GroupType { GroupType(string: unknownPrefix) }
    public var isUnknown: Bool { id.hasPrefix(Self.unknownPrefix) }

    /// Drawn in the error colour rather than as an ordinary cluster: a boundary is
    /// a large visual claim, and a mistyped one that renders normally hides the
    /// mistake in the place the author is looking.
    public static var unknownChrome: BoundaryChrome {
        BoundaryChrome(
            cornerRadius: 8,
            borderDash: "8,4",
            borderColor: SemanticColor(id: "group.unknown.border", lightHex: "#d32f2f", darkHex: "#ef5350"),
            fill: SemanticColor(id: "group.unknown.fill", lightHex: "#00000000", darkHex: "#00000000"))
    }
}

public struct GroupTypeDefinition: Sendable {
    public let groupType: GroupType
    public let description: String

    public init(_ groupType: GroupType, description: String) {
        self.groupType = groupType
        self.description = description
    }
}

extension Identifier: AttributeType where Value == _GroupType {
    public static var typeName: String { "GroupType" }

    public var asString: String { id }

    public static func fromString(_ string: String) throws(VError) -> GroupType {
        return GroupType(string: string)
    }
}
