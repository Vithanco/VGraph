extension Notations {

    /// The per-node style (with count baked in) is set dynamically by FoldingLayoutStep.
    public struct FoldGroups: NotationExtension {

        // Colors match the group style palette — Vithanco Diagram Style Guide §08
        // (warm near-white fill, mid-gray dashed border, charcoal label)
        public static let foldedGroupFill = SemanticColor(id: "folded.group.foldedGroup.fill", lightHex: "#f4f3f0")
        public static let foldedGroupBorder = SemanticColor(id: "folded.group.foldedGroup.border", lightHex: "#909088")
        public static let foldedGroupText = SemanticColor(id: "folded.group.foldedGroup.text", lightHex: "#505048")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.foldedGroup]
            }

            private static let foldedGroupId = "FoldedGroup"

            public static let foldedGroup: NodeType = NodeType(string: foldedGroupId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] { return [] }
        }

        /// The actual per-node style (with count) is stamped in FoldingLayoutStep.
        public static var values: [TypeValues] {
            [
                .nodeType(
                    NodeTypes.foldedGroup,
                    [
                        Attributes.Node.nodeStyle(.presetLayout), Attributes.Node.fontsize(13), Attributes.Node.fontname(.dmSans),
                    ])
            ]
        }

        public static var foldStep: TransformStep {
            TransformStep(.foldGroups) { (g: VGraph) throws(VError) in try applyFoldingLayoutStep(to: g) }
        }

        /// Not the route by which folding runs — `Notations.extensionSteps` wires
        /// `foldStep` in directly, unconditionally.
        public static var step: TransformStep? { foldStep }
    }
}
