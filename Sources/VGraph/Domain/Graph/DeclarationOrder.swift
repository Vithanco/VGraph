/// The order a document declared its elements in, which export and
/// the Display pipeline preserve. Structure, not an attribute (ADR-0030).
public struct DeclarationOrder: VProtocol {
    private var next = 1
    private var positions: [ItemKey: Int] = [:]

    public init() {}

    func position(of key: ItemKey) -> Int? { positions[key] }

    func appending(_ key: ItemKey) -> DeclarationOrder {
        var result = self
        result.positions[key] = next
        result.next += 1
        return result
    }

    /// At a position an element that was replaced held, so a command that
    /// deletes and re-adds keeps the document's order.
    func placing(_ key: ItemKey, at position: Int) -> DeclarationOrder {
        var result = self
        result.positions[key] = position
        return result
    }

    func removing(_ key: ItemKey) -> DeclarationOrder {
        var result = self
        result.positions[key] = nil
        return result
    }
}
