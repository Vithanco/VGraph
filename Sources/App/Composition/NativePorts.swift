import VGLanguage
import VGraph
import VGraphSVG
import VGraphvizLib

/// Every port wired to its real adapter. Shared by the CLI, MCP, the WASM
/// editor and the tests — only the logger differs, and one shared wiring is
/// what stops them drifting apart.
public struct NativePorts<Logger: ForLogMessages>: AppPorts {
    public let logger: Logger
    public let parser: VGraphParser<Logger>
    public let highlighter: VGraphParser<Logger>
    public let renderer: VSVGRenderer<Logger>
    public let layoutEngine: GraphvizLibLayoutEngine<Logger>
    public let documentExporter: VGLExporter

    public init(logger: Logger) {
        // One instance for both ports: semantic highlighting reuses its parse.
        let parser = VGraphParser(logger: logger)
        self.logger = logger
        self.parser = parser
        self.highlighter = parser
        self.renderer = VSVGRenderer(logger: logger)
        self.layoutEngine = GraphvizLibLayoutEngine(logger: logger)
        self.documentExporter = VGLExporter()
    }
}

/// Parsing, export, history and quality analysis, with no rendering or layout —
/// for hosts that only handle documents as text.
public struct ParseOnlyPorts<Logger: ForLogMessages>: AppPorts {
    public let logger: Logger
    public let parser: VGraphParser<Logger>
    public let highlighter: VGraphParser<Logger>
    public let renderer = NullRenderer()
    public let layoutEngine = NullLayoutEngine()
    public let documentExporter = VGLExporter()

    public init(logger: Logger) {
        let parser = VGraphParser(logger: logger)
        self.logger = logger
        self.parser = parser
        self.highlighter = parser
    }
}
