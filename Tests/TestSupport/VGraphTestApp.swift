// Test composition root — the native app, wired silently.

import App
import VGraph

/// The application under test: identical to the CLI and MCP roots in every
/// respect except the logger, which discards output instead of writing the
/// full DOT dump of every laid-out graph into the test log.
///
/// Tests used to reach for `VGraphCLIApp`, which meant a single render-based
/// test emitted ~25 lines of `digraph { … }` into the run output, and the CLI's
/// logging choice was load-bearing for test ergonomics. Nothing is lost by
/// swapping it: the logger is injected, so every type downstream is the same.
public typealias VGraphTestApp = VGraphApplication<NativePorts<NoOpLogger>>

extension VGraphTestApp {
    public init() {
        self.init(ports: NativePorts(logger: NoOpLogger()))
    }
}
