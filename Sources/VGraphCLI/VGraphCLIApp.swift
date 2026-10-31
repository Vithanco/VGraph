// CLI composition root — logs to stdout, lays out via the in-process C library.

import App
import Foundation
import VGraph

public struct PrintLogger: ForLogMessages {
    public let level: LogLevel
    private let sink: LogSink

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        sink: @escaping LogSink = { print($0) }
    ) {
        self.level = LogLevel(environment: environment)
        self.sink = sink
    }

    public func log(_ message: String) { emit(.info, message) }
    public func warn(_ message: String) { emit(.warn, "WARN: " + message) }
    public func debug(_ message: String) { emit(.debug, "DEBUG: " + message) }
    public func error(_ message: String) { emit(.error, "ERROR: " + message) }

    private func emit(_ messageLevel: LogLevel, _ line: String) {
        guard messageLevel >= level else { return }
        sink(line)
    }
}

/// The CLI's fully-configured application. Only the logger is CLI-specific;
/// the wiring is `NativePorts`, shared with MCP, the WASM editor and the tests.
public typealias VGraphCLIApp = VGraphApplication<NativePorts<PrintLogger>>

extension VGraphCLIApp {
    public init() {
        self.init(ports: NativePorts(logger: PrintLogger()))
    }
}
