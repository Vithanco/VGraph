//
//  Conversation.swift
//  EditorCore
//
//  A [[VCommand]] that cannot be decided from the graph and the target alone
//  asks the user first. Which question it opens with, what each answer settles,
//  and when there is no question at all — decided in a target a test can import.
//
//  First built as replay, then replaced with named methods (ADR-0013): the
//  adapter asks the domain what a command *would* need, collects the answers,
//  and makes one call. The state below is that collection. It stays
//  adapter-side deliberately — `GraphSession` holding it was rejected, because
//  a pending command there collides with text edits, undo and re-targeting.
//

import App
import VGraph

/// The named call a finished conversation has settled on, with every argument
/// resolved. Data rather than a closure so that what the conversation *decided*
/// is what a test asserts; the adapter performs it against its own session.
public enum EditorAction: Sendable, Equatable {
    case toggleFolding(group: String)
    case ungroup(group: String)
    case decompose(node: String)
    case delete(element: String)
    case removeURL(element: String)
    case openURL(element: String)
    /// Opens an [[Inline edit]] (ADR-0009); the label is typed there.
    case rename(element: String)
    case addNode(in: String, ofType: NodeType, notationBreak: VNotationBreak)
    case addRelated(to: String, outgoing: Bool, using: EdgeType.Id)
    /// Past the notation: the node type is chosen directly, so no edge type
    /// carries it and the edge becomes an unknown one.
    case addRelatedBreaking(to: String, outgoing: Bool, ofType: NodeType)
    /// `to: nil` leaves the choice to the named method — one candidate it picks
    /// itself, none at all and a permitted break reverses anyway.
    case changeDirection(edge: String, to: EdgeType.Id?, notationBreak: VNotationBreak)
    /// `using: nil` as in `changeDirection`: the named method picks where the
    /// notation left one choice, and mints an unknown type under a permitted
    /// break. `declareEdgeType` is the way back out of one (ADR-0024).
    case connect(from: String, to: String, using: EdgeType.Id?, notationBreak: VNotationBreak)
    /// Widen the notation rather than break it: give an edge wearing a minted
    /// type a name, and declare it (ADR-0024).
    case declareEdgeType(edge: String, named: String)
    case reattach(
        edge: String, end: VEdgeEnd, to: String, using: EdgeType.Id?,
        notationBreak: VNotationBreak)
    case split(edge: String, with: VSplitCandidate)
    /// Past the notation: the inserted node's type is chosen directly, so no
    /// pair of edge types carries it.
    case splitBreaking(edge: String, ofType: NodeType)
    /// `edgeTypes` answers `ambiguousEdges(ifRetyping:to:)` positionally, one
    /// per ambiguous edge, in the order they were asked.
    case changeType(
        node: String, to: NodeType, edgeTypes: [EdgeType.Id], notationBreak: VNotationBreak)
    /// The same menu command one level up, and a separate action because it
    /// settles a different argument: `nil` makes the boundary plain again, which
    /// is a real state and not the absence of one (ADR-0020). No conversation
    /// state to carry — an edge's group is derived (ADR-0017), so retyping a
    /// boundary leaves nothing ambiguous.
    case changeGroupType(group: String, to: GroupType?)
    /// Retype an edge without moving either end. `using: nil` where the notation
    /// left one alternative and the command picks it; no `notationBreak`,
    /// because there is no break to permit (ADR-0023).
    case changeEdgeType(edge: String, using: EdgeType.Id?)
    case setURL(element: String, to: String)
    case setLoopMarkers(LoopMarkers)
    case setLayoutDirection(LayoutDirection)
    case createView(label: String)
    case duplicateView(label: String)
    case renameView(name: String, label: String)
    case deleteView(name: String)
}

public enum ConversationStep: Sendable, Equatable {
    case ask(prompt: String, options: [VCommandOption])
    /// Only `setURL` asks this way: free text is typed where it belongs, and a
    /// label is typed in the diagram itself (ADR-0009).
    case askText(prompt: String, initial: String)
    case perform(EditorAction)
    case dismiss
}

