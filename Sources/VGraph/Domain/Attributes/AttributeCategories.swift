/// ADR-0030's split of attributes, kept in one table rather than on each of a
/// hundred definitions. Anything not listed is content, as the ADR says of an
/// undeclared attribute; judging reads content only.
extension Attributes {
    static let presentation: Set<Attribute.Id> = [
        Node.backgroundColor.id, Node.fontColor.id, Node.fontname.id, Node.fontsize.id, Node.shape.id,
        Node.style.id, Node.nodeStyle.id, Node.width.id, Node.height.id, Node.minWidth.id, Node.margin.id,
        Node.fixedsize.id, Node.iconInfo.id, Node.alignGroup.id,
        Edge.arrowHead.id, Edge.arrowTail.id, Edge.color.id, Edge.fontname.id, Edge.penwidth.id, Edge.style.id,
        Edge.dir.id, Edge.len.id, Edge.weight.id, Edge.constraint.id, Edge.labelangle.id, Edge.labeldistance.id,
        Group.backgroundColor.id, Group.border.id, Group.borderColor.id, Group.borderDash.id, Group.borderWidth.id,
        Group.cornerRadius.id, Group.fontcolor.id, Group.fontsize.id, Group.fontname.id,
        Group.groupStyle.id, Group.boundaryChrome.id, Group.isFolded.id, Group.labelocation.id, Group.labeljust.id,
        Group.layoutDirection.id, Group.ratio.id, Group.splines.id, Group.style.id, Group.watermark.id,
        Group.layoutEngine.id, Group.overlap.id, Group.sep.id, Group.maxNodeWidth.id, Group.loopMarkers.id,
        Group.derivedEdges.id,
    ]

    static let computed: Set<Attribute.Id> = [
        Node.wrappedText.id, Node.nodeTextSize.id, Node.layoutedPos.id, Node.layoutedSize.id,
        Node.foldedNodeCount.id, Node.standsForGroup.id,
        Edge.layoutedPath.id, Edge.layoutData.id, Edge.foldedDescription.id, Edge.bundledEdges.id,
        Edge.bundleMembers.id,
        Group.labelLayoutedPos.id, Group.labelLayoutedSize.id, Group.layoutedBounds.id,
        Group.completedSteps.id, Group.recordedLoops.id,
    ]

    /// Means something only for the whole diagram, so only the root may hold it.
    static let diagramOnly: Set<Attribute.Id> = [
        Group.layoutDirection.id, Group.layoutEngine.id,
        Group.maxNodeWidth.id, Group.completedSteps.id, Group.recordedLoops.id,
        Group.diagramLogic.id, Group.overlap.id, Group.sep.id, Group.loopMarkers.id, Group.derivedEdges.id,
    ]
}

extension AttributeDefinition {
    public var category: AttributeCategory {
        if Attributes.computed.contains(id) { return .computed }
        return Attributes.presentation.contains(id) ? .presentation : .content
    }

    public var isDiagramOnly: Bool { Attributes.diagramOnly.contains(id) }
}
