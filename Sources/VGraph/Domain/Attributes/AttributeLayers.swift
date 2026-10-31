/// ADR-0030's vocabulary for `AttributeStore`.

public enum ItemKind: String, VProtocol {
    case node, edge, group, root, nodeType, edgeType, groupType

    public var isType: Bool { self == .nodeType || self == .edgeType || self == .groupType }
}

/// Kinds do not share a keyspace, so a node and a node type may share an id.
public struct ItemKey: VProtocol, CustomStringConvertible {
    public let kind: ItemKind
    public let id: String

    public init(_ kind: ItemKind, _ id: String) {
        self.kind = kind
        self.id = id
    }

    public static let root = ItemKey(.root, "")

    public var description: String { "\(kind.rawValue) '\(id)'" }
}

public struct AttributeLayer: VProtocol, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// The display types every notation has, and the unknown types.
    public static let engine = AttributeLayer("engine")
    public static let builtin = AttributeLayer("builtin")
    public static let vnotation = AttributeLayer("vnotation")
    public static let model = AttributeLayer("model")

    public var description: String { rawValue }
}

public enum AttributeCategory: String, VProtocol {
    case content, presentation
    /// Computed by the Display pipeline. Kept as written, never pruned: "computed
    /// as empty" must not read back as "not computed".
    case computed
}

/// Which values a layer may hold. Data rather than a closure, so a layer stays
/// `Hashable` and `Codable` like the rest of the store.
public struct LayerAdmission: VProtocol {
    public let kinds: Set<ItemKind>
    public let categories: Set<AttributeCategory>

    public init(kinds: Set<ItemKind>, categories: Set<AttributeCategory>) {
        self.kinds = kinds
        self.categories = categories
    }

    public static let notation = LayerAdmission(
        kinds: [.root, .nodeType, .edgeType, .groupType], categories: [.content, .presentation])
    /// Admits computed values: a view graph's model layer holds what the pipeline computes.
    public static let model = LayerAdmission(
        kinds: [.root, .node, .edge, .group], categories: [.content, .presentation, .computed])
    public static let view = LayerAdmission(
        kinds: [.root, .node, .edge, .group, .nodeType, .edgeType, .groupType], categories: [.presentation])

    func admits(_ key: ItemKey, _ definition: AttributeDefinition) -> Bool {
        kinds.contains(key.kind) && categories.contains(definition.category)
            && (!definition.isDiagramOnly || key.kind == .root)
    }
}

public enum AttributeSource: VProtocol {
    case direct
    case rule(String)
}

public enum AttributeProvenance: VProtocol {
    case layer(AttributeLayer, key: ItemKey, source: AttributeSource)
    case `default`
}

public struct ResolvedAttribute: VProtocol {
    public let value: String
    public let provenance: AttributeProvenance

    public init(_ value: String, from provenance: AttributeProvenance) {
        self.value = value
        self.provenance = provenance
    }
}

/// An element's type, and a type's elements. The graph's structure is the only
/// record of them; the store asks rather than keeping a copy that could drift.
public protocol ChainSource {
    func type(of key: ItemKey) -> ItemKey?
    func members(of type: ItemKey) -> [ItemKey]
}
