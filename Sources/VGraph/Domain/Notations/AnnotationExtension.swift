extension Notations {

    /// AnnotationExtension adds `Annotation` and `Warning` node types to any notation.
    ///
    /// When applied to a graph, it automatically registers edge types from every
    /// existing node type to `Annotation` and `Warning`, allowing any node to be annotated.
    public struct Annotation: NotationExtension {

        public static let annotation: NodeType = NodeType(string: "Annotation")
        public static let warning: NodeType = NodeType(string: "Warning")

        public struct NodeTypes: NotationNodeTypes {
            public static var all: [NodeType] { [Notations.Annotation.annotation, Notations.Annotation.warning] }
        }

        public struct EdgeTypes: NotationEdgeTypes {
            /// Edge types are generated per node type in `edgeContent(given:)`.
            public static var all: [EdgeType] { [] }
        }

        public static var values: [TypeValues] {
            [
                .preset(annotation, .annotationNode, fontsize: 12, badgeTypeName: "Annotation"),
                .preset(warning, .warningNode, fontsize: 12, badgeTypeName: "Warning"),
            ]
        }

        public static func edgeContent(given nodeTypes: [NodeType]) -> NotationContent {
            let sources = nodeTypes.filter { !$0.id.hasPrefix("__UNKNOWN") && $0 != annotation && $0 != warning }
            return NotationContent(
                edgeTypes: sources.flatMap { source in
                    [
                        EdgeType(id: "annotates__\(source.id)", from: source, to: annotation),
                        EdgeType(id: "warns__\(source.id)", from: source, to: warning),
                    ]
                })
        }
    }
}
