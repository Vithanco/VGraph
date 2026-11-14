/// How far a node type carries a [[Neighbourhood]] past itself (ADR-0037).
public enum AddsToNeighborhood: EnumAttributeType {
    /// The node is lit and the walk ends: it is a thing, not part of how a claim
    /// is written.
    case none
    /// Every end, because they all make one claim — a [[Junctor]], an equation.
    case all
    /// Only the ends that continue the way the walk came in, because each pair
    /// is its own claim — a Concept Map Relation.
    case onward

    public var value: String {
        switch self {
        case .none: return "none"
        case .all: return "all"
        case .onward: return "onward"
        }
    }

    public var readableName: String {
        switch self {
        case .none: return "Only itself"
        case .all: return "All its ends"
        case .onward: return "Onward only"
        }
    }

    /// Stored and written as the VGL value: `addsToNeighborhood: onward`.
    public var alias: String { value }

    public static let typeName: String = "AddsToNeighborhood"
}
