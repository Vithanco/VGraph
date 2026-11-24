/// The logical reasoning type of a diagram notation.
///
/// Vithanco diagrams use one of three logic types that govern how edges are interpreted.
public enum DiagramLogic: HasReadableNames {

    /// No particular logic applies (e.g., Concept Maps, IBIS).
    case noLogic
    /// Each predecessor is enough (sufficient) to achieve the successor ("If A then B"):
    /// if any predecessor is valid, the successor is valid too.
    case sufficientCause
    /// Each predecessor is needed to achieve the successor, but not necessarily sufficient:
    /// only if all predecessors are valid is the successor valid.
    case necessaryCondition

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
}
