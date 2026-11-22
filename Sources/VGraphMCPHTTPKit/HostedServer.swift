import Logging
import MCP
import VGraphMCPTools

extension MCPHTTPApp {
    /// The endpoint Cloud Run serves: every VGraph tool behind the stateless transport.
    public static func hosted(host: String, port: Int, logger: Logger) async throws -> MCPHTTPApp {
        let server = Server(
            name: "vgraph",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: VGraphTools.all.map(\.definition))
        }

        await server.withMethodHandler(CallTool.self) { params in
            guard let tool = VGraphTools.all.first(where: { $0.definition.name == params.name }) else {
                return .init(
                    content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            return await tool.handle(params)
        }

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
        // After start, which installs the SDK's own handler.
        await server.answerEveryInitialize()
        return MCPHTTPApp(transport: transport, host: host, port: port, logger: logger)
    }
}

extension Server {
    /// The SDK's own handler answers `initialize` once per Server, but over a
    /// stateless transport every request may come from a different client, and a
    /// client stops at a refused `initialize`. Nothing here keeps per-client state,
    /// so each one is answered afresh.
    func answerEveryInitialize() async {
        let info = Server.Info(name: name, version: version, title: title)
        let instructions = instructions
        let capabilities = capabilities
        withMethodHandler(Initialize.self) { params in
            Initialize.Result(
                protocolVersion: Version.supported.contains(params.protocolVersion)
                    ? params.protocolVersion : Version.latest,
                capabilities: capabilities,
                serverInfo: info,
                instructions: instructions
            )
        }
    }
}
