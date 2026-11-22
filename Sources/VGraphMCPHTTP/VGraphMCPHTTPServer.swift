// MCP server for VGraph over HTTP (Streamable HTTP, stateless).
// Designed for Cloud Run and similar container platforms.

import Foundation
import Logging
import VGraphMCPHTTPKit

@main
struct VGraphMCPHTTPServer {
    static func main() async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "vgraph-mcp-http")

        let port = ProcessInfo.processInfo.environment["PORT"].flatMap(Int.init) ?? 8080
        let host = "0.0.0.0"
        let app = try await MCPHTTPApp.hosted(host: host, port: port, logger: logger)

        logger.info("Starting VGraph MCP HTTP server on \(host):\(port)")
        try await app.start()
    }
}
