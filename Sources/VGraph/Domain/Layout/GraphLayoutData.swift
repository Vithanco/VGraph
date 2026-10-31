// The result of computing a graph layout: node positions, edge routes and
// group bounds.
//
// Engine-agnostic on purpose — nothing here is Graphviz-specific. It is the
// contract between "compute a layout" (a driven adapter, e.g. the in-process
// Graphviz C engine) and "apply that layout to a VGraph" (`applyLayoutData`),
// which is what lets the two be developed and tested independently.

public struct GroupLayoutData: VProtocol {
    /// Bounding box of the group (already Y-flipped)
    public let boundingBox: VRect

    /// Label position (baseline, already Y-flipped)
    public let labelPosition: VPoint?

    /// Label size in points
    public let labelSize: VSize?

    public init(
        boundingBox: VRect,
        labelPosition: VPoint? = nil,
        labelSize: VSize? = nil
    ) {
        self.boundingBox = boundingBox
        self.labelPosition = labelPosition
        self.labelSize = labelSize
    }
}

public struct GraphLayoutData: VProtocol {
    public let nodePositions: [String: VPoint]
    public let edgeLayouts: [String: EdgeLayoutData]

    /// Layout for the root graph itself: bounding box (encloses everything drawn,
    /// including edge splines and arrowheads) plus optional graph label position/size.
    /// Same shape as a cluster, because structurally the root graph is just a group.
    public let rootLayout: GroupLayoutData?

    /// Layout data for groups/clusters, keyed by group ID (without cluster_ prefix)
    public let groupLayouts: [String: GroupLayoutData]

    public init(
        nodePositions: [String: VPoint] = [:],
        edgeLayouts: [String: EdgeLayoutData] = [:],
        rootLayout: GroupLayoutData? = nil,
        groupLayouts: [String: GroupLayoutData] = [:]
    ) {
        self.nodePositions = nodePositions
        self.edgeLayouts = edgeLayouts
        self.rootLayout = rootLayout
        self.groupLayouts = groupLayouts
    }
}
