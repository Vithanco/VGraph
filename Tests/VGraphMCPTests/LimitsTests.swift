import Foundation
import MCP
import TestSupport
import Testing

@testable import VGraphMCPTools

private func texts(_ result: CallTool.Result) -> String {
    result.content.compactMap { if case .text(let text, _, _) = $0 { text } else { nil } }.joined(separator: "\n")
}

private func images(_ result: CallTool.Result) -> Int {
    result.content.filter { if case .image = $0 { true } else { false } }.count
}

private func nodes(_ count: Int) -> String {
    (0..<count).map { "    node n\($0): Concept \"C\($0)\"" }.joined(separator: "\n")
}

/// Edges i->i+1, i->i+2, i->i+3 over `nodeCount` nodes, cut at `count`.
private func edges(_ count: Int, over nodeCount: Int) -> String {
    var lines: [String] = []
    outer: for step in 1...3 {
        for i in 0..<(nodeCount - step) {
            if lines.count == count { break outer }
            lines.append("    edge n\(i) -> n\(i + step)")
        }
    }
    return lines.joined(separator: "\n")
}

private func document(nodes nodeCount: Int, edges edgeCount: Int = 0, views: Int = 0) -> String {
    var vgl = "vgraph test: ConceptMap \"Test\" {\n\(nodes(nodeCount))\n\(edges(edgeCount, over: nodeCount))\n}\n"
    for v in 0..<views { vgl += "\nvview v\(v) \"View \(v)\" {\n    node n0 [fontsize: 1\(v)];\n}\n" }
    return vgl
}

private func padded(_ vgl: String, to bytes: Int) -> String {
    vgl + String(repeating: " ", count: max(0, bytes - vgl.utf8.count))
}

private struct Run {
    let result: CallTool.Result
    let log: String
    var text: String { texts(result) }
    var refusedByLimit: Bool { result.isError == true && text.contains("limit") }
    var laidOut: Bool { log.contains("DOT Output") }
}

private func run(
    _ vgl: String, limits: MCPLimits = .standard, tool: any ToolUnderTest = ConceptMapUnderTest()
) async -> Run {
    let capture = LogCapture()
    let logger = StderrLogger(environment: ["VGRAPH_LOG_LEVEL": "debug"], sink: capture.write)
    let result = await tool.call(vgl, logger: logger, limits: limits)
    return Run(result: result, log: capture.text)
}

private protocol ToolUnderTest: Sendable {
    func call(_ vgl: String, logger: StderrLogger, limits: MCPLimits) async -> CallTool.Result
}

private struct ConceptMapUnderTest: ToolUnderTest {
    func call(_ vgl: String, logger: StderrLogger, limits: MCPLimits) async -> CallTool.Result {
        await ConceptMapTool.handle(
            .init(name: ConceptMapTool.name, arguments: ["vgl": .string(vgl)]), logger: logger, limits: limits)
    }
}

private struct GenericTool<T: VGraphTool>: ToolUnderTest {
    let type: T.Type
    func call(_ vgl: String, logger: StderrLogger, limits: MCPLimits) async -> CallTool.Result {
        await T.handle(.init(name: T.name, arguments: ["vgl": .string(vgl)]), logger: logger, limits: limits)
    }
}

@Suite("Graph limits — an MCP render tool")
struct GraphLimitTests {
    private let standard = MCPLimits.standard

    @Test("Given VGL one byte over the length limit, when rendered, then it is refused with an error naming the VGL length limit, and no layout runs")
    func vglTooLong() async {
        let r = await run(padded(document(nodes: 2), to: standard.maxVGLBytes + 1))
        #expect(r.refusedByLimit)
        #expect(r.text.contains("VGL length limit"))
        #expect(!r.laidOut)
    }

    @Test("Given VGL exactly at the length limit, when rendered, then it renders")
    func vglAtLimit() async {
        let r = await run(padded(document(nodes: 2), to: standard.maxVGLBytes))
        #expect(!r.refusedByLimit)
        #expect(r.laidOut)
    }

