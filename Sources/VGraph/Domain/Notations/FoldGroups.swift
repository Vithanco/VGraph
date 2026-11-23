extension Notations {

    public struct FoldGroups: NotationExtension {

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] {
                return [Self.foldedGroup]
            }

            private static let foldedGroupId = "FoldedGroup"

            public static let foldedGroup: NodeType = NodeType(rawValue: foldedGroupId)
        }

        public struct EdgeTypes: NotationEdgeTypes {
            public static var all: [EdgeType] { return [] }
        }

        /// The actual per-node style (with count) is stamped in FoldStep.
        public static var values: [TypeValues] {
            [
                .nodeType(
                    NodeTypes.foldedGroup,
                    [
                        Attributes.Node.nodeStyle(.presetLayout), Attributes.Node.fontsize(13), Attributes.Node.fontname(.dmSans),
                    ])
            ]
        }

        /// Runs for every notation: `Notations.extensionSteps` wires it in
        /// directly rather than through a notation's own step.
        public static var foldStep: TransformStep {
            TransformStep(.foldGroups) { (graph: VGraph) throws(VError) in try applyFoldStep(to: graph) }
        }
    }
}
