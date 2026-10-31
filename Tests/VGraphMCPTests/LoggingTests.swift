import MCP
import TestSupport
import Testing
import VGraph
import VGraphSVG

@testable import VGraphMCPTools

private let secret = "SECRET-LABEL-7731"

private func logger(_ level: String?, into capture: LogCapture) -> StderrLogger {
    StderrLogger(environment: level.map { [LogLevel.environmentKey: $0] } ?? [:], sink: capture.write)
}

@Suite("Log level — what a logger lets through")
struct LogLevelFilterTests {
    @Test("Given a logger at level warn, when debug is logged, then nothing is written")
    func warnDropsDebug() {
        let capture = LogCapture()
        logger("warn", into: capture).debug("hello")
        #expect(capture.lines.isEmpty)
    }

    @Test("Given a logger at level warn, when info (log) is logged, then nothing is written")
    func warnDropsInfo() {
        let capture = LogCapture()
        logger("warn", into: capture).log("hello")
        #expect(capture.lines.isEmpty)
    }

    @Test("Given a logger at level warn, when warn is logged, then the line is written with a WARN prefix")
    func warnWritesWarn() {
        let capture = LogCapture()
        logger("warn", into: capture).warn("hello")
        #expect(capture.lines == ["[vgraph-mcp] WARN: hello"])
    }

    @Test("Given a logger at level warn, when error is logged, then the line is written with an ERROR prefix")
    func warnWritesError() {
        let capture = LogCapture()
        logger("warn", into: capture).error("hello")
        #expect(capture.lines == ["[vgraph-mcp] ERROR: hello"])
    }

    @Test("Given a logger at level debug, when debug is logged, then the line is written with a DEBUG prefix")
    func debugWritesDebug() {
        let capture = LogCapture()
        logger("debug", into: capture).debug("hello")
        #expect(capture.lines == ["[vgraph-mcp] DEBUG: hello"])
    }

    @Test("Given a logger at level error, when warn is logged, then nothing is written")
    func errorDropsWarn() {
        let capture = LogCapture()
        logger("error", into: capture).warn("hello")
        #expect(capture.lines.isEmpty)
    }
}

@Suite("Level setting — VGRAPH_LOG_LEVEL")
struct LogLevelSettingTests {
    @Test("Given no setting, when the level is read, then it is warn")
    func absent() {
        #expect(LogLevel(setting: nil) == .warn)
    }

    @Test("Given debug, info, warn, error in any letter case, when read, then each gives its level")
    func known() {
        #expect(LogLevel(setting: "debug") == .debug)
        #expect(LogLevel(setting: "INFO") == .info)
        #expect(LogLevel(setting: "Warn") == .warn)
        #expect(LogLevel(setting: "error") == .error)
    }

    @Test("Given an unrecognised value, when read, then it is warn")
    func unknown() {
        #expect(LogLevel(setting: "verbose") == .warn)
    }

    @Test("Given an empty value, when read, then it is warn")
    func empty() {
        #expect(LogLevel(setting: "") == .warn)
    }
}

@Suite("Default in the binary")
struct LogDefaultTests {
    @Test("Given no VGRAPH_LOG_LEVEL, when the MCP app is built, then its logger is at warn")
    func mcpDefaultIsWarn() {
        #expect(StderrLogger(environment: [:]).level == .warn)
    }
}

@Suite("Rendering — a document with the label SECRET-LABEL-7731")
struct LogLeakTests {
    private func render(_ vgl: String, level: String?) async -> String {
        let capture = LogCapture()
        _ = await ConceptMapTool.handle(
            .init(name: ConceptMapTool.name, arguments: ["vgl": .string(vgl)]),
            logger: logger(level, into: capture))
        return capture.text
    }

    // The title and group/edge labels reach the Graphviz source; node labels do not.
    private let labelled = """
        vgraph test: ConceptMap "\(secret)" {
            node a: Concept "\(secret)"
            node b: Concept "Cat"
            node r1: Relation "is a"
            edge a -> r1
            edge r1 -> b
        }
        """

    @Test("Given the default level, when it is rendered, then nothing logged contains the label")
    func defaultLevelIsSilent() async {
        #expect(!(await render(labelled, level: nil)).contains(secret))
    }

    @Test("Given debug, when it is rendered, then the logged Graphviz source contains the label")
    func debugShowsDot() async {
        #expect((await render(labelled, level: "debug")).contains(secret))
    }

    @Test("Given a two-view document, at the default level, when rendered, then nothing logged contains the label")
    func viewsAreSilent() async {
        let vgl =
            labelled + """


                vview first "First View" {
                    node b [fontsize: 16];
                }

                vview second "Second View" {
                    node b [fontsize: 20];
                }
                """
        #expect(!(await render(vgl, level: nil)).contains(secret))
    }

    @Test("Given a node, a group and an edge each labelled SECRET-LABEL-7731, when rendered at the default level, then no log line contains it")
    func everyKindIsSilent() async {
        let vgl = """
            vgraph test: ConceptMap "Test?" {
                group g1 "\(secret)" {
                    node a: Concept "\(secret)"
                }
                node b: Concept "Cat"
                edge a -> b "\(secret)"
            }
            """
        #expect(!(await render(vgl, level: nil)).contains(secret))
    }
}

@Suite("Warnings — identifiers, never labels")
struct LogWarningTests {
    private func parseWarnings(_ vgl: String) throws -> String {
        let capture = LogCapture()
        _ = try VGraphMCPApp(logger: logger(nil, into: capture)).parseGraph(vgl)
        return capture.text
    }

    private let unknownType = """
        vgraph test: ConceptMap "Test?" {
            node n7: NoSuchType "\(secret)"
        }
        """

    @Test(
        "Given a node of an unknown type with the label SECRET-LABEL-7731, when parsed at the default level, then a warning names the node id and the type name"
    )
    func warningNamesIdentifiers() throws {
        let text = try parseWarnings(unknownType)
        #expect(text.contains("n7"))
        #expect(text.contains("NoSuchType"))
    }

    @Test(
        "Given a node of an unknown type with the label SECRET-LABEL-7731, when parsed at the default level, then the warning does not contain the label"
    )
    func warningOmitsLabel() throws {
        #expect(!(try parseWarnings(unknownType)).contains(secret))
    }
}

@Suite("PNG conversion failure")
struct RSVGFailureLogTests {
    @Test(
        "Given rsvg-convert exits with status 1 and an error text quoting a label, when it is logged at the default level, then the line has the status and not the text"
    )
    func exitLogsStatusOnly() {
        let capture = LogCapture()
        logRSVGFailure(.exited(status: 1, stderr: "bad text \(secret)"), logger: logger(nil, into: capture))
        #expect(capture.text.contains("1"))
        #expect(!capture.text.contains(secret))
    }

    @Test("Given the same failure, when logged at debug, then the line includes the text")
    func exitLogsTextAtDebug() {
        let capture = LogCapture()
        logRSVGFailure(.exited(status: 1, stderr: "bad text \(secret)"), logger: logger("debug", into: capture))
        #expect(capture.text.contains(secret))
    }

    @Test("Given rsvg-convert cannot be launched, when it is logged at the default level, then a warning says so")
    func launchFailureWarns() {
        let capture = LogCapture()
        logRSVGFailure(.launch, logger: logger(nil, into: capture))
        #expect(capture.text.contains("WARN"))
        #expect(capture.text.contains("rsvg-convert"))
    }
}
