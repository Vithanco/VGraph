// Shared infrastructure for MCP tools: logging and application setup.

import App
import Foundation
import VGraph

/// Logger that writes to stderr (stdout is reserved for MCP JSON-RPC)
public struct StderrLogger: ForLogMessages {
    public let level: LogLevel
    private let sink: LogSink

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        sink: @escaping LogSink = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
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
        sink("[vgraph-mcp] " + line)
    }
}

/// VGraphApplication configured for MCP (logs to stderr, not stdout).
///
/// Only the logger is MCP-specific (stderr, because stdout carries JSON-RPC);
/// the wiring is `NativePorts`, shared with the CLI, the WASM editor and the
/// tests. This root previously assembled its own pipeline and had drifted — it
/// applied folding but *not* the notation phase, so MCP rendered
/// notations (and `vnotation` blocks) differently from everything else.
public typealias VGraphMCPApp = VGraphApplication<NativePorts<StderrLogger>>

extension VGraphMCPApp {
    public init(forMCP: Void = ()) {
        self.init(logger: StderrLogger())
    }

    public init(logger: StderrLogger) {
        self.init(ports: NativePorts(logger: logger))
    }
}
