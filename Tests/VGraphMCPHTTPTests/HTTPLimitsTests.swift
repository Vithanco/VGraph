import Foundation
import Logging
import MCP
import NIOCore
import NIOEmbedded
import NIOHTTP1
import Testing
import VGraphMCPTools

@testable import VGraphMCPHTTPKit

private actor Calls {
    private(set) var bodies: [Int] = []
    func record(_ n: Int) { bodies.append(n) }
}

private func ok(_ request: NIOHTTPRequest) -> NIOHTTPResponse {
    NIOHTTPResponse(statusCode: 200, headers: [:], body: Data("answered".utf8))
}

private func channel(
    limits: MCPLimits = .standard,
    handle: @escaping @Sendable (NIOHTTPRequest) async -> NIOHTTPResponse = { ok($0) }
) async throws -> NIOAsyncTestingChannel {
    let channel = NIOAsyncTestingChannel()
    try await channel.pipeline.addHandler(HTTPHandler(limits: limits, handle: handle))
    try await channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1))
    return channel
}

private func post(length: Int?, chunked: Bool = false) -> HTTPServerRequestPart {
    var headers = HTTPHeaders()
    if let length { headers.add(name: "Content-Length", value: String(length)) }
    if chunked { headers.add(name: "Transfer-Encoding", value: "chunked") }
    return .head(HTTPRequestHead(version: .http1_1, method: .POST, uri: "/mcp", headers: headers))
}

private func chunk(_ size: Int) -> HTTPServerRequestPart {
    .body(ByteBuffer(repeating: UInt8(ascii: "x"), count: size))
}

/// The next response part, or nil if none arrives in time. Polls: waiting on the
/// channel cannot be cancelled, so a missing response would hang the suite.
private func nextResponse(_ channel: NIOAsyncTestingChannel, seconds: Double = 2) async -> HTTPServerResponsePart? {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if let part = try? await channel.readOutbound(as: HTTPServerResponsePart.self) { return part }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
}

private func status(_ channel: NIOAsyncTestingChannel) async -> Int? {
    if case .head(let head)? = await nextResponse(channel) { return Int(head.status.code) }
    return nil
}

private let oneMiB = 1 << 20

@Suite("Body cap — HTTP layer")
struct BodyCapTests {
    @Test("Given a POST announcing 2 MiB, when its head arrives, then 413 is sent before any body is read")
    func announcedTooLarge() async throws {
        let channel = try await channel()
        try await channel.writeInbound(post(length: 2 * oneMiB))
        #expect(await status(channel) == 413)
    }

    @Test("Given a chunked POST with no length, when it passes 1 MiB, then 413 is sent and the rest is not buffered")
    func chunkedTooLarge() async throws {
        let calls = Calls()
        let channel = try await channel(handle: { request in
            await calls.record(request.body?.count ?? 0)
            return ok(request)
        })
        try await channel.writeInbound(post(length: nil, chunked: true))
        for _ in 0..<5 { try await channel.writeInbound(chunk(256 << 10)) }
        #expect(await status(channel) == 413)
        try await channel.writeInbound(chunk(256 << 10))
        try await channel.writeInbound(HTTPServerRequestPart.end(nil))
        try await Task.sleep(for: .milliseconds(100))
        #expect(await calls.bodies.isEmpty)
    }

    @Test("Given a POST of exactly 1 MiB, when received, then it reaches the MCP transport")
    func exactlyAtLimit() async throws {
        let calls = Calls()
        let channel = try await channel(handle: { request in
            await calls.record(request.body?.count ?? 0)
            return ok(request)
        })
        try await channel.writeInbound(post(length: oneMiB))
        for _ in 0..<4 { try await channel.writeInbound(chunk(256 << 10)) }
        try await channel.writeInbound(HTTPServerRequestPart.end(nil))
        #expect(await status(channel) == 200)
        #expect(await calls.bodies == [oneMiB])
    }

    @Test("Given a 413, when read, then its text names the 1 MiB limit")
    func messageNamesLimit() async throws {
        let channel = try await channel()
        try await channel.writeInbound(post(length: 2 * oneMiB))
        _ = await nextResponse(channel)
        var text = ""
        if case .body(.byteBuffer(let buffer))? = await nextResponse(channel) {
            text = String(buffer: buffer)
        }
        #expect(text.contains("1 MiB"))
    }

    @Test("Given a small POST, when received, then it is handled as today")
    func smallPost() async throws {
        let channel = try await channel()
        try await channel.writeInbound(post(length: 5))
        try await channel.writeInbound(chunk(5))
        try await channel.writeInbound(HTTPServerRequestPart.end(nil))
        #expect(await status(channel) == 200)
    }
}

