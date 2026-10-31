extension TransformStep.Id {
    public static var boundaryChrome: Self { "boundaryChrome" }
}

/// Stamps each *unfolded* typed group's boundary chrome onto its loose
/// `Attributes.Group.*` so the SVG renderer draws a C4 (or other) boundary with the
/// right dashed border, colour and fill — without the renderer needing to know about
/// `GroupType`/`GroupStyle`. It is the unfolded-face counterpart of
/// `FoldingLayoutStep`, which stamps the *folded* face onto the collapsed proxy node.
///
/// Runs after folding: a folded group has already become a `FoldedGroup` node and is
/// no longer a group, so only the boundaries that remain visible are stamped.
///
/// `resolvedBoundaryChrome` supplies the chrome: a detailed node's node type, or a
/// plain group's override or `GroupType`. Groups without one keep the generic cluster look.
public func applyBoundaryChromeStep(to graph: VGraph) throws(VError) -> VGraph {
    var result = graph
    for group in graph.groups {
        guard let chrome = graph.resolvedBoundaryChrome(group) else { continue }

        result = try result.stamping(
            group: group, attribute: Attributes.Group.cornerRadius.attribute(chrome.cornerRadius))
        result = try result.stamping(
            group: group, attribute: Attributes.Group.borderDash.attribute(chrome.borderDash))
        // Loose group colours are VColour; resolve the semantic light hex. The renderer
        // honours a non-default group colour as an explicit override in both themes.
        result = try result.stamping(
            group: group,
            attribute: Attributes.Group.borderColor.attribute(chrome.borderColor.resolve(darkMode: false)))
        result = try result.stamping(
            group: group,
            attribute: Attributes.Group.backgroundColor.attribute(chrome.fill.resolve(darkMode: false)))
    }
    return result
}

extension Notations {
    /// The unfolded-boundary chrome step, gated on folding having run first.
    public static var boundaryChromeStep: TransformStep {
        TransformStep(.boundaryChrome, requires: [.foldGroups]) { (g: VGraph) throws(VError) in
            try applyBoundaryChromeStep(to: g)
        }
    }
}