/// A retype the user has settled the *type* of, and the edge questions that
/// choice left behind. The only accumulating state in any conversation, because
/// `changeType` is the only command whose question count depends on an earlier
/// answer (CONTEXT.md [[VCommand]]).
public struct Retype: Sendable, Equatable {
    public let type: NodeType
    public let ambiguous: [VAmbiguousEdge]
    public var chosen: [EdgeType.Id]

    public init(type: NodeType, ambiguous: [VAmbiguousEdge], chosen: [EdgeType.Id] = []) {
        self.type = type
        self.ambiguous = ambiguous
        self.chosen = chosen
    }
}

/// What a conversation is *about*. A menu command names one element; a
/// [[Gesture]] names several in order and has no menu target at all.
public enum Subject: Sendable, Equatable {
    case element(String)
    case pair(from: String, to: String)
    /// An [[Edge end]] is a position on an edge rather than an element, so the
    /// pair (edge, end) travels together (ADR-0021).
    case edgeEnd(edge: String, end: VEdgeEnd, droppedOn: String)

    /// `nil` for a gesture, which names several elements and so names no
    /// single one.
    public var element: String? {
        if case .element(let id) = self { return id }
        return nil
    }
}

public struct Conversation: Sendable, Equatable {
    public let command: VCommandID
    public let subject: Subject
    /// ⌥ was held on the menu click. One gesture, two effects: show the
    /// candidate list even where there is only one candidate, and permit the
    /// command to go past the notation.
    public let forceChoice: Bool
    public internal(set) var retype: Retype?
    /// The node-type list is on screen, so the next answer is a node type
    /// rather than one of the notation's candidates.
    public internal(set) var breakChoice: Bool

    public var notationBreak: VNotationBreak { forceChoice ? .permitted : .forbidden }

    public init(
        command: VCommandID, subject: Subject, forceChoice: Bool,
        retype: Retype? = nil, breakChoice: Bool = false
    ) {
        self.command = command
        self.subject = subject
        self.forceChoice = forceChoice
        self.retype = retype
        self.breakChoice = breakChoice
    }
}

