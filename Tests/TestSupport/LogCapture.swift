import Foundation

/// A log sink a test can read back.
public final class LogCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    public init() {}

    public var write: @Sendable (String) -> Void {
        { [self] line in
            lock.lock()
            defer { lock.unlock() }
            recorded.append(line)
        }
    }

    public var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    public var text: String { lines.joined(separator: "\n") }
}
