//
//  VNotationBreak.swift
//  VGraph
//
//  Whether a VCommand may go beyond what the notation permits.
//

/// Permission to break the notation. The editor binds `.permitted` to ⌥; the
/// domain never learns which key gave it (ADR-0001).
///
/// ## When a command takes this at all
///
/// Two shapes carry a break across `ForEditAGraphVisually`, and which one a
/// command uses is not a matter of taste:
///
/// - **An overload pair**, where going past the notation changes *what you
///   pass*. `split(_:with:)` takes a `VSplitCandidate` the notation offered;
///   `split(_:ofType:)` takes a `NodeType` chosen directly, because past the
///   notation no candidate carries it. `addSuccessor`/`addPredecessor` pair the
///   same way, `EdgeType.Id` against `NodeType`. Asking for the second form *is*
///   permitting the break, so there is no flag to pass and nothing to grey out.
/// - **This flag**, where the arguments are the same either way and only the
///   outcome differs.
///
/// A command with no break at all takes neither: `changeType(of groupId:to:)`
/// and `changeType(of edgeId:using:)`, for the reason ADR-0020 and ADR-0023
/// give — an unknown boundary kind is what a broken document produces, and an
/// unknown edge type over a pair the notation already joins de-types a legal
/// edge. Where there is no rule worth breaking, the command answers
/// `.notApplicable` and ⌥ leaves it greyed.
///
/// ## What `.permitted` then means
///
/// Two things, and the line is gesture versus menu:
///
/// - **A [[Gesture]] mints outright.** `connect` and `reattach` are reached by
///   dragging, so there is no list on screen for ⌥ to widen — it makes an
///   unknown edge type for the pair, *even over a pair the notation would have
///   joined* (ADR-0012, ADR-0021). The `using:` argument is therefore not a
///   choice the caller still has: under `.permitted` it must be `nil`.
/// - **A menu command widens the gate.** `changeDirection` and
///   `changeType(of nodeId:…)` show a list, so ⌥ means "let me reach this at
///   all" — the command runs where its candidate list was empty, and an
///   unknown type is minted *only* then. A type named alongside `.permitted` is
///   still honoured, and still has to be one the notation declares.
public enum VNotationBreak: Sendable, Equatable {
    case forbidden
    case permitted
}
