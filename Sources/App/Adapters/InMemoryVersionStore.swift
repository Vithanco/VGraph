// Default ForStoreDocumentVersions adapter: an in-process stack. Behaves
// exactly like the pre-port undo/redo history (see docs/adr/0006 and 0007) —
// divergence after undo drops the abandoned tail, depth is capped.

import VGraph

public struct InMemoryVersionStore: ForStoreDocumentVersions {
    private let maxHistory: Int
    /// Root-to-tip VGL snapshots, in lockstep with `numbers`.
    private var entries: [String]
    private var numbers: [Int]
    private var cursor: Int
    private var nextNumber: Int

    /// Seeded with an empty document at version 0 so `current` is total —
    /// there is no unseeded state for a caller to trip over. `reset` starts
    /// real numbering at 1.
    public init(maxHistory: Int = 100) {
        self.maxHistory = maxHistory
        self.entries = [""]
        self.numbers = [0]
        self.cursor = 0
        self.nextNumber = 1
    }

    public mutating func reset(vgl: String) throws(VError) {
        entries = [vgl]
        numbers = [nextNumber]
        nextNumber += 1
        cursor = 0
    }

    @discardableResult
    public mutating func record(vgl: String) throws(VError) -> VersionRef {
        if cursor < entries.count - 1 {
            entries.removeSubrange((cursor + 1)...)
            numbers.removeSubrange((cursor + 1)...)
        }
        entries.append(vgl)
        numbers.append(nextNumber)
        nextNumber += 1
        if entries.count > maxHistory {
            let overflow = entries.count - maxHistory
            entries.removeFirst(overflow)
            numbers.removeFirst(overflow)
        }
        cursor = entries.count - 1
        return current
    }

    public mutating func amend(vgl: String) throws(VError) {
        entries[cursor] = vgl
    }

    private func ref(at index: Int) -> VersionRef {
        VersionRef(number: numbers[index])
    }

    public var current: VersionRef { ref(at: cursor) }

    public func vgl(of ref: VersionRef) -> String? {
        guard let index = numbers.firstIndex(of: ref.number) else { return nil }
        return entries[index]
    }

    public func parent(of ref: VersionRef) -> VersionRef? {
        guard let index = numbers.firstIndex(of: ref.number), index > 0 else { return nil }
        return self.ref(at: index - 1)
    }

    public func children(of ref: VersionRef) -> [VersionRef] {
        guard let index = numbers.firstIndex(of: ref.number), index < numbers.count - 1 else {
            return []
        }
        return [self.ref(at: index + 1)]
    }

    public var canUndo: Bool { cursor > 0 }
    public var canRedo: Bool { cursor < entries.count - 1 }

    @discardableResult
    public mutating func undo() throws(VError) -> VersionRef? {
        guard canUndo else { return nil }
        cursor -= 1
        return current
    }

    @discardableResult
    public mutating func redo() throws(VError) -> VersionRef? {
        guard canRedo else { return nil }
        cursor += 1
        return current
    }
}
