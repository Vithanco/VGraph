//
//  VGraph+Declare.swift
//  VGraph
//
//  Declaring a relationship the notation lacks — the alternative to minting an
//  unknown edge type. See ADR-0024.
//

extension VGraph {
    /// The name a derived notation takes the first time a document declares a
    /// relationship of its own. Derived rather than asked: the author is naming
    /// the *relationship*, and a second question about what to call the notation
    /// is a question about bookkeeping.
    public static func derivedNotationName(extending base: String) -> String {
        "\(base)Extended"
    }

    static func isKeyword(_ name: String) -> Bool {
        switch name {
        case "vgraph", "vnotation", "vview", "metagraph", "metadescription", "group", "folded", "node", "edge":
            return true
        default: return false
        }
    }

    /// Whether `name` is a relationship name this graph can take: a VGL
    /// identifier the parser will read back, not one of its keywords, and not a
    /// type this graph already has.
    ///
    /// The lexer reads an identifier as alphanumerics plus `_`, `.` and `-`, so
    /// those are what may follow the first character. A leading digit would lex
    /// as a number.
    public func canDeclare(edgeTypeNamed name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        for character in name.dropFirst() {
            guard
                character.isLetter || character.isNumber || character == "_"
                    || character == "." || character == "-"
            else { return false }
        }
        guard !Self.isKeyword(name) else { return false }
        return get(edgeType: EdgeType.Id(string: name)) == nil
    }

    /// Add an edge type the notation does not declare, and make the document's
    /// notation a `vnotation` extending the one it had.
    ///
    /// The promotion happens once: a document already on a derived notation
    /// simply gains another type, and its name does not change. The exporter
    /// needs nothing told to it — `reconstructVNotation` rebuilds the block by
    /// diffing this graph's types against the base named in `extendsNotation`.
    ///
    /// This is what replaces minting. A minted `__UNKNOWN_EDGE_TYPE__` cannot be
    /// written into VGL and read back, so an edge wearing one is a state the
    /// document cannot hold; a declared type is ordinary VGL (ADR-0024).
    public func declaring(
        _ id: EdgeType.Id, from: NodeType, to: NodeType
    ) throws(VError) -> (VGraph, EdgeType) {
        let edgeType = EdgeType(id: id.id, from: from, to: to)
        var result = try add(edgeType: edgeType)

        let current = result.notationName
        if NotationRegistry.entries.contains(where: { $0.id == current }) {
            result = result.extending(notation: current)
                .using(notation: VGraph.derivedNotationName(extending: current))
        }
        return (result, edgeType)
    }
}
