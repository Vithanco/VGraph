import TestSupport
import Testing
import VGraph

@testable import vgraph_cli

@Suite("CLI log level")
struct CLILoggerTests {
    @Test("Given no VGRAPH_LOG_LEVEL, when the CLI app is built, then its logger is at warn")
    func defaultIsWarn() {
        #expect(PrintLogger(environment: [:]).level == .warn)
    }
}
