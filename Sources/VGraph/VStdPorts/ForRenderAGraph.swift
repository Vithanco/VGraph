/// Outbound port for rendering graphs
/// Implementations will provide different rendering engines (e.g., Graphviz dot, neato, circo)
public protocol VForRenderAGraph {
    /// What this renderer draws before it serialises — a tree, a display list.
    /// The adapter's to say, so that the core names no rendering vocabulary; a
    /// pane that mounts drawings constrains it to the kind it can mount.
    associatedtype Drawing

    /// The drawing, before it is a string — what a live pane mounts, so that a
    /// redraw patches the elements already shown instead of replacing them
    /// (ADR-0015 F1).
    ///
    ///   - darkMode: When true, render with the dark palette (per Diagram Style
    ///     Guide §11).
    ///   - interactive: When true, emit the chrome only a live editor can use —
    ///     today the [[Edge end]] handles a [[Reattach]] drag is grabbed by. Not
    ///     "who is asking" but *what kind of output*: the renderer still does not
    ///     know its caller (ADR-0021).
    func draw(graph: VGraph, darkMode: Bool, interactive: Bool) throws(VError) -> Drawing

    /// A drawing as an artefact. Apart from `draw` so that a drawing which is
    /// both mounted and saved is drawn once.
    ///
    ///   - sourceVGL: The graph's VGL text, to be carried inside the rendered
    ///     output so it can be recovered from the artefact alone (Save SVG /
    ///     extraction). *How* — SVG `<metadata>`, a PNG text chunk, not at all —
    ///     is the adapter's business; callers only promise it is semantically
    ///     the same graph. `nil` serialises without it.
    func serialise(_ drawing: Drawing, sourceVGL: String?) -> String

    /// The `sourceVGL` an earlier `serialise` carried, recovered from the artefact
    /// alone — what opening a saved diagram as a document depends on.
    ///
    /// The inverse of the promise above, and the same actor's business: only the
    /// renderer that chose how to carry the text knows where to look for it.
    /// `nil` where the artefact carries none, which includes every artefact this
    /// renderer did not write, and every renderer that declines to carry it —
    /// not an error, because a picture that is only a picture is a normal thing
    /// to be handed.
    func sourceVGL(from rendered: String) -> String?
}

extension VForRenderAGraph {
    /// The defaults leave an export, the CLI and the engine exactly as they
    /// were before `interactive` existed (ADR-0021).
    public func render(
        graph: VGraph, sourceVGL: String? = nil, darkMode: Bool = false, interactive: Bool = false
    ) throws(VError) -> String {
        serialise(
            try draw(graph: graph, darkMode: darkMode, interactive: interactive), sourceVGL: sourceVGL)
    }
}
