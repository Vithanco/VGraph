// What VGL reads back as a name. A name the graph mints — a declared edge
// type, a view — must pass, or the reopened document cannot refer to it.

extension VGraph {
    static func isVGLKeyword(_ name: String) -> Bool {
        switch name {
        case "vgraph", "vnotation", "vview", "metagraph", "metadescription", "group", "folded", "node", "edge":
            return true
        default: return false
        }
    }

    /// A leading digit would lex as a number.
    static func isVGLIdentifier(_ name: String) -> Bool {
        guard let first = name.first, isASCIILetter(first) || first == "_" else { return false }
        return name.dropFirst().allSatisfy { isVGLIdentifierCharacter($0) }
    }

    /// Must match the lexer, or a name passes here that the parser cannot read.
    static func isVGLIdentifierCharacter(_ character: Character) -> Bool {
        isASCIILetter(character) || ("0"..."9").contains(character) || character == "_" || character == "."
            || character == "-"
    }

    private static func isASCIILetter(_ character: Character) -> Bool {
        ("a"..."z").contains(character) || ("A"..."Z").contains(character)
    }
}
