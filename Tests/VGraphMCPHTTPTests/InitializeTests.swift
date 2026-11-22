import Foundation
import Logging
import MCP
import Testing

@testable import VGraphMCPHTTPKit

private struct InitializeReply: Decodable {
    struct Result: Decodable { let protocolVersion: String }
    struct Failure: Decodable { let message: String }
    let result: Result?
    let error: Failure?
}

private func initialize(_ app: MCPHTTPApp, protocolVersion: String = "2025-06-18") async throws -> InitializeReply {
    let body =
        #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"\#(protocolVersion)","#
        + #""capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#
    let response = await app.handleHTTPRequest(
        NIOHTTPRequest(
            method: "POST", uri: "/mcp",
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            body: Data(body.utf8)))
    return try JSONDecoder().decode(InitializeReply.self, from: try #require(response.body))
}

@Suite("Hosted MCP endpoint — initialize")
struct InitializeTests {
    @Test("Given a client has initialized, when a second client initializes, then it is accepted")
    func secondClient() async throws {
        let app = try await MCPHTTPApp.hosted(host: "127.0.0.1", port: 0, logger: Logger(label: "test"))
        _ = try await initialize(app)
        let second = try await initialize(app)
        #expect(second.error?.message == nil)
        #expect(second.result?.protocolVersion == "2025-06-18")
    }

    @Test("Given a client asks for a protocol version the server lacks, when it initializes, then it is offered the latest")
    func unknownVersion() async throws {
        let app = try await MCPHTTPApp.hosted(host: "127.0.0.1", port: 0, logger: Logger(label: "test"))
        let reply = try await initialize(app, protocolVersion: "1999-01-01")
        #expect(reply.result?.protocolVersion == Version.latest)
    }
}
