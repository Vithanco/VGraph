import App
import VGraph

/// What the editor's details marker says on this element — `"+3"` — or `nil` for
/// no marker: only a [[Detailed node]] that is folded has one. Unfolded, its
/// details are already in sight. Folded, it draws exactly as a node of its type,
/// so the SVG cannot say there is more inside; the editor says it instead, and an
/// exported SVG stays a picture of the model. Style guide §13.
public func detailsMarker(_ id: String, in session: some ForEditAGraphVisually) -> String? {
    guard session.isDetailed(id), session.isFolded(id) else { return nil }
    return "+\(session.detailCount(of: id))"
}
