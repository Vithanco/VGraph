/// Allows domain logic to log without depending on specific logging implementations
public protocol VForLogMessages: Sendable {
    func log(_ message: String)

    func error(_ message: String)

    func warn(_ message: String)

    func debug(_ message: String)
}

extension VForLogMessages {
    public func error(_ message: String) {
        log("ERROR: " + message)
    }
    public func warn(_ message: String) {
        log("WARN: " + message)
    }
    public func debug(_ message: String) {
        log("DEBUG: " + message)
    }
}
