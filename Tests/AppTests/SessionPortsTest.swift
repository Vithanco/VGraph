// The session and the app must go through the ports they were handed.

import Testing
import VGLanguage
import VGraph

@testable import App

/// Counts parse calls so a test can prove text is routed through the injected
/// parser rather than one the callee built for itself.
final class CountingParser: ForParseAGraph {
    private let inner = VGraphParser(logger: NoOpLogger())
    private(set) var parseCount = 0

    func parse(source: String) throws(VError) -> VGraph {
        parseCount += 1
        return try inner.parse(source: source)
    }
}

/// Parse-only ports with the parse port swapped for a spy.
struct SpyPorts: AppPorts {
    let logger = NoOpLogger()
    let parser: CountingParser
    let highlighter = NullHighlighter()
    let renderer = NullRenderer()
    let layoutEngine = NullLayoutEngine()
    let documentExporter = VGLExporter()
    let fragments = VGLFragments(logger: NoOpLogger())
}

/// Answers a fixed string, so a session that exports through anything but the
/// injected exporter cannot produce it.
struct SentinelExporter: ForExportAGraph {
    static let text = "exported by the injected exporter"
    func export(graph: VGraph) throws(VError) -> String { Self.text }
}

/// Recovers a fixed string, so a session that answers `sourceVGL` any way but
/// through the injected renderer cannot produce it.
struct SentinelRenderer: ForRenderAGraph {
    static let source = "recovered by the injected renderer"
    func sourceVGL(from rendered: String) -> String? { Self.source }
    func draw(graph: VGraph, darkMode: Bool, interactive: Bool) throws(VError) -> Never {
        throw VError.notImplemented("sentinel draws nothing")
    }
    func serialise(_ drawing: Never, sourceVGL: String?) -> String {}
}

struct SentinelRendererPorts: AppPorts {
    let logger = NoOpLogger()
    let parser = VGraphParser(logger: NoOpLogger())
    let highlighter = NullHighlighter()
    let renderer = SentinelRenderer()
    let layoutEngine = NullLayoutEngine()
    let documentExporter = VGLExporter()
    let fragments = VGLFragments(logger: NoOpLogger())
}

struct SentinelExporterPorts: AppPorts {
    let logger = NoOpLogger()
    let parser = VGraphParser(logger: NoOpLogger())
    let highlighter = NullHighlighter()
    let renderer = NullRenderer()
    let layoutEngine = NullLayoutEngine()
    let documentExporter = SentinelExporter()
    let fragments = VGLFragments(logger: NoOpLogger())
}

/// Succeeds without doing anything, so a render can reach the renderer.
struct IdentityLayoutEngine: ForLayoutAGraph {
    func layout(graph: VGraph) throws(VError) -> VGraph { graph }
}

/// Lays out successfully but cannot render — the configuration that used to trap.
struct NoRendererPorts: AppPorts {
    let logger = NoOpLogger()
    let parser = VGraphParser(logger: NoOpLogger())
    let highlighter = NullHighlighter()
    let renderer = NullRenderer()
    let layoutEngine = IdentityLayoutEngine()
    let documentExporter = VGLExporter()
    let fragments = VGLFragments(logger: NoOpLogger())
}

struct SessionPortsTest {
    let base = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
        }
        """
    let edited = """
        vgraph demo: ConceptMap "Demo" {
          node a: Concept "A";
          node b: Concept "B";
        }
        """

    @Test func sessionParsesThroughTheInjectedParser() throws {
        let spy = CountingParser()
        let app = VGraphApplication(ports: SpyPorts(parser: spy))

        let session = try app.makeSession(vgl: base)
        #expect(spy.parseCount == 1)

        try session.textEdited(vgl: edited)
        #expect(spy.parseCount == 2)

        try session.replaceDocument(vgl: base)
        #expect(spy.parseCount == 3)
    }

    @Test func sessionExportsThroughTheInjectedExporter() throws {
        let session = try VGraphApplication(ports: SentinelExporterPorts()).makeSession(vgl: base)
        #expect(try session.exportVGL() == SentinelExporter.text)
    }

    @Test func sessionRecoversSourceThroughTheInjectedRenderer() throws {
        let session = try VGraphApplication(ports: SentinelRendererPorts()).makeSession(vgl: base)
        #expect(session.sourceVGL(from: "x") == SentinelRenderer.source)
        #expect(try makeTestSession(vgl: base).sourceVGL(from: "x") == nil)
    }

    @Test func renderingWithoutARendererThrowsInsteadOfTrapping() throws {
        let app = VGraphApplication(ports: NoRendererPorts())

        #expect(throws: VError.notImplemented("No renderer available")) {
            _ = try app.renderGraph(base)
        }
    }

    /// Highlighting is presentation: its absence returns the source unchanged
    /// rather than failing the way a missing renderer does.
    @Test func missingHighlighterReturnsSourceUnchanged() throws {
        let app = VGraphApplication(ports: SpyPorts(parser: CountingParser()))
        #expect(app.highlightHTML(base, semantic: false) == base)
    }
}
