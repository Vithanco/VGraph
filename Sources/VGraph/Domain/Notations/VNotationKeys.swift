/// The keys a `vnotation` type declaration reads, spelled as export writes them.
/// An author may write one in any case, or in an older spelling; both are brought
/// to this spelling before anything reads the block, so nothing after has to care.
enum VNotationKeys {
    /// `.node` for `node type:`, `.edge` for `edge type:`, `.group` for `group type:`.
    static func keys(of declaration: AttributeTarget) -> [String] {
        switch declaration {
        case .node:
            return [
                Attributes.Node.backgroundColor.name, "icon", "iconColor", "iconSize", "category", "fontsize",
                Attributes.Node.addsToNeighborhood.name,
            ] + GroupFrame.vnotationKeys + Bound.nodeBounds.map { $0.name }
        case .edge:
            return [
                "arrowHead", "arrowTail", "style", "color", "penwidth", "constraint", "dir", "headLabel", "tailLabel",
                "len", "labelangle", "labeldistance",
            ] + Bound.edgeBounds.map { $0.name }
        case .group:
            return GroupFrame.vnotationKeys
        }
    }

    /// A key the declaration does not take stays as written.
    static func current(_ key: String, of declaration: AttributeTarget) -> String {
        let renamed = OlderVGLSpellings.current(key, in: .typeDeclaration(declaration))
        return keys(of: declaration).first { $0.lowercased() == renamed.lowercased() } ?? renamed
    }

    /// The declaration's keys in their current spelling. Where it gives one key
    /// twice, the current spelling wins; a value it overrules is kept to be reported.
    static func reading(_ attributes: [String: String], of declaration: AttributeTarget, owner: ItemKey)
        -> (attributes: [String: String], givenTwice: [KeyGivenTwice])
    {
        let spellingsByKey = Dictionary(grouping: attributes.keys.sorted()) { current($0, of: declaration) }
        let read = spellingsByKey.keys.sorted().map { key -> (key: String, value: String, givenTwice: [KeyGivenTwice]) in
            let spellings = spellingsByKey[key] ?? []
            let keptSpelling = spellings.min { KeyGivenTwice.preference($0, for: key) < KeyGivenTwice.preference($1, for: key) } ?? key
            let kept = KeyGivenTwice.Written(spelling: keptSpelling, value: attributes[keptSpelling] ?? "")
            let overruled = spellings.filter { $0 != keptSpelling && attributes[$0] != kept.value }.map { spelling in
                KeyGivenTwice(
                    owner: owner, key: key, kept: kept,
                    dropped: KeyGivenTwice.Written(spelling: spelling, value: attributes[spelling] ?? ""))
            }
            return (key, kept.value, overruled)
        }
        return (
            Dictionary(uniqueKeysWithValues: read.map { ($0.key, $0.value) }),
            read.flatMap { $0.givenTwice }
        )
    }
}
