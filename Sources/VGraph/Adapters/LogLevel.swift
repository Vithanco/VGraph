public typealias LogSink = @Sendable (String) -> Void

public enum LogLevel: Int, Sendable, Comparable {
    case debug, info, warn, error

    public static let environmentKey = "VGRAPH_LOG_LEVEL"

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Lenient on purpose: a typo in an env var must not take the server down,
    /// and the fallback is the level that leaks least.
    public init(setting: String?) {
        switch setting?.lowercased() {
        case "debug": self = .debug
        case "info": self = .info
        case "error": self = .error
        default: self = .warn
        }
    }

    public init(environment: [String: String]) {
        self.init(setting: environment[Self.environmentKey])
    }
}
