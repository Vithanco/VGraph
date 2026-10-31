/// The logical reasoning type of a diagram notation.
///
/// Vithanco diagrams use one of three logic types that govern how edges are interpreted:
/// - **noLogic**: No particular logic applies (e.g., Concept Maps, IBIS)
/// - **sufficientCause**: Each predecessor is enough to achieve the successor ("If A then B")
/// - **necessaryCondition**: All predecessors are needed to achieve the successor
public enum DiagramLogic: HasReadableNames {

    case noLogic
    case sufficientCause
    case necessaryCondition

    public var toolTip: String {
        switch self {
        case .noLogic: return "Don't use any particular logic"
        case .sufficientCause:
            return
                "'Sufficient Cause' logic means that each predecessor is enough (=sufficient) to achieve the successor. So, if any predecessor is valid then the successors are valid, too."
        case .necessaryCondition:
            return
                "'Necessary Condition' logic means that each predecessor is needed to achieve the successor but not necessarily sufficient. So, only if all predecessors are valid is the successor also valid."
        }
    }

    public var readableName: String {
        switch self {
        case .noLogic: return "None"
        case .necessaryCondition: return "Necessary Condition"
        case .sufficientCause: return "Sufficient Cause"
        }
    }

    // Explicit per-case strings — no enum-case reflection under Embedded Swift.
    public var value: String {
        switch self {
        case .noLogic: return "noLogic"
        case .sufficientCause: return "sufficientCause"
        case .necessaryCondition: return "necessaryCondition"
        }
    }

    public static let typeName: String = "DiagramLogic"

    public var relationshipName: String {
        switch self {
        case .noLogic: return "points at"
        case .sufficientCause: return "sufficient causes"
        case .necessaryCondition: return "is necessary for"
        }
    }

    public var connectionName: String {
        switch self {
        case .noLogic: return "connection"
        case .sufficientCause: return "sufficient cause"
        case .necessaryCondition: return "necessary condition"
        }
    }
}
