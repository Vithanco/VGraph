extension TransformStep.Id {
    public static var groupFrame: Self { "groupFrame" }
}

/// Stamps each *unfolded* group's frame onto its loose `Attributes.Group.*`, so
/// the SVG renderer draws a C4 (or other) frame with the right dashed border,
/// colour and fill without knowing about `GroupType`/`GroupStyle`. The unfolded
/// counterpart of `FoldStep`, which stamps the *folded* face onto the
/// collapsed stand-in.
///
/// Runs after folding: a folded group is no longer a group, so only the frames
/// that remain visible are stamped. Groups without a frame of their own keep the
/// plain-group look.
public func applyGroupFrameStep(to graph: VGraph) throws(VError) -> VGraph {
    try graph.groups.folding(graph) { (result, group) throws(VError) in
        guard let frame = graph.resolvedFrame(group) else { return result }
        return try result.stamping(frame, on: group)
    }
}

extension VGraph {
    /// Loose group colours are `VColor`, so the frame's light hex goes in; the
    /// renderer honours a non-default group colour in both themes.
    fileprivate func stamping(_ frame: GroupFrame, on group: Group) throws(VError) -> VGraph {
        try stamping(group: group, attribute: Attributes.Group.cornerRadius(frame.cornerRadius))
            .stamping(group: group, attribute: Attributes.Group.borderDash(frame.borderDash))
            .stamping(group: group, attribute: Attributes.Group.borderColor(frame.borderColor.resolve(darkMode: false)))
            .stamping(group: group, attribute: Attributes.Group.backgroundColor(frame.fill.resolve(darkMode: false)))
    }
}

extension Notations {
    /// Gated on folding having run first.
    public static var groupFrameStep: TransformStep {
        TransformStep(.groupFrame, requires: [.foldGroups]) { (graph: VGraph) throws(VError) in
            try applyGroupFrameStep(to: graph)
        }
    }
}
