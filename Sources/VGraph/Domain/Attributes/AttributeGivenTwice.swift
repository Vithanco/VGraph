/// A key given twice: in one spelling, or with different values under an older
/// spelling or in another case. Reported by `GenericQualityChecks.keysGivenTwice`.
struct KeyGivenTwice: VProtocol {
    struct Written: VProtocol {
        let spelling: String
        let value: String
    }

    let owner: ItemKey
    let key: String
    let kept: Written
    let dropped: Written

    /// Lower wins: the current spelling as the guide writes it, then in another
    /// case, then an older one.
    static func preference(_ spelling: String, for key: String) -> Int {
        spelling == key ? 0 : spelling.lowercased() == key.lowercased() ? 1 : 2
    }
}

/// One attribute as a document wrote it; `definition` is `nil` for a statement
/// that names none, which is left for whoever applies it to refuse.
public struct WrittenAttribute {
    let owner: ItemKey
    let spelling: String
    let value: String
    let definition: AttributeDefinition?

    public init(owner: ItemKey, spelling: String, value: String, definition: AttributeDefinition?) {
        self.owner = owner
        self.spelling = spelling
        self.value = value
        self.definition = definition
    }
}

/// An attribute an element was given twice. The graph keeps it,
/// because only the value that won reaches the layers (ADR-0030).
public struct AttributeGivenTwice: VProtocol {
    let keys: KeyGivenTwice
    let definition: AttributeDefinition
    let layer: AttributeLayer

    /// What one layer's statements give twice: the positions of those to pass
    /// over, and what to report. Between two spellings of the same standing the
    /// later wins, as it does when one spelling is repeated. A repeated spelling
    /// is always reported; two spellings only when their values differ.
    public static func reading(_ written: [WrittenAttribute], in layer: AttributeLayer)
        -> (overruled: Set<Int>, givenTwice: [AttributeGivenTwice])
    {
        let named = written.enumerated().compactMap { position, statement in
            statement.definition.map { Named(position: position, statement: statement, definition: $0) }
        }
        let read = Dictionary(grouping: named) { Target(owner: $0.statement.owner, attribute: $0.definition.id) }.values
            .sorted { $0[0].position < $1[0].position }
            .map { reading($0, in: layer) }
        return (Set(read.flatMap { $0.overruled }), read.flatMap { $0.givenTwice })
    }

    private struct Target: Hashable {
        let owner: ItemKey
        let attribute: Attribute.Id
    }

    private struct Named {
        let position: Int
        let statement: WrittenAttribute
        let definition: AttributeDefinition

        var preference: Int {
            min(
                KeyGivenTwice.preference(statement.spelling, for: definition.camelCaseKey),
                statement.spelling.lowercased() == definition.name.lowercased() ? 1 : 2)
        }
    }

    /// `statements` give one attribute of one element.
    private static func reading(_ statements: [Named], in layer: AttributeLayer)
        -> (overruled: [Int], givenTwice: [AttributeGivenTwice])
    {
        guard let best = statements.map({ $0.preference }).min(),
            let kept = statements.last(where: { $0.preference == best })
        else { return ([], []) }
        let others = statements.filter { $0.position != kept.position }
        let reported = others.filter { other in
            let isRepeated = statements.contains {
                $0.statement.spelling == other.statement.spelling && $0.position > other.position
            }
            return isRepeated || !kept.definition.readsAlike(other.statement.value, kept.statement.value)
        }
        let givenTwice =
            reported
            .map { dropped in
                AttributeGivenTwice(
                    keys: KeyGivenTwice(
                        owner: kept.statement.owner, key: kept.definition.camelCaseKey,
                        kept: .init(spelling: kept.statement.spelling, value: kept.statement.value),
                        dropped: .init(spelling: dropped.statement.spelling, value: dropped.statement.value)),
                    definition: kept.definition, layer: layer)
            }
        return (others.map { $0.position }, givenTwice)
    }
}

extension VGraph {
    /// One already noted stays noted once: a group declared again is read again.
    public func noting(_ givenTwice: [AttributeGivenTwice]) -> VGraph {
        let new = givenTwice.filter { !attributesGivenTwice.contains($0) }
        return new.isEmpty ? self : VGraph(base: self, attributesGivenTwice: attributesGivenTwice + new)
    }

    /// Those whose kept value still holds; one that has since been changed, or
    /// whose element is gone, has nothing left to report.
    var standingAttributesGivenTwice: [AttributeGivenTwice] {
        attributesGivenTwice.filter { twice in
            let owner = twice.keys.owner
            let isGone = twice.layer == .model && owner.kind != .root && resolveCommandTarget(id: owner.id) == nil
            let value = try? attributeStore.resolve(twice.definition.id, for: owner, through: twice.layer, chains: self).value
            return !isGone && value.map { twice.definition.readsAlike($0, twice.keys.kept.value) } ?? false
        }
    }
}
