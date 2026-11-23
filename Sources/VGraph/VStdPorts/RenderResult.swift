// In the core rather than in App because `VForEditAGraphVisually` names it, and
// a port declared in the core cannot reach forward into App for its types.

public struct RenderResult<Drawing> {
    public let svg: String

    /// What `svg` was serialised from, for a pane that mounts it.
    public let drawing: Drawing

    public let qualityReport: QualityReport

    public init(svg: String, drawing: Drawing, qualityReport: QualityReport) {
        self.svg = svg
        self.drawing = drawing
        self.qualityReport = qualityReport
    }
}
