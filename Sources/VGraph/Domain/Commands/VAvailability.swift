//
//  VAvailability.swift
//  VGraph
//
//  Why a command is offered, greyed, or greyed-but-reachable.
//

/// Whether a [[VCommand]] may run on a target, and — when it may not — *why*.
///
/// The why decides what ⌥ can reach: both reasons grey a command, but only one
/// is a [[Notation break]] the user may insist on. A case rather than words in
/// the command's title, so an adapter can localise it, restyle it, or turn it
/// into a "hold ⌥" hint.
public enum VAvailability: Sendable, Equatable {
    case available

    /// The notation says no, and the user may overrule it. Greyed until ⌥.
    case forbiddenByNotation

    /// Nothing to offer here at all — no URL to open, no text to rename. ⌥
    /// changes nothing, because there is no rule to break.
    case notApplicable
}

extension VAvailability {
    /// The one place the ⌥ rule lives, so no command spells out
    /// `… || notationBreak == .permitted` for itself and can forget to.
    public func isEnabled(under notationBreak: VNotationBreak) -> Bool {
        switch self {
        case .available: true
        case .forbiddenByNotation: notationBreak == .permitted
        case .notApplicable: false
        }
    }
}
