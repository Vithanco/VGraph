//
//  VGroupingTarget.swift
//  VGraph
//
//  Where a new group of the selection would go. See ADR-0018.
//

/// One answer to three questions — may the command run, where does the group
/// land, and what should the menu row say — so the greyed row and the executed
/// command cannot disagree (ADR-0018).
public struct VGroupingTarget: Sendable, Equatable {
    public let parentId: String
    /// How many elements would leave a group they are in. Zero is the only case
    /// `addGroup(containing:)` accepts.
    public let detachedCount: Int

    public init(parentId: String, detachedCount: Int) {
        self.parentId = parentId
        self.detachedCount = detachedCount
    }

    public var detachesAny: Bool { detachedCount > 0 }
}
