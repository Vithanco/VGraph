public protocol VForHighlightVGL {

    /// Parse-free highlight for the current keystroke; never fails.
    func lexicalHighlightHTML(source: String) -> String

    /// Parse-backed highlight: identifier roles, unknown types flagged, and (when
    /// a `report` is given) its locatable errors/warnings overlaid as tooltip
    /// markers. On a syntax error, colors lexically and marks the offending token.
    func semanticHighlightHTML(source: String, report: QualityReport?) -> String
}
