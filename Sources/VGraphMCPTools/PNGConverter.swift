import Foundation

public enum PNGResult: Sendable, Equatable {
    case png(Data)
    case unavailable
    case timedOut
    case outputTooLarge
    case failed
}

/// At most `limit` conversions at once. Each one holds an rsvg-convert process and
/// its whole bitmap in memory, and the instance has 1 GiB.
public actor ConcurrencyGate {
    private let limit: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    deinit {
        for waiter in waiters { waiter.resume() }
    }

    public func acquire() async {
        if running < limit {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Hands the place straight to the longest waiter, so it cannot be overtaken.
    public func release() {
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

/// Converts SVG to PNG with rsvg-convert, within `MCPLimits`.
public final class PNGConverter: Sendable {
    private let executable: String?
    private let limits: MCPLimits
    private let gate: ConcurrencyGate

    public init(executable: String? = nil, limits: MCPLimits = .standard) {
        self.executable = executable ?? Self.findRsvgConvert()
        self.limits = limits
        self.gate = ConcurrencyGate(limit: limits.pngConcurrency)
        _ = Self.ignoreBrokenPipes
    }

    public static let shared = PNGConverter()

    /// A child that exits before reading its input must not kill the server.
    private static let ignoreBrokenPipes: Void = { signal(SIGPIPE, SIG_IGN) }()

    /// rsvg-convert refuses a bitmap longer than this on either side, whatever its area.
    private static let maxSidePixels = 32767.0

    /// Our SVG is sized in plain pixels, which rsvg takes as they are (`--dpi` has no
    /// effect), so the bitmap is the SVG's own size. Past `maxPixels` in area, or
    /// rsvg's limit on one side, `--zoom` shrinks it by whichever rule is stricter.
    static func arguments(forSVG svg: String, limits: MCPLimits) -> [String] {
        guard let (width, height) = size(of: svg), width > 0, height > 0 else { return ["--format=png"] }
        let byArea = (Double(limits.maxPixels) / (width * height)).squareRoot()
        let bySide = maxSidePixels / max(width, height)
        let zoom = (min(1, byArea, bySide) * 10_000).rounded(.down) / 10_000
        return zoom < 1 ? ["--format=png", "--zoom=\(max(zoom, 0.0001))"] : ["--format=png"]
    }

    private static func size(of svg: String) -> (Double, Double)? {
        guard let open = svg.range(of: "<svg"), let close = svg[open.upperBound...].firstIndex(of: ">") else {
            return nil
        }
        let tag = String(svg[open.upperBound..<close])
        func number(_ attribute: String, in text: String) -> Double? {
            guard let match = text.range(of: #"\b\#(attribute)="\s*([0-9.]+)"#, options: .regularExpression) else {
                return nil
            }
            return Double(text[match].filter { $0.isNumber || $0 == "." })
        }
        if let width = number("width", in: tag), let height = number("height", in: tag) {
            return (width, height)
        }
        guard let box = tag.range(of: #"viewBox="[^"]*""#, options: .regularExpression) else { return nil }
        let parts = tag[box].dropFirst(9).dropLast().split(whereSeparator: { $0 == " " || $0 == "," }).compactMap {
            Double($0)
        }
        return parts.count == 4 ? (parts[2], parts[3]) : nil
    }

    public func convert(_ svg: String, logger: StderrLogger) async -> PNGResult {
        guard let path = executable else { return .unavailable }
        await gate.acquire()
        let result = await run(svg, executable: path, logger: logger)
        await gate.release()
        return result
    }

    private func run(_ svg: String, executable: String, logger: StderrLogger) async -> PNGResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Self.arguments(forSVG: svg, limits: limits)
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        // Not `waitUntilExit`: it waits on a run loop, and on a dispatch worker thread
        // it can miss the exit and block forever, which a conversion that had long
        // finished then reports as timed out.
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            logRSVGFailure(.launch, logger: logger)
            return .failed
        }

        let maxBytes = limits.maxPNGBytes
        let timeout = limits.pngTimeoutSeconds
        return await withCheckedContinuation { continuation in
            let outcome = Outcome(continuation)
            let pid = process.processIdentifier
            let kill: @Sendable () -> Void = { _ = Foundation.kill(pid, SIGKILL) }

            // Threads of their own, not the shared dispatch pool: on Linux that pool
            // does not grow while its workers block, so the reads below could hold
            // up the timeout until the converter exited by itself.
            Thread.detachNewThread {
                if !outcome.waitForDecision(seconds: timeout), outcome.finish(.timedOut) { kill() }
            }
            Thread.detachNewThread {
                try? input.fileHandleForWriting.write(contentsOf: Data(svg.utf8))
                try? input.fileHandleForWriting.close()
            }

            // Not `readDataToEndOfFile`: a killed child's own children can hold
            // the pipe open, and the answer must not wait for them.
            let errorText = Collected(limit: 64 << 10)
            let errorsDone = DispatchSemaphore(value: 0)
            Thread.detachNewThread {
                while true {
                    let chunk = errors.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    _ = errorText.append(chunk)
                }
                errorsDone.signal()
            }
            Thread.detachNewThread {
                let png = Collected(limit: maxBytes)
                while true {
                    let chunk = output.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    if !png.append(chunk) {
                        if outcome.finish(.outputTooLarge) { kill() }
                        return
                    }
                }
                exited.wait()
                _ = errorsDone.wait(timeout: .now() + 1)
                if process.terminationStatus != 0 {
                    if outcome.finish(.failed) {
                        logRSVGFailure(
                            .exited(status: process.terminationStatus, stderr: errorText.string), logger: logger)
                    }
                } else {
                    _ = outcome.finish(png.data.isEmpty ? .failed : .png(png.data))
                }
            }
        }
    }

    private static func findRsvgConvert() -> String? {
        [
            "/usr/bin/rsvg-convert",
            "/usr/local/bin/rsvg-convert",
            "/opt/homebrew/bin/rsvg-convert",
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

/// Resumes its continuation once; later results are dropped.
private final class Outcome: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PNGResult, Never>?
    private let decided = DispatchSemaphore(value: 0)

    init(_ continuation: CheckedContinuation<PNGResult, Never>) {
        self.continuation = continuation
    }

    /// False if nothing decided the result within `seconds`.
    func waitForDecision(seconds: Double) -> Bool {
        decided.wait(timeout: .now() + seconds) == .success
    }

    /// True for the first call, which is the one that decided the result.
    func finish(_ result: PNGResult) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        decided.signal()
        pending.resume(returning: result)
        return true
    }
}

private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var bytes = Data()

    init(limit: Int) { self.limit = limit }

    /// False once more than `limit` bytes have been offered.
    func append(_ chunk: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard bytes.count + chunk.count <= limit else { return false }
        bytes.append(chunk)
        return true
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return bytes
    }

    var string: String { String(data: data, encoding: .utf8) ?? "<unreadable>" }
}
