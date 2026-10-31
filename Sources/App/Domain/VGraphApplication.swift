import VGraph

/// The application layer: the use cases, expressed against ports only.
/// Assembling the app means choosing a `Ports` conformer — see `AppPorts`.
public struct VGraphApplication<Ports: AppPorts> {
    /// Internal, not private: `GraphSession` drives the same ports.
    let ports: Ports

    /// App decides *where* in the pipeline layout runs, never how it is computed.
    private let displayPipeline: GraphTransform

    public init(ports: Ports) {
        self.ports = ports
        let engine = ports.layoutEngine
        self.displayPipeline = DisplayPipeline.full(layout: { graph throws(VError) in
            try engine.layout(graph: graph)
        })
    }

    public func parseGraph(_ input: String) throws(VError) -> VGraph {
        try ports.parser.parse(source: input)
    }

    /// A built-in notation's self-describing Markdown, or `nil` for a name the
    /// registry does not know. `title` replaces the notation's name as the H1.
    public func describeNotation(_ notation: String, title: String? = nil) -> String? {
        guard let entry = NotationRegistry.entry(for: notation) else { return nil }
        return NotationMarkdown.render(entry: entry, displayTitle: title ?? notation)
    }

    /// Render targets only — `VGLExporter` refuses the transformed graph this produces.
    public func exportGraph(_ input: String, using exporter: some ForExportAGraph) throws(VError)
        -> String
    {
        let graph = try parseGraph(input)
        let transformedGraph = try TransformStep.pipeline(Notations.extensionSteps)(graph)
        return try exporter.export(graph: transformedGraph)
    }

    /// Re-export VGL in canonical form (`vgraph vgl`).
    public func exportToVGL(_ input: String) throws(VError) -> String {
        try exportDocument(graph: parseGraph(input))
    }

    /// Serialise a graph back to document text, transform-free — deliberately not
    /// `exportGraph`, whose output the document exporter now refuses outright.
    public func exportDocument(graph: VGraph) throws(VError) -> String {
        try ports.documentExporter.export(graph: graph)
    }

    public func layoutGraph(_ input: String) throws(VError) -> VGraph {
        try displayPipeline(try parseGraph(input))
    }

    /// Quality analysis runs on the pre-transform parsed graph. Without a
    /// `view` the model is shown, even in a document that declares views.
    public func renderGraph(_ input: String, view: String? = nil, darkMode: Bool = false) throws(VError)
        -> RenderResult
    {
        let graph = try parseGraph(input)
        return try renderGraph(graph: graph, sourceVGL: input, view: view, darkMode: darkMode)
    }

    /// The VGL an artefact carries, or `nil` if it carries none. Which is not a
    /// failure: a picture that is only a picture is a normal thing to be handed,
    /// unlike being asked to draw with no renderer.
    public func sourceVGL(from rendered: String) -> String? {
        ports.renderer.sourceVGL(from: rendered)
    }

    /// Render an already-parsed graph — the OriginGraph a [[GraphSession]] holds
    /// after a VCommand mutated it — with no round-trip through text.
    public func renderGraph(
        graph: VGraph, sourceVGL: String, view: String? = nil, darkMode: Bool = false, interactive: Bool = false
    ) throws(VError) -> RenderResult {
        let qualityReport = Notations.analyzeQuality(graph: graph)

        let layoutedGraph = try displayPipeline(try graph.displaying(view: view))
        let svg = try ports.renderer.render(
            graph: layoutedGraph, sourceVGL: sourceVGL, darkMode: darkMode,
            interactive: interactive)
        return RenderResult(svg: svg, qualityReport: qualityReport)
    }

    public func analyzeQuality(_ input: String) throws(VError) -> QualityReport {
        Notations.analyzeQuality(graph: try parseGraph(input))
    }

    /// Syntax-highlight HTML for the editor overlay (spans reconstructing `input`
    /// verbatim). `semantic` uses the parse-backed pass; `diagnostics`, if given,
    /// overlays the report's locatable errors/warnings as tooltip markers.
    public func highlightHTML(_ input: String, semantic: Bool, diagnostics: QualityReport? = nil)
        -> String
    {
        semantic
            ? ports.highlighter.semanticHighlightHTML(source: input, report: diagnostics)
            : ports.highlighter.lexicalHighlightHTML(source: input)
    }

    /// `{"svg": "…", "quality": [{"severity": "warning", "message": "…"}]}` — the shape
    /// JavaScript callers read.
    public func renderGraphJSON(_ input: String, view: String? = nil, darkMode: Bool = false) throws(VError)
        -> String
    {
        let result = try renderGraph(input, view: view, darkMode: darkMode)

        // Built by hand to avoid a Codable dependency (Embedded Swift).
        let qualityEntries = result.qualityReport.messages.map { msg in
            "{\"severity\":\"\(msg.severity.rawValue)\",\"message\":\"\(escapeJSON(msg.message))\"}"
        }
        let qualityArray = "[\(qualityEntries.joined(separator: ","))]"
        return "{\"svg\":\"\(escapeJSON(result.svg))\",\"quality\":\(qualityArray)}"
    }

    /// `[{"name": "…", "label": "…"}]` in document order; `label` is omitted when the
    /// view has none.
    public func listViewsJSON(_ input: String) throws(VError) -> String {
        let entries = try parseGraph(input).views.map { view in
            let label = view.label.map { ",\"label\":\"\(escapeJSON($0))\"" } ?? ""
            return "{\"name\":\"\(escapeJSON(view.name))\"\(label)}"
        }
        return "[\(entries.joined(separator: ","))]"
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Build a live [[GraphSession]] over `vgl`, wired to this app's ports.
    /// `versionStore` decides where that session's history lives; `observer` is
    /// told after each settled change (ADR-0013).
    public func makeSession<
        VersionStore: ForStoreDocumentVersions, Observer: ForObserveDocumentChanges
    >(
        vgl: String, versionStore: VersionStore, observer: Observer
    ) throws(VError) -> GraphSession<Ports, VersionStore, Observer> {
        try GraphSession(app: self, vgl: vgl, versionStore: versionStore, observer: observer)
    }

    /// `makeSession(vgl:versionStore:observer:)` for a session nothing watches —
    /// a driver that moves its own views, or none at all.
    public func makeSession<VersionStore: ForStoreDocumentVersions>(
        vgl: String, versionStore: VersionStore
    ) throws(VError) -> GraphSession<Ports, VersionStore, NullDocumentObserver> {
        try makeSession(vgl: vgl, versionStore: versionStore, observer: NullDocumentObserver())
    }

    /// `makeSession(vgl:versionStore:)` with the default in-memory history.
    public func makeSession(vgl: String) throws(VError)
        -> GraphSession<Ports, InMemoryVersionStore, NullDocumentObserver>
    {
        try makeSession(vgl: vgl, versionStore: InMemoryVersionStore())
    }
}
