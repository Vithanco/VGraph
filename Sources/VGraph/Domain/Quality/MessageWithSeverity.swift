public enum Severity: String, VProtocol, AttributeType {
    public static let typeName: String = "Severity"

    case error
    case warning
    case info

    public static func fromString(_ string: String) throws(VError) -> Severity {
        guard let value = Severity(rawValue: string) else {
            throw VError.conversionError(from: string, to: typeName)
        }
        return value
    }

    public var asString: String {
        return self.rawValue
    }
}

/// What a quality message is about. `.graph` has no single source location.
public enum QualityTarget: Sendable, Equatable, Hashable {
    case graph
    case node(String)
    case edge(from: String, to: String)
}

public struct MessageWithSeverity: VProtocol, AttributeType {
    public static let typeName: String = "MessageWithSeverity"

    public static func fromString(_ string: String) throws(VError) -> MessageWithSeverity {
        guard string.hasPrefix("{"), string.hasSuffix("}") else {
            throw VError.conversionError(from: string, to: typeName)
        }
        let inner = String(string.dropFirst().dropLast())
        let components = inner.split(separator: "|", maxSplits: 1).map(String.init)
        guard components.count == 2 else {
            throw VError.conversionError(from: string, to: typeName)
        }
        let severity = try Severity.fromString(components[0])
        return MessageWithSeverity(message: components[1], severity: severity)
    }

    public var asString: String {
        "{\(severity.rawValue)|\(message)}"
    }

    public let message: String
    public let severity: Severity
    /// In-memory only (not in `asString`/`fromString`); drives editor highlighting.
    public let target: QualityTarget

    public init(message: String, severity: Severity, target: QualityTarget = .graph) {
        self.message = message
        self.severity = severity
        self.target = target
    }
}
