import VGraph

/// A graph using one notation, as a document naming it would have, without
/// going through the parser.
extension NotationDeclaration {
    public static func addNotation(addTo graph: VGraph) throws(VError) -> VGraph {
        try graph.placing(content, in: .builtin)
    }
}

extension NotationExtension {
    /// Both phases at once — safe only for a single extension applied on its own.
    public static func addExtension(addTo graph: VGraph) throws(VError) -> VGraph {
        let withNodes = try graph.placing(nodeContent, in: .builtin)
        return try withNodes.placing(edgeContent(given: withNodes.nodeTypes), in: .builtin)
    }
}
