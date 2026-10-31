public enum VParserError: Error & Equatable & Sendable {
    case unexpectedToken(String)
    case expectedIdentifier
    case expectedValue
    case duplicateNodeId(String)
    case undefinedNode(String)
}

extension VParserError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unexpectedToken(let message):
            return "Syntax error: \(message)"
        case .expectedIdentifier:
            return "Syntax error: expected an identifier"
        case .expectedValue:
            return "Syntax error: expected a value"
        case .duplicateNodeId(let id):
            return "Duplicate node: '\(id)' is already defined"
        case .undefinedNode(let id):
            return "Undefined node: '\(id)' must be defined before use in an edge"
        }
    }
}
