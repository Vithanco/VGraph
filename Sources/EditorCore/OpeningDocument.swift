//
//  OpeningDocument.swift
//  EditorCore
//
//  What the editor opens with. Three things can have a claim on that — a
//  document named in the URL, whatever the last session left behind, and the
//  built-in demo — and the order between them is a judgement, not a mechanism,
//  so it lives here rather than in the wasm target.
//

public struct OpeningDocument: Sendable, Equatable {
    public let vgl: String
    /// Whether to say so. A restore the reader cannot see is worse than silence:
    /// they go looking for what came back.
    public let restoredDraft: Bool

    public init(vgl: String, restoredDraft: Bool) {
        self.vgl = vgl
        self.restoredDraft = restoredDraft
    }
}

/// Decide what to show at mount.
///
/// - `urlDocument`: VGL the URL carried inline (`?vgl=` or `#vgl=`), if any.
/// - `urlAwaitsFetch`: the URL named a document the *host* is fetching (`?src=`).
///   It is not in hand yet, but it is already spoken for.
/// - `draft`: what the last session left in this browser's storage.
/// - `fallback`: the built-in demo.
///
/// A URL wins over a draft, always: a link has to show the same diagram to
/// everyone who follows it, and the person who followed it did not ask to see
/// what this browser was last doing. A draft only surfaces when nobody asked
/// for anything in particular — which is exactly the case where the last
/// session's work would otherwise be gone.
public func documentToOpen(
    urlDocument: String?,
    urlAwaitsFetch: Bool,
    draft: String?,
    fallback: String
) -> OpeningDocument {
    if let urlDocument, !isBlank(urlDocument) {
        return OpeningDocument(vgl: urlDocument, restoredDraft: false)
    }
    // Nothing to show yet, but something is coming: opening the draft here would
    // put a diagram on screen only to replace it a moment later.
    if urlAwaitsFetch {
        return OpeningDocument(vgl: fallback, restoredDraft: false)
    }
    guard let draft, !isBlank(draft), draft != fallback else {
        return OpeningDocument(vgl: fallback, restoredDraft: false)
    }
    return OpeningDocument(vgl: draft, restoredDraft: true)
}

private func isBlank(_ s: String) -> Bool {
    !s.contains { !$0.isWhitespace }
}
