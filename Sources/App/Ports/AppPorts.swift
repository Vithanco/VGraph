import VGraph

/// The outbound ports `VGraphApplication` and `GraphSession` drive, bundled so
/// they can be one generic parameter: Embedded Swift forbids protocol
/// existentials, so every port must be a compile-time type.
///
/// A conformer is a composition root — the only place allowed to name concrete
/// adapters. Absent capabilities are the `Null*` adapters, never optionals.
public protocol AppPorts {
    associatedtype Logger: ForLogMessages
    associatedtype Parser: ForParseAGraph
    associatedtype Highlighter: ForHighlightVGL
    associatedtype Renderer: ForRenderAGraph
    associatedtype LayoutEngine: ForLayoutAGraph
    associatedtype DocumentExporter: ForExportAGraph

    var logger: Logger { get }
    var parser: Parser { get }
    var highlighter: Highlighter { get }
    var renderer: Renderer { get }
    var layoutEngine: LayoutEngine { get }

    /// The format the document round-trips through, as distinct from the
    /// per-call target formats passed to `exportGraph(_:using:)`.
    var documentExporter: DocumentExporter { get }
}
