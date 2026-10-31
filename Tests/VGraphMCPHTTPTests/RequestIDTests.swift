import Foundation
import Logging
import MCP
import Testing

@testable import VGraphMCPHTTPKit

// Drop `withKnownIssue` once an SDK release containing swift-sdk#298 is pinned.

private actor Arrivals {
    private(set) var count = 0
    func arrive() { count += 1 }
}

private actor Replies {
    private(set) var all: [Reply] = []
    func add(_ reply: Reply) { all.append(reply) }
}

private struct Reply: Decodable, Sendable {
    let id: Value
    let result: CallTool.Result?

    var marker: String? {
        guard case .text(let text, _, _)? = result?.content.first else { return nil }
        return text
    }
}

/// A hosted endpoint whose only tool echoes its `marker` argument once
/// `inFlight` calls have arrived, so the calls are guaranteed to overlap.
private func endpoint(inFlight: Int) async throws -> MCPHTTPApp {
    let arrivals = Arrivals()
    let server = Server(name: "test", version: "1", capabilities: .init(tools: .init(listChanged: false)))
    await server.withMethodHandler(CallTool.self) { params in
        await arrivals.arrive()
        let deadline = Date().addingTimeInterval(2)
        while await arrivals.count < inFlight, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let marker = params.arguments?["marker"]?.stringValue ?? ""
        return .init(content: [.text(text: marker, annotations: nil, _meta: nil)])
    }
    let transport = StatelessHTTPServerTransport(
        validationPipeline: StandardValidationPipeline(validators: []),
        logger: Logger(label: "test"))
    try await server.start(transport: transport)
    return MCPHTTPApp(transport: transport, host: "127.0.0.1", port: 0, logger: Logger(label: "test"))
}

private func call(id: String, marker: String) -> NIOHTTPRequest {
    let body =
        #"{"jsonrpc":"2.0","id":\#(id),"method":"tools/call","#
        + #""params":{"name":"echo","arguments":{"marker":"\#(marker)"}}}"#
    return NIOHTTPRequest(
        method: "POST", uri: "/mcp",
        headers: ["Content-Type": "application/json", "Accept": "application/json"],
        body: Data(body.utf8))
}

/// The replies that arrive within a few seconds. A colliding call never
/// returns, so the calls run as unstructured tasks the test does not wait on.
private func send(_ requests: [NIOHTTPRequest], to app: MCPHTTPApp) async -> [Reply] {
    let replies = Replies()
    for request in requests {
        Task {
            let response = await app.handleHTTPRequest(request)
            if let body = response.body, let reply = try? JSONDecoder().decode(Reply.self, from: body) {
                await replies.add(reply)
            }
        }
    }
    let deadline = Date().addingTimeInterval(4)
    while await replies.all.count < requests.count, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(20))
    }
    return await replies.all
}

private let markers = ["m1", "m2", "m3", "m4"]
private let callsWithID1 = markers.map { call(id: "1", marker: $0) }

@Suite("Hosted MCP endpoint — overlapping tool calls")
struct OverlappingCallsTests {
    @Test("Given four overlapping calls with distinct ids, when the server answers, then every call gets a response")
    func distinctIDs() async throws {
        let app = try await endpoint(inFlight: 4)
        let replies = await send(zip(1..., markers).map { call(id: "\($0)", marker: $1) }, to: app)
        #expect(replies.count == 4)
    }

    @Test("Given four overlapping calls that all use id 1, when the server answers, then every call gets a response")
    func sameIDAllAnswered() async throws {
        let app = try await endpoint(inFlight: 4)
        let replies = await send(callsWithID1, to: app)
        withKnownIssue("swift-sdk#254: a second waiter with the same id replaces the first") {
            #expect(replies.count == 4)
        }
    }

    @Test(
        "Given four overlapping calls that all use id 1 with different markers, when the server answers, then each response carries its own call's marker"
    )
    func sameIDOwnMarker() async throws {
        let app = try await endpoint(inFlight: 4)
        let replies = await send(callsWithID1, to: app)
        withKnownIssue("swift-sdk#265: a response can reach the other call with the same id") {
            #expect(replies.compactMap { $0.marker }.sorted() == markers)
        }
    }

    @Test("Given four overlapping calls that all use id 1, when the server answers, then every response carries id 1")
    func sameIDKeepsID() async throws {
        let app = try await endpoint(inFlight: 4)
        let replies = await send(callsWithID1, to: app)
        #expect(!replies.isEmpty)
        #expect(replies.allSatisfy { $0.id == .int(1) })
    }

    @Test("Given two overlapping calls with id 1 and id \"1\", when the server answers, then both get a response")
    func numberAndStringID() async throws {
        let app = try await endpoint(inFlight: 2)
        let replies = await send([call(id: "1", marker: "m1"), call(id: #""1""#, marker: "m2")], to: app)
        withKnownIssue("swift-sdk#254: ids are compared as strings, so 1 and \"1\" collide") {
            #expect(replies.count == 2)
        }
    }
}

@Suite("Hosted MCP endpoint — one client reusing an id")
struct ReusedIDTests {
    @Test(
        "Given a call with id 1 that has been answered, when the client sends another call with id 1, then it gets a response"
    )
    func sequentialSameID() async throws {
        let app = try await endpoint(inFlight: 1)
        let first = await send([call(id: "1", marker: "m1")], to: app)
        let second = await send([call(id: "1", marker: "m2")], to: app)
        #expect(first.count == 1)
        #expect(second.map { $0.marker } == ["m2"])
    }
}
