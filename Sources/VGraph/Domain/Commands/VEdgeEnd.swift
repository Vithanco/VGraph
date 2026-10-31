//
//  VEdgeEnd.swift
//  VGraph
//
//  Which end of an edge a command is about.
//

/// One of an edge's two attachments. Not an element: an [[Edge end]] has no id,
/// being a *position on* an edge, so anything naming one names the pair
/// (edge, end). Cases match `Edge.from`/`Edge.to` and `reattach`'s parameters,
/// so the word never changes on the way down (ADR-0021).
public enum VEdgeEnd: Sendable, Equatable {
    case from
    case to
}
