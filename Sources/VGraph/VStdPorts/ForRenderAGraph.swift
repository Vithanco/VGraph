/// Outbound port for rendering graphs
/// Implementations will provide different rendering engines (e.g., Graphviz dot, neato, circo)
public protocol VForRenderAGraph {
    ///   - sourceVGL: The graph's VGL text, to be carried inside the rendered
    ///     output so it can be recovered from the artefact alone (Save SVG /
    ///     extraction). *How* — SVG `<metadata>`, a PNG text chunk, not at all —
    ///     is the adapter's business; callers only promise it is semantically
    ///     the same graph. `nil` renders without it.
    ///   - darkMode: When true, render with the dark palette (per Diagram Style
    ///     Guide §11). Conforming types should declare this parameter with a
    ///     default of `false` so light-mode callers can omit it.
    ///   - interactive: When true, emit the chrome only a live editor can use —
    ///     today the [[Edge end]] handles a [[Reattach]] drag is grabbed by. Not
    ///     "who is asking" but *what kind of output*: the renderer still does not
    ///     know its caller. Declare it with a default of `false`, so an export,
    ///     the CLI and the engine stay exactly as they were (ADR-0021).
    func render(graph: VGraph, sourceVGL: String?, darkMode: Bool, interactive: Bool)
        throws(VError) -> String

    /// The `sourceVGL` an earlier `render` carried, recovered from the artefact
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
