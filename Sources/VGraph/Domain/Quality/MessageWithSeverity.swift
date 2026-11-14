public enum Severity: String, VProtocol {
    case error
    case warning
    case info
}

/// What a quality message is about. `.graph` has no single source location.
public enum QualityTarget: Sendable, Equatable, Hashable {
    case graph
    case node(String)
    case edge(from: String, to: String)
}

public struct MessageWithSeverity: VProtocol {
    public let message: String
    public let severity: Severity
    /// Drives editor highlighting.
    public let target: QualityTarget

    public init(message: String, severity: Severity, target: QualityTarget = .graph) {
        self.message = message
        self.severity = severity
        self.target = target
    }
}
