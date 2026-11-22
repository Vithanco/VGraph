//
//  VSplitCandidate.swift
//  VGraph
//
//  One way the notation permits inserting a node into an existing edge.
//

/// One way to split an edge. A **pair** of edge types, not a node type: in a
/// Causal Loop Diagram the sign of each link is the whole point, so the two
/// halves are separate choices — see `namesTheRelationshipsWhenTheNodeTypeIsNotEnough`.
public struct VSplitCandidate: Sendable, Equatable {
    /// Source → inserted node.
    public let incoming: EdgeType
    /// Inserted node → target.
    public let outgoing: EdgeType
    public let title: String

    public var nodeType: NodeType { incoming.to }

    /// Stable within one conversation, which is all replay needs (ADR-0013).
    public var id: String { "\(incoming.id.id)>\(outgoing.id.id)" }
}