/// The `default:` arms below are *required*, not defensive: `VCommandID` is
/// static members on a struct rather than an enum, so the compiler cannot check
/// this switch is exhaustive. A command handled in neither `begin` nor `next` is
/// caught only by `MenuAgreesWithExecutionTest`.
public func begin(
    _ command: VCommandID, on target: String, forcingChoice: Bool,
    in session: some ForEditAGraphVisually
) -> (step: ConversationStep, conversation: Conversation) {
    let conversation = Conversation(
        command: command, subject: .element(target), forceChoice: forcingChoice)

    switch command {
    case .toggleFolding: return (.perform(.toggleFolding(group: target)), conversation)
    case .ungroup: return (.perform(.ungroup(group: target)), conversation)
    case .decompose: return (.perform(.decompose(node: target)), conversation)
    case .delete: return (.perform(.delete(element: target)), conversation)
    case .removeURL: return (.perform(.removeURL(element: target)), conversation)
    case .openURL: return (.perform(.openURL(element: target)), conversation)
    case .setLabel: return (.perform(.rename(element: target)), conversation)

    case .addSuccessor, .addPredecessor:
        let outgoing = command == .addSuccessor
        let options = relatedOptions(from: target, outgoing: outgoing, in: session)
        // One real candidate is not a choice. ⌥ forces the list, which is how
        // the break stays reachable when the question would otherwise be skipped.
        if !forcingChoice, let only = VCommandOption.soleCandidate(in: options) {
            return (
                .perform(
                    .addRelated(
                        to: target, outgoing: outgoing, using: EdgeType.Id(string: only.id))),
                conversation
            )
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .addNode:
        let options = addNodeOptions(on: target, notationBreak: conversation.notationBreak, in: session)
        // Empty is "no question", not "nothing to offer": a single type fits
        // here and that is what gets made.
        guard !options.isEmpty else {
            guard
                let only = addableNodeTypes(on: target, notationBreak: conversation.notationBreak, in: session)
                    .first
            else { return (.dismiss, conversation) }
            return (
                .perform(.addNode(in: target, ofType: only, notationBreak: conversation.notationBreak)),
                conversation
            )
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .setURL:
        // Seeded from the link as *stored*, not from `urlToOpen` — that is nil
        // for one too dangerous to follow, and seeding from it would silently
        // discard what the user had.
        return (
            .askText(prompt: urlPrompt, initial: session.storedURL(of: target) ?? ""),
            conversation
        )

    case .changeType:
        // A group answers from a different list, as it does in `availability`:
        // `retypeOptions` reads `retypeCandidates(for nodeId:)`, which has no
        // answer for a group and would dismiss a menu item the menu drew enabled.
        if session.kind(of: target) == .edge {
            let options = edgeRetypeOptions(for: target, in: session)
            // Empty is "no question", not "nothing to offer": one alternative
            // the command picks itself, or none at all — and `availability` has
            // already greyed the second.
            guard !options.isEmpty else {
                guard !session.retypeCandidates(edge: target).isEmpty else {
                    return (.dismiss, conversation)
                }
                return (.perform(.changeEdgeType(edge: target, using: nil)), conversation)
            }
            return (.ask(prompt: prompt(for: command), options: options), conversation)
        }
        if isPlainGroup(target, in: session) {
            let options = groupRetypeOptions(for: target, in: session)
            // Nothing to auto-pick, unlike the node form: `soleCandidate` only
            // fires on a list carrying the escape hatch, and a boundary list
            // carries none. A one-entry list is still a question worth asking.
            guard !options.isEmpty else { return (.dismiss, conversation) }
            return (.ask(prompt: prompt(for: command), options: options), conversation)
        }
        let options = retypeOptions(
            for: target, notationBreak: conversation.notationBreak, in: session)
        guard !options.isEmpty else {
            guard let only = session.retypeCandidates(for: target).first else {
                return (.dismiss, conversation)
            }
            return beganRetype(conversation, node: target, to: only, in: session)
        }
        if !forcingChoice, let only = VCommandOption.soleCandidate(in: options) {
            return beganRetype(
                conversation, node: target, to: NodeType(string: only.id), in: session)
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .split:
        let options = splitOptions(for: target, notationBreak: conversation.notationBreak, in: session)
        // Empty covers two different things: the notation leaves exactly one
        // insertion, or it offers none at all — and the second is not a command.
        guard !options.isEmpty else {
            guard let only = session.splitCandidates(for: target).first else {
                return (.dismiss, conversation)
            }
            return (.perform(.split(edge: target, with: only)), conversation)
        }
        if !forcingChoice, let only = VCommandOption.soleCandidate(in: options) {
            return (splitStep(target, candidateId: only.id, in: session), conversation)
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .newView, .duplicateView:
        return (.askText(prompt: prompt(for: command), initial: ""), conversation)

    case .renameView:
        let label = session.views().first { $0.name == target }.map { $0.label ?? $0.name } ?? target
        return (.askText(prompt: prompt(for: command), initial: label), conversation)

    case .deleteView:
        let options = [
            VCommandOption(id: "delete", title: "Delete"), VCommandOption(id: "cancel", title: "Cancel"),
        ]
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .layoutDirection:
        let current = session.layoutDirection()
        let options = LayoutDirection.allCases.map { direction in
            VCommandOption(
                id: direction.value, title: direction.readableName + (direction == current ? " ✓" : ""))
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .loopMarkers:
        guard let current = session.loopMarkers() else { return (.dismiss, conversation) }
        let options = LoopMarkers.allCases.map { markers in
            VCommandOption(
                id: markers.value, title: markers.readableName + (markers == current ? " ✓" : ""))
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    case .changeDirection:
        let options = reversalOptions(for: target, in: session)
        guard !options.isEmpty else {
            return (
                .perform(
                    .changeDirection(
                        edge: target, to: nil, notationBreak: conversation.notationBreak)),
                conversation
            )
        }
        return (.ask(prompt: prompt(for: command), options: options), conversation)

    default:
        return (.dismiss, conversation)
    }
}

/// Open the conversation a drop starts. A [[Gesture]] names its elements in
/// order and has no menu entry, so it is seeded here rather than by `begin`.
public func beginConnect(
    from: String, to: String, allowingBreak: Bool, in session: some ForEditAGraphVisually
) -> (step: ConversationStep, conversation: Conversation) {
    let conversation = Conversation(
        command: .connect, subject: .pair(from: from, to: to), forceChoice: allowingBreak)
    let allowed = conversation.notationBreak
    let options = connectOptions(from: from, to: to, notationBreak: allowed, in: session)

    guard !options.isEmpty else {
        return (
            .perform(.connect(from: from, to: to, using: nil, notationBreak: allowed)),
            conversation
        )
    }
    return (
        .ask(
            prompt: pairPrompt(from: from, to: to, in: session), options: options),
        conversation
    )
}

/// The same for a [[Reattach]] drop, where one [[Edge end]] moves and the other
/// stays. The prompt names the *fixed* end's node and the one dropped on, since
/// that is the relationship being chosen.
public func beginReattach(
    edge: String, end: VEdgeEnd, to nodeId: String, allowingBreak: Bool,
    in session: some ForEditAGraphVisually
) -> (step: ConversationStep, conversation: Conversation) {
    let conversation = Conversation(
        command: .reattach, subject: .edgeEnd(edge: edge, end: end, droppedOn: nodeId),
        forceChoice: allowingBreak)
    let allowed = conversation.notationBreak
    let options = reattachOptions(
        edge: edge, end: end, to: nodeId, notationBreak: allowed, in: session)

    guard !options.isEmpty else {
        return (
            .perform(
                .reattach(
                    edge: edge, end: end, to: nodeId, using: nil, notationBreak: allowed)),
            conversation
        )
    }
    // Moving `.from` puts the new node first, `.to` puts it last — so the prompt
    // still reads in the edge's direction.
    let fixed = session.node(atEdge: edge, end: end == .from ? .to : .from) ?? ""
    let (from, to) = end == .from ? (nodeId, fixed) : (fixed, nodeId)
    return (
        .ask(
            prompt: pairPrompt(from: from, to: to, in: session), options: options),
        conversation
    )
}

/// Source before destination, by label where there is one — not the edge's own
/// label, which is usually empty and never what changed. The elements came from
/// the drag, so there is no menu target to title the question with.
private func pairPrompt(
    from: String, to: String, in session: some ForEditAGraphVisually
) -> String {
    "\(session.label(of: from) ?? from) → \(session.label(of: to) ?? to)"
}

/// Settle a typed answer. Takes no session: what the text means is the domain's
/// to judge, and it says so by accepting or refusing the call.
public func next(
    afterText text: String, in conversation: Conversation
) -> (step: ConversationStep, conversation: Conversation) {
    if conversation.command == .changeType, let target = conversation.subject.element {
        return (.perform(.declareEdgeType(edge: target, named: text)), conversation)
    }
    switch conversation.command {
    case .newView: return (.perform(.createView(label: text)), conversation)
    case .duplicateView: return (.perform(.duplicateView(label: text)), conversation)
    case .renameView:
        guard let target = conversation.subject.element else { return (.dismiss, conversation) }
        return (.perform(.renameView(name: target, label: text)), conversation)
    default: break
    }
    guard conversation.command == .setURL, let target = conversation.subject.element else {
        return (.dismiss, conversation)
    }
    return (.perform(.setURL(element: target, to: text)), conversation)
}

/// What a refused text answer means. The distinction is *what* was refused:
/// the text, which the user can correct, or the target, which they cannot —
/// re-opening the field on a stale id would loop on it forever.
public func next(
    afterRefusing refusal: VError, typed: String, in conversation: Conversation
) -> ConversationStep {
    if case .edgeTypeNameRefused = refusal, conversation.command == .changeType {
        return .askText(prompt: declarePrompt, initial: typed)
    }
    if case .viewLabelRefused = refusal {
        switch conversation.command {
        case .newView, .duplicateView, .renameView: return .askText(prompt: prompt(for: conversation.command), initial: typed)
        default: return .dismiss
        }
    }
    guard conversation.command == .setURL else { return .dismiss }
    guard case .urlRefused = refusal else { return .dismiss }
    return .askText(prompt: urlPrompt, initial: typed)
}

public func next(
    after option: VCommandOption, in conversation: Conversation,
    session: some ForEditAGraphVisually
) -> (step: ConversationStep, conversation: Conversation) {
    // The escape hatch replaces the question rather than answering it — except
    // for `changeDirection`, where ⌥ has already permitted the break by the time
    // the list is on screen, so there is no reversal left for it to name.
    if option.isBreak, conversation.command == .changeDirection {
        return (.dismiss, conversation)
    }
    // Once inside the retype loop every answer is an edge type, so the escape
    // hatch is not offered and not looked for — the original checked the loop
    // before the hatch, and the order is kept.
    if option.isBreak, !conversation.breakChoice, conversation.retype == nil {
        // Only a *node* retype has an escape hatch. Neither the boundary list
        // nor the edge list carries one, so a break arriving for either did not
        // come from the list it was offered (ADR-0020, ADR-0023).
        if conversation.command == .changeType, let element = conversation.subject.element,
            session.kind(of: element) == .edge || isPlainGroup(element, in: session)
        {
            return (.dismiss, conversation)
        }
        var answered = conversation
        answered.breakChoice = true
        // Retyping is the one command that drops a type from the list: "change
        // it to what it already is" is not an offer. Creating a node excludes
        // nothing, because every type is a real choice there.
        let excluding = conversation.command == .changeType ? conversation.subject.element : nil
        return (
            .ask(
                prompt: breakTypePrompt,
                options: breakTypeOptions(in: session, excluding: excluding), ),
            answered
        )
    }

    // No command check on the two gesture cases: only their own opener can have
    // built those subjects, and it sets the command.
    switch conversation.subject {
    case .pair(let from, let to):
        // `.forbidden` and not the conversation's own: a permitted break returns
        // no options, so this branch is reachable only under a forbidden one.
        return (
            .perform(
                .connect(
                    from: from, to: to, using: EdgeType.Id(string: option.id),
                    notationBreak: .forbidden)),
            conversation
        )

    case .edgeEnd(let edge, let end, let droppedOn):
        return (
            .perform(
                .reattach(
                    edge: edge, end: end, to: droppedOn,
                    using: EdgeType.Id(string: option.id), notationBreak: .forbidden)),
            conversation
        )

    case .element(let target):
        switch conversation.command {
        case .loopMarkers:
            guard let markers = try? LoopMarkers.fromString(option.id) else { return (.dismiss, conversation) }
            return (.perform(.setLoopMarkers(markers)), conversation)
        case .layoutDirection:
            guard let direction = try? LayoutDirection.fromString(option.id) else { return (.dismiss, conversation) }
            return (.perform(.setLayoutDirection(direction)), conversation)
        case .deleteView:
            return (option.id == "delete" ? .perform(.deleteView(name: target)) : .dismiss, conversation)
        case .addSuccessor, .addPredecessor:
            let outgoing = conversation.command == .addSuccessor
            if conversation.breakChoice {
                return (
                    .perform(
                        .addRelatedBreaking(
                            to: target, outgoing: outgoing,
                            ofType: NodeType(string: option.id))),
                    conversation
                )
            }
            return (
                .perform(
                    .addRelated(
                        to: target, outgoing: outgoing,
                        using: EdgeType.Id(string: option.id))),
                conversation
            )

        case .addNode:
            return (
                .perform(
                    .addNode(
                        in: target, ofType: NodeType(string: option.id),
                        notationBreak: conversation.notationBreak)),
                conversation
            )

        case .split:
            if conversation.breakChoice {
                return (
                    .perform(.splitBreaking(edge: target, ofType: NodeType(string: option.id))),
                    conversation
                )
            }
            return (splitStep(target, candidateId: option.id, in: session), conversation)

        case .changeType:
            if session.kind(of: target) == .edge {
                // The way out of a break is a question, not an answer: what
                // comes back is a name (ADR-0024).
                guard option.id != declareOption.id else {
                    return (
                        .askText(
                            prompt: declarePrompt,
                            initial: suggestedEdgeTypeName(forEdge: target, in: session)),
                        conversation
                    )
                }
                return (
                    .perform(
                        .changeEdgeType(edge: target, using: EdgeType.Id(string: option.id))),
                    conversation
                )
            }
            if isPlainGroup(target, in: session) {
                return (
                    .perform(
                        .changeGroupType(
                            group: target,
                            to: option.id == plainGroupOption.id
                                ? nil : GroupType(string: option.id))),
                    conversation
                )
            }
            if var retype = conversation.retype {
                retype.chosen.append(EdgeType.Id(string: option.id))
                var advanced = conversation
                advanced.retype = retype
                return (nextEdgeOrRetype(advanced, node: target), advanced)
            }
            return beganRetype(conversation, node: target, to: NodeType(string: option.id), in: session)

        case .changeDirection:
            return (
                .perform(
                    .changeDirection(
                        edge: target, to: EdgeType.Id(string: option.id),
                        notationBreak: conversation.notationBreak)),
                conversation
            )

        default:
            return (.dismiss, conversation)
        }
    }
}

private func beganRetype(
    _ conversation: Conversation, node: String, to type: NodeType,
    in session: some ForEditAGraphVisually
) -> (step: ConversationStep, conversation: Conversation) {
    var started = conversation
    started.retype = Retype(
        type: type, ambiguous: session.ambiguousEdges(ifRetyping: node, to: type))
    return (nextEdgeOrRetype(started, node: node), started)
}

private func nextEdgeOrRetype(_ conversation: Conversation, node: String) -> ConversationStep {
    guard let retype = conversation.retype else { return .dismiss }

    guard retype.chosen.count == retype.ambiguous.count else {
        let edge = retype.ambiguous[retype.chosen.count]
        return .ask(prompt: edge.prompt, options: ambiguousEdgeOptions(edge))
    }
    return .perform(
        .changeType(
            node: node, to: retype.type, edgeTypes: retype.chosen,
            notationBreak: conversation.notationBreak))
}

/// An insertion's id back to the insertion itself. A stale id names nothing,
/// which closes the menu rather than guessing.
private func splitStep(
    _ edgeId: String, candidateId: String, in session: some ForEditAGraphVisually
) -> ConversationStep {
    for candidate in session.splitCandidates(for: edgeId) where candidate.id == candidateId {
        return .perform(.split(edge: edgeId, with: candidate))
    }
    return .dismiss
}

let breakTypePrompt = "Node type (breaks notation)"
let urlPrompt = "URL"
/// Names the thing being named. Not "Edge type": the author is saying what the
/// relationship *is*, and the notation grows to match (ADR-0024).
let declarePrompt = "Name this relationship"

private func prompt(for command: VCommandID) -> String {
    switch command {
    case .addSuccessor: return "Add successor"
    case .addPredecessor: return "Add predecessor"
    case .addNode: return "Add node"
    case .changeDirection: return "Change direction"
    case .loopMarkers: return "Loop markers"
    case .layoutDirection: return "Layout direction"
    case .newView: return "New view"
    case .duplicateView: return "Duplicate view"
    case .renameView: return "Rename view"
    case .deleteView: return "Delete view"
    case .split: return "Split"
    case .changeType: return "Change type"
    default: return ""
    }
}
