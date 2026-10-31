//
//  VAvailability.swift
//  VGraph
//
//  Why a command is offered, greyed, or greyed-but-reachable.
//

/// Whether a [[VCommand]] may run on a target, and — when it may not — *why*.
///
/// A `Bool` could not say why, so the reason used to be smuggled out inside the
/// command's **title**: `"Change type (breaks notation)"`. That made a domain
/// fact into English prose an adapter could not localise, restyle, or turn into
/// a "hold ⌥" hint, and made three tests assert on wording.
///
/// The distinction is not cosmetic. `addSuccessor` on a terminal node type was
/// indistinguishable from `changeType` on a node the notation forbids, so ⌥
/// could not reach the first — see [[Notation break]].
public enum VAvailability: Sendable, Equatable {
    case available

    /// The notation says no, and the user may overrule it. Greyed until ⌥.
    case forbiddenByNotation

    /// Nothing to offer here at all — no URL to open, no text to rename. ⌥
    /// changes nothing, because there is no rule to break.
    case notApplicable
}

extension VAvailability {
    /// The one place the ⌥ rule lives. Every command used to spell out
    /// `… || notationBreak == .permitted` for itself, and the two that forgot
    /// are why the bug existed.
    public func isEnabled(under notationBreak: VNotationBreak) -> Bool {
        switch self {
        case .available: true
        case .forbiddenByNotation: notationBreak == .permitted
        case .notApplicable: false
        }
    }
}
