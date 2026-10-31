// MCP server for VGraph over HTTP (Streamable HTTP, stateless).
// Designed for Cloud Run and similar container platforms.

import Foundation
import Logging
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix
import VGraphMCPTools

// MARK: - NIO HTTP Application

/// Minimal NIO HTTP server that routes requests to the MCP transport.
public actor MCPHTTPApp {
    private let transport: StatelessHTTPServerTransport
    private let host: String
    private let port: Int
    private let logger: Logger
    private let limits: MCPLimits

    public init(
        transport: StatelessHTTPServerTransport, host: String, port: Int, logger: Logger,
        limits: MCPLimits = .standard
    ) {
        self.limits = limits
        self.transport = transport
        self.host = host
        self.port = port
        self.logger = logger
    }

    public func start() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(self.makeHandler())
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        let channel = try await bootstrap.bind(host: host, port: port).get()
        logger.info("VGraph MCP HTTP server listening on \(host):\(port)")
        try await channel.closeFuture.get()
    }

    func makeHandler() -> HTTPHandler {
        HTTPHandler(limits: limits, handle: { await self.handleHTTPRequest($0) })
    }

    // MARK: - Request Routing

    private static let mcpEndpoint = "/mcp"
    private static let healthEndpoint = "/health"

    func handleHTTPRequest(_ request: NIOHTTPRequest) async -> NIOHTTPResponse {
        let path = String(request.uri.split(separator: "?").first ?? Substring(request.uri))

        switch path {
        case Self.healthEndpoint:
            return NIOHTTPResponse(statusCode: 200, headers: ["Content-Type": "text/plain"], body: Data("ok".utf8))

        case Self.mcpEndpoint:
            let mcpRequest = HTTPRequest(
                method: request.method,
                headers: request.headers,
                body: request.body,
                path: path
            )
            let mcpResponse = await transport.handleRequest(mcpRequest)
            return NIOHTTPResponse(
                statusCode: mcpResponse.statusCode,
                headers: mcpResponse.headers,
                body: mcpResponse.bodyData
            )

        default:
            return NIOHTTPResponse(statusCode: 404, headers: ["Content-Type": "text/plain"], body: Data("Not Found".utf8))
        }
    }
}

// MARK: - Framework-agnostic request/response for NIO layer

struct NIOHTTPRequest: Sendable {
    let method: String
    let uri: String
    let headers: [String: String]
    let body: Data?
}

struct NIOHTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?
}

// MARK: - NIO HTTP Handler