    @Test("Given 501 nodes, when rendered, then it is refused with an error naming the node limit, the count and the limit")
    func tooManyNodes() async {
        let r = await run(document(nodes: standard.maxNodes + 1))
        #expect(r.refusedByLimit)
        #expect(r.text.contains("node limit"))
        #expect(r.text.contains("501"))
        #expect(r.text.contains("500"))
    }

    @Test("Given 1001 edges, when rendered, then it is refused with an error naming the edge limit")
    func tooManyEdges() async {
        let r = await run(document(nodes: 400, edges: standard.maxEdges + 1))
        #expect(r.refusedByLimit)
        #expect(r.text.contains("edge limit"))
    }

    @Test("Given 9 views, when rendered, then it is refused before any view is laid out")
    func tooManyViews() async {
        let r = await run(document(nodes: 3, views: standard.maxViews + 1))
        #expect(r.refusedByLimit)
        #expect(r.text.contains("view limit"))
        #expect(!r.laidOut)
    }

    @Test("Given a document at every limit at once, when rendered, then it renders")
    func atEveryLimit() async {
        var small = MCPLimits.standard
        small.maxNodes = 12
        small.maxEdges = 20
        small.maxViews = 2
        let vgl = document(nodes: 12, edges: 20, views: 2)
        small.maxVGLBytes = vgl.utf8.count
        let r = await run(vgl, limits: small)
        #expect(!r.refusedByLimit)
        #expect(r.laidOut)
    }

    @Test("Given an over-limit document, when sent to each notation tool, then each refuses it")
    func everyToolRefuses() async {
        let tooBig = document(nodes: standard.maxNodes + 1)
        let tools: [any ToolUnderTest] = [
            GenericTool(type: CLDTool.self), GenericTool(type: ConceptMapTool.self),
            GenericTool(type: IBISTool.self), GenericTool(type: TimelineTool.self),
        ]
        for tool in tools {
            #expect(await run(tooBig, tool: tool).refusedByLimit)
        }
    }

    @Test("Given a small document, when rendered, then the answer is what it is today")
    func smallDocument() async {
        let r = await run(document(nodes: 3, edges: 2))
        #expect(!r.refusedByLimit)
        #expect(images(r.result) == 1)
    }
}

@Suite("PNG conversion")
struct PNGConversionTests {
    private let logger = StderrLogger(environment: [:], sink: { _ in })

    /// A stand-in for rsvg-convert: it drains stdin, then runs `body`.
    private func script(_ body: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fake-rsvg")
        try "#!/bin/sh\ncat > /dev/null\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }

    private func converter(_ body: String, adjust: (inout MCPLimits) -> Void = { _ in }) throws -> PNGConverter {
        var limits = MCPLimits.standard
        adjust(&limits)
        return PNGConverter(executable: try script(body), limits: limits)
    }

    private func seconds(_ work: () async -> Void) async -> Double {
        let start = Date()
        await work()
        return Date().timeIntervalSince(start)
    }

    @Test("Given a converter that never exits, when the timeout passes, then it is killed and conversion fails")
    func neverExits() async throws {
        let png = try converter("sleep 3") { $0.pngTimeoutSeconds = 0.3 }
        var result: PNGResult?
        let elapsed = await seconds { result = await png.convert("<svg/>", logger: logger) }
        #expect(result == .timedOut)
        #expect(elapsed < 2)
    }

    @Test("Given a timeout, when the tool answers, then the error says the conversion timed out")
    func toolReportsTimeout() async throws {
        let png = try converter("sleep 3") { $0.pngTimeoutSeconds = 0.3 }
        let r = await ConceptMapTool.handle(
            .init(name: ConceptMapTool.name, arguments: ["vgl": .string(document(nodes: 2))]),
            logger: logger, png: png)
        #expect(r.isError == true)
        #expect(texts(r).contains("timed out"))
    }

    @Test("Given an SVG larger than 25 megapixels, when converted, then it is scaled down to fit")
    func scaledDown() {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="10000" height="10000"></svg>"#
        let args = PNGConverter.arguments(forSVG: svg, limits: .standard)
        #expect(args == ["--format=png", "--zoom=0.5"])
    }

    @Test("Given an SVG within the cap, when converted, then it renders at its own size")
    func withinCap() {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600"></svg>"#
        #expect(
            PNGConverter.arguments(forSVG: svg, limits: .standard)
                == ["--format=png"])
    }