@Suite("Timeouts — HTTP layer")
struct TimeoutTests {
    @Test("Given a connection that sends nothing for the idle limit, when the limit passes, then it is closed")
    func idleClosed() async throws {
        let channel = try await channel()
        try await channel.testingEventLoop.advanceTime(by: .seconds(Int64(MCPLimits.standard.idleTimeoutSeconds) + 1))
        #expect(!channel.isActive)
    }

    @Test("Given a head sent and a body that stalls, when the read limit passes, then it is closed")
    func readStallClosed() async throws {
        let channel = try await channel()
        try await channel.writeInbound(post(length: 100))
        try await channel.testingEventLoop.advanceTime(by: .seconds(Int64(MCPLimits.standard.readTimeoutSeconds) + 1))
        #expect(!channel.isActive)
    }

    @Test("Given a request still running at the deadline, when it passes, then 504 is sent")
    func deadline() async throws {
        var limits = MCPLimits.standard
        limits.requestDeadlineSeconds = 0.2
        let channel = try await channel(
            limits: limits,
            handle: { request in
                try? await Task.sleep(for: .seconds(30))
                return ok(request)
            })
        try await channel.writeInbound(post(length: 0))
        try await channel.writeInbound(HTTPServerRequestPart.end(nil))
        #expect(await status(channel) == 504)
    }

    @Test("Given a request that finishes before the deadline, when answered, then the answer is unchanged")
    func beforeDeadline() async throws {
        let channel = try await channel()
        try await channel.writeInbound(post(length: 0))
        try await channel.writeInbound(HTTPServerRequestPart.end(nil))
        #expect(await status(channel) == 200)
    }

    @Test("Given an over-limit request, when /health is asked next, then it answers ok")
    func healthAfterRefusal() async throws {
        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: []),
            logger: Logger(label: "test"))
        let app = MCPHTTPApp(transport: transport, host: "127.0.0.1", port: 0, logger: Logger(label: "test"))

        let refused = NIOAsyncTestingChannel()
        try await refused.pipeline.addHandler(await app.makeHandler())
        try await refused.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1))
        try await refused.writeInbound(post(length: 2 * oneMiB))
        #expect(await status(refused) == 413)

        let next = NIOAsyncTestingChannel()
        try await next.pipeline.addHandler(await app.makeHandler())
        try await next.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1))
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/health")
        try await next.writeInbound(HTTPServerRequestPart.head(head))
        try await next.writeInbound(HTTPServerRequestPart.end(nil))
        #expect(await status(next) == 200)
    }
}

@Suite("Cloud Run settings")
struct CloudRunSettingsTests {
    private func publishRecipe() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            url.deleteLastPathComponent()
        }
        let justfile = try String(contentsOf: url.appendingPathComponent("justfile"), encoding: .utf8)
        let start = try #require(justfile.range(of: "publish-cloud-run:"))
        let rest = justfile[start.lowerBound...]
        let end = rest.range(of: "\n\n# ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    @Test("publish-cloud-run sets --max-instances")
    func maxInstances() throws { #expect(try publishRecipe().contains("--max-instances")) }

    @Test("publish-cloud-run sets --concurrency")
    func concurrency() throws { #expect(try publishRecipe().contains("--concurrency")) }

    @Test("publish-cloud-run sets --timeout")
    func timeout() throws { #expect(try publishRecipe().contains("--timeout")) }

    @Test("publish-cloud-run sets --cpu-throttling")
    func cpuThrottling() throws { #expect(try publishRecipe().contains("--cpu-throttling")) }

    @Test("Each of those flags has a comment line saying why")
    func flagsAreExplained() throws {
        let lines = try publishRecipe().split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for flag in ["--max-instances", "--concurrency", "--timeout", "--cpu-throttling"] {
            let index = try #require(lines.firstIndex { $0.contains(flag) && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") })
            let above = lines[..<index].reversed().prefix { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            #expect(above.joined().contains(flag), "\(flag) needs a comment above it naming it")
        }
    }

    @Test("The request deadline in the server is shorter than the Cloud Run timeout")
    func deadlineBelowTimeout() throws {
        let recipe = try publishRecipe()
        let value = try #require(recipe.range(of: #"--timeout[= ](\d+)"#, options: .regularExpression))
        let seconds = try #require(Double(recipe[value].filter(\.isNumber)))
        #expect(MCPLimits.standard.requestDeadlineSeconds < seconds)
    }
}
