// MCP server for VGraph over HTTP (Streamable HTTP, stateless).
// Designed for Cloud Run and similar container platforms.

import Foundation
import Logging
import MCP
import VGraphMCPHTTPKit
import VGraphMCPTools

@main
struct VGraphMCPHTTPServer {
    static func main() async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "vgraph-mcp-http")

        let port = ProcessInfo.processInfo.environment["PORT"].flatMap(Int.init) ?? 8080
        let host = "0.0.0.0"

        let server = Server(
            name: "vgraph",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: VGraphTools.all.map(\.definition))
        }

        await server.withMethodHandler(CallTool.self) { params in
            guard let tool = VGraphTools.all.first(where: { $0.definition.name == params.name })
            else {
                return .init(
                    content: [
                        .text(
                            text: "Unknown tool: \(params.name)",
                            annotations: nil,
                            _meta: nil)
                    ],
                    isError: true
                )
            }
            return await tool.handle(params)
        }

        // Create stateless HTTP transport with cloud-safe validation
        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: [
                OriginValidator.disabled,
                AcceptHeaderValidator(mode: .jsonOnly),
                ContentTypeValidator(),
                ProtocolVersionValidator(),
            ]),
            logger: logger
        )

        try await server.start(transport: transport)

        let app = MCPHTTPApp(
            transport: transport,
            host: host,
            port: port,
            logger: logger
        )

        logger.info("Starting VGraph MCP HTTP server on \(host):\(port)")
        try await app.start()
    }
}