    @Test(
        "Given an SVG under 25 megapixels but longer than 32767 pixels on one side, when converted, then it is scaled down so the longest side fits")
    func longSideScaledDown() {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="40000" height="400"></svg>"#
        let args = PNGConverter.arguments(forSVG: svg, limits: .standard)
        #expect(args == ["--format=png", "--zoom=0.8191"])
    }

    @Test("Given an SVG over both the area cap and the side limit, when converted, then the stricter scale applies")
    func stricterScaleWins() {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="30000" height="30000"></svg>"#
        let args = PNGConverter.arguments(forSVG: svg, limits: .standard)
        #expect(args == ["--format=png", "--zoom=0.1666"])
    }

    @Test("Given an SVG whose longest side is just within the limit, when converted, then it renders at its own size")
    func sideJustWithinLimit() {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="21844" height="500"></svg>"#
        #expect(
            PNGConverter.arguments(forSVG: svg, limits: .standard)
                == ["--format=png"])
    }

    @Test("Given a chain of 500 nodes and 1000 edges, when rendered, then a PNG comes back")
    func chainAtTheLimitsRenders() async {
        let standard = MCPLimits.standard
        let r = await run(document(nodes: standard.maxNodes, edges: standard.maxEdges))
        #expect(r.result.isError != true, "\(r.text)")
        #expect(images(r.result) == 1)
    }

    @Test("Given a converter writing more than the output cap, when it passes, then reading stops and conversion fails")
    func outputCap() async throws {
        let png = try converter("head -c 5000000 /dev/zero") { $0.maxPNGBytes = 1_000_000 }
        #expect(await png.convert("<svg/>", logger: logger) == .outputTooLarge)
    }

    @Test("Given the concurrency limit reached, when another conversion arrives, then it waits")
    func waits() async {
        let gate = ConcurrencyGate(limit: 2)
        await gate.acquire()
        await gate.acquire()
        let started = Flag()
        let waiter = Task {
            await gate.acquire()
            await started.set()
        }
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await !started.value)
        waiter.cancel()
    }

    @Test("Given a waiting conversion, when a running one finishes, then it starts")
    func startsAfterRelease() async {
        let gate = ConcurrencyGate(limit: 1)
        await gate.acquire()
        let started = Flag()
        Task {
            await gate.acquire()
            await started.set()
        }
        try? await Task.sleep(for: .milliseconds(100))
        await gate.release()
        try? await Task.sleep(for: .milliseconds(300))
        #expect(await started.value)
    }

    @Test("Given a converter that fails or is killed, when it ends, then its place is freed")
    func slotFreed() async throws {
        let failing = try converter("exit 3") { $0.pngConcurrency = 1 }
        let hanging = try converter("sleep 3") {
            $0.pngConcurrency = 1
            $0.pngTimeoutSeconds = 0.3
        }
        var results: [PNGResult] = []
        let elapsed = await seconds {
            for png in [failing, failing, hanging, hanging, failing] {
                results.append(await png.convert("<svg/>", logger: logger))
            }
        }
        #expect(results == [.failed, .failed, .timedOut, .timedOut, .failed])
        #expect(elapsed < 4)
    }
}

private actor Flag {
    private(set) var value = false
    func set() { value = true }
}