/// Bounds what one connection may cost before the MCP transport sees it: the body
/// is capped as it arrives (not after it has been buffered), a silent or stalled
/// connection is closed, and a request that runs past its deadline is answered
/// with 504. The work behind a missed deadline is abandoned, not cancelled:
/// Graphviz layout runs in-process and cannot be stopped, which is why the graph
/// limits bound the input as well.
final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let limits: MCPLimits
    private let handle: @Sendable (NIOHTTPRequest) async -> NIOHTTPResponse

    private struct RequestState {
        var head: HTTPRequestHead
        var bodyBuffer: ByteBuffer
        var refused = false
    }

    private var requestState: RequestState?
    private var idleTimer: Scheduled<Void>?
    private var readTimer: Scheduled<Void>?

    init(limits: MCPLimits, handle: @escaping @Sendable (NIOHTTPRequest) async -> NIOHTTPResponse) {
        self.limits = limits
        self.handle = handle
    }

    func channelActive(context: ChannelHandlerContext) {
        startIdleTimer(context)
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        idleTimer?.cancel()
        readTimer?.cancel()
        context.fireChannelInactive()
    }

    private func timeAmount(_ seconds: Double) -> TimeAmount { .milliseconds(Int64(seconds * 1000)) }

    private func startIdleTimer(_ context: ChannelHandlerContext) {
        idleTimer?.cancel()
        nonisolated(unsafe) let ctx = context
        idleTimer = context.eventLoop.scheduleTask(in: timeAmount(limits.idleTimeoutSeconds)) { ctx.close(promise: nil) }
    }

    private func restartReadTimer(_ context: ChannelHandlerContext) {
        readTimer?.cancel()
        nonisolated(unsafe) let ctx = context
        readTimer = context.eventLoop.scheduleTask(in: timeAmount(limits.readTimeoutSeconds)) { ctx.close(promise: nil) }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            idleTimer?.cancel()
            restartReadTimer(context)
            requestState = RequestState(
                head: head,
                bodyBuffer: context.channel.allocator.buffer(capacity: 0)
            )
            if let announced = head.headers.first(name: "Content-Length").flatMap(Int.init),
                announced > limits.maxBodyBytes
            {
                refuse(context: context)
            }
        case .body(var buffer):
            guard requestState?.refused == false else { return }
            restartReadTimer(context)
            requestState?.bodyBuffer.writeBuffer(&buffer)
            if (requestState?.bodyBuffer.readableBytes ?? 0) > limits.maxBodyBytes {
                refuse(context: context)
            }
        case .end:
            readTimer?.cancel()
            guard let state = requestState, !state.refused else { return }
            requestState = nil

            nonisolated(unsafe) let ctx = context
            Task {
                await self.handleRequest(state: state, context: ctx)
            }
        }
    }

    /// 413, then close: a client that sent too much has no claim on the connection,
    /// and what it still sends is dropped unread.
    private func refuse(context: ChannelHandlerContext) {
        guard let version = requestState?.head.version else { return }
        requestState?.refused = true
        requestState?.bodyBuffer.clear()
        readTimer?.cancel()
        let body = Data("Request body is larger than the limit of \(describe(limits.maxBodyBytes)).".utf8)
        let response = NIOHTTPResponse(
            statusCode: 413, headers: ["Content-Type": "text/plain", "Connection": "close"], body: body)
        write(response, version: version, context: context, thenClose: true)
    }

    private func describe(_ bytes: Int) -> String {
        bytes >= 1 << 20 && bytes % (1 << 20) == 0 ? "\(bytes >> 20) MiB" : "\(bytes) bytes"
    }

    private func handleRequest(state: RequestState, context: ChannelHandlerContext) async {
        var headers: [String: String] = [:]
        for (name, value) in state.head.headers {
            if let existing = headers[name] {
                headers[name] = existing + ", " + value
            } else {
                headers[name] = value
            }
        }

        let body: Data?
        if state.bodyBuffer.readableBytes > 0,
            let bytes = state.bodyBuffer.getBytes(at: 0, length: state.bodyBuffer.readableBytes)
        {
            body = Data(bytes)
        } else {
            body = nil
        }

        let request = NIOHTTPRequest(
            method: state.head.method.rawValue,
            uri: state.head.uri,
            headers: headers,
            body: body
        )

        let response = await Deadline.race(seconds: limits.requestDeadlineSeconds) { await self.handle(request) }
        await writeResponse(response, version: state.head.version, context: context)
    }

    private func writeResponse(
        _ response: NIOHTTPResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext
    ) async {
        write(response, version: version, context: context, thenClose: false)
    }

    private func write(
        _ response: NIOHTTPResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext,
        thenClose: Bool
    ) {
        nonisolated(unsafe) let ctx = context
        let eventLoop = ctx.eventLoop

        let send = {
            var head = HTTPResponseHead(
                version: version,
                status: HTTPResponseStatus(statusCode: response.statusCode)
            )
            for (name, value) in response.headers {
                head.headers.add(name: name, value: value)
            }

            ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)

            if let bodyData = response.body {
                var buffer = ctx.channel.allocator.buffer(capacity: bodyData.count)
                buffer.writeBytes(bodyData)
                ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }

            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            if thenClose { ctx.close(promise: nil) }
        }
        if eventLoop.inEventLoop { send() } else { eventLoop.execute(send) }
    }
}

// MARK: - Request deadline

enum Deadline {
    static let exceeded = NIOHTTPResponse(
        statusCode: 504, headers: ["Content-Type": "text/plain"],
        body: Data("The request took too long and was abandoned. Send a smaller diagram.".utf8))

    /// The operation's answer, or 504 if it has not answered in time. The operation
    /// is left running when it loses.
    static func race(
        seconds: Double, operation: @escaping @Sendable () async -> NIOHTTPResponse
    ) async -> NIOHTTPResponse {
        await withCheckedContinuation { continuation in
            let once = Once(continuation)
            Task { once.resume(await operation()) }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                once.resume(exceeded)
            }
        }
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<NIOHTTPResponse, Never>?

        init(_ continuation: CheckedContinuation<NIOHTTPResponse, Never>) { self.continuation = continuation }

        func resume(_ response: NIOHTTPResponse) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: response)
        }
    }
}
