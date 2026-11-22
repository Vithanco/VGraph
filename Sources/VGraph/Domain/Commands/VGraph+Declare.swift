//
//  VGraph+Declare.swift
//  VGraph
//
//  Declaring a relationship the notation lacks — the alternative to minting an
//  unknown edge type. See ADR-0024.
//

extension VGraph {
    /// Whether `name` is a relationship name this graph can take: a VGL
    /// identifier the parser will read back, not one of its keywords, and not a
    /// type this graph already has.
    public func canDeclare(edgeTypeNamed name: String) -> Bool {
        Self.isVGLIdentifier(name) && !Self.isVGLKeyword(name) && get(edgeType: EdgeType.Id(string: name)) == nil
    }

    /// Add an edge type the notation does not declare, and make the document's
    /// notation a [[Dynamic notation]] extending the one it had.
    ///
    /// The exporter needs nothing told to it — `reconstructVNotation` rebuilds
    /// the `vnotation` block by diffing this graph's types against the base
    /// named in `extendsNotation`.
    ///
    /// This is what replaces minting. A minted `__UNKNOWN_EDGE_TYPE__` cannot be
    /// written into VGL and read back, so an edge wearing one is a state the
    /// document cannot hold; a declared type is ordinary VGL (ADR-0024).
    public func declaring(
        edgeType id: EdgeType.Id, from: NodeType, to: NodeType
    ) throws(VError) -> (VGraph, EdgeType) {
        let edgeType = EdgeType(id: id.id, from: from, to: to)
        return (try add(edgeType: edgeType).onDynamicNotation(), edgeType)
    }

    /// Happens once: a document already on a dynamic notation keeps its name
    /// and simply gains another type.
    private func onDynamicNotation() -> VGraph {
        let base = notationName
        guard NotationRegistry.entries.contains(where: { $0.id == base }) else { return self }
        return extending(notation: base).using(notation: dynamicNotationName(extending: base))

        /// Derived rather than asked: the author is naming the *relationship*,
        /// and a second question about what to call the notation is a question
        /// about bookkeeping.
        func dynamicNotationName(extending base: String) -> String {
            "\(base)Extended"
        }
    }
}
