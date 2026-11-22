//
//  VAmbiguousEdge.swift
//  VGraph
//
//  What retyping a node leaves undecided about the edges around it.
//

/// One edge whose type stops being determined when its node is retyped, with
/// what it could become.
///
/// `changeType` is the only command that still holds a conversation: after the
/// new type is chosen it asks once per ambiguous edge, and *how many* depends on
/// the type just picked. An adapter driving it by name needs to know the
/// questions in advance, which is what this answers.
public struct VAmbiguousEdge: Sendable, Equatable {
    public let edgeId: String
    /// How to name the edge to the user — "A → B", by label where there is one.
    public let prompt: String
    public let options: [EdgeType]
}
