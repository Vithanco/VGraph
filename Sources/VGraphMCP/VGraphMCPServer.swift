// MCP server for VGraph — exposes notation-specific tools for creating diagrams.
// Communicates via stdin/stdout using the MCP (Model Context Protocol).

import Foundation
import Logging
import MCP
import VGraphMCPTools

@main
struct VGraphMCPServer {
    /// Write a debug message to stderr (safe — does not corrupt the JSON-RPC stream on stdout)
    private static func debug(_ message: String) {
        FileHandle.standardError.write(Data("[vgraph-mcp DEBUG] \(message)\n".utf8))
    }

    static func main() async throws {
        debug("main() entered")

        // Log to stderr to avoid corrupting the JSON-RPC stream on stdout
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "vgraph-mcp")
        debug("logging configured")

        let server = Server(
            name: "vgraph",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )
        debug("server created")

        await server.withMethodHandler(ListTools.self) { _ in
            debug("ListTools handler called")
            return .init(tools: VGraphTools.all.map(\.definition))
        }
        debug("ListTools handler registered")

        await server.withMethodHandler(CallTool.self) { params in
            debug("CallTool handler called for: \(params.name)")
            guard let tool = VGraphTools.all.first(where: { $0.definition.name == params.name })
            else {
                return .init(
                    content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            return await tool.handle(params)
        }
        debug("CallTool handler registered")

        let transport = StdioTransport(logger: logger)
        debug("transport created, starting server...")
        try await server.start(transport: transport)
        debug("server started, waiting for completion...")

        // Keep the process alive until the transport disconnects
        await server.waitUntilCompleted()
        debug("server completed, exiting")
    }
}
