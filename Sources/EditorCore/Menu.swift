//
//  Menu.swift
//  EditorCore
//
//  What the diagram pane offers on a right-click, decided in a target a test
//  can import.
//

import App
import VGraph

/// One row of the diagram pane's context menu — the editor's decision about
/// what to draw.
///
/// It began as a copy of a `VCommandDescriptor`, the domain's answer to "what
/// may be done here". Keeping the two apart while they were identical is what
/// let the domain's half be deleted without this one moving house.
public struct MenuItem: Sendable, Equatable {
    public let id: VCommandID
    public let title: String
    /// Why it is offered or not, so an adapter can render a greyed
    /// `.forbiddenByNotation` differently from a greyed `.notApplicable` — the
    /// first is reachable with ⌥, the second is not.
    public let availability: VAvailability
    public let enabled: Bool
    /// The element this row acts on when it is not the menu's own target — as on
    /// an [[Edge bundle]], whose rows each unfold a different group.
    public let target: String?

    public init(
        id: VCommandID, title: String, availability: VAvailability, enabled: Bool, target: String? = nil
    ) {
        self.id = id
        self.title = title
        self.availability = availability
        self.enabled = enabled
        self.target = target
    }
}

/// The menu for one element, in the order it should be drawn.
///
/// Generic over the port, never `any ForEditAGraphVisually` — ports are generic
/// parameters by choice, and Embedded Swift still rejects handing an `any` port
/// on to generic code.
///
/// Built here rather than relayed from the domain: which commands an element
/// kind offers, in what order, and what each is called are presentation
/// decisions (ADR-0013). What may *run* still comes from the domain, through
/// `availability`.
public func menu(
    for elementId: String,
    in session: some ForEditAGraphVisually,
    notationBreak: VNotationBreak = .forbidden
) -> [MenuItem] {
    guard let kind = session.kind(of: elementId) else { return [] }

    var result: [MenuItem] = []
    for command in commands(on: kind) {
        let availability = availability(of: command, on: elementId, in: session)
        // Offered only where it runs: no break reaches a detailing the type
        // does not have, so a greyed row would only be noise.
        if command == .decompose, availability == .notApplicable { continue }
        result.append(
            MenuItem(
                id: command,
                title: title(of: command, on: elementId, availability: availability, in: session),
                availability: availability,
                enabled: availability.isEnabled(under: notationBreak)))
    }
    // A setting of the whole diagram, so only the canvas offers it, and only
    // where loops are marked at all (ADR-0028).
    if elementId == session.rootGroupId(), session.loopMarkers() != nil {
        result.append(
            MenuItem(id: .loopMarkers, title: "Loop markers…", availability: .available, enabled: true))
    }
    if elementId == session.rootGroupId() {
        result.append(
            MenuItem(id: .layoutDirection, title: "Layout direction…", availability: .available, enabled: true))
    }
    return result
}

/// What each element kind offers, in the order it is shown. This was
/// `appliesTo` plus the registry's array order; menu composition is the
/// adapter's business, so it is spelled out where the menu is drawn.
public func commands(on kind: VElementKind) -> [VCommandID] {
    switch kind {
    case .node:
        return [
            .addSuccessor, .addPredecessor, .changeType, .decompose, .setLabel, .openURL, .setURL,
            .removeURL, .delete,
        ]
    case .edge:
        // `changeType` sits next to `changeDirection` because the two are the
        // same question about one edge — what it is, and which way it runs —
        // and after it so that no existing entry moves (ADR-0023).
        return [
            .changeDirection, .changeType, .split, .setLabel, .openURL, .setURL, .removeURL,
            .delete,
        ]
    case .group:
        // Blank canvas resolves to the [[Root group]] and so arrives here, where
        // `addNode` leads because it is the only reason to open that menu at all
        // (ADR-0016).
        // `ungroup` sits beside `delete` because the pair is the whole point:
        // one keeps the contents, the other takes them with it (ADR-0018).
        // `changeType` sits where it does on a node — a group's boundary kind is
        // the same idea one level up, so it gets the same verb (ADR-0020).
        return [
            .addNode, .toggleFolding, .changeType, .setLabel, .openURL, .setURL, .removeURL,
            .ungroup, .delete,
        ]
    }
}

/// Whether the domain will let this command run here, and if not why not.
///
/// Every answer is derived from a query the port already offers — the three
/// notation-breakable commands are each "the notation left no candidate", which
/// is why they read alike. The adapter decides *what to show*; it never decides
/// what is allowed.
public func availability(
    of command: VCommandID, on elementId: String, in session: some ForEditAGraphVisually
) -> VAvailability {
    // `.notApplicable`, never `.forbiddenByNotation`: the difference is whether ⌥
    // reaches it, and ⌥ must not delete the diagram. `GraphSession` refuses these
    // too — this half only says so before the click (ADR-0016).
    if command != .addNode, elementId == session.rootGroupId() {
        return .notApplicable
    }

    switch command {
    case .addNode:
        // An unattached node is an *incomplete* graph, not an illegal one
        // (ADR-0016); only where it stands can break the notation (ADR-0032).
        return session.nodeTypes(placeableIn: elementId).isEmpty ? .forbiddenByNotation : .available
    case .toggleFolding, .delete, .setURL:
        return .available
    case .ungroup:
        return session.isDetailed(elementId) ? .notApplicable : .available
    case .loopMarkers:
        return session.loopMarkers() == nil ? .notApplicable : .available
    case .addSuccessor:
        return session.successorCandidates(from: elementId).isEmpty
            ? .forbiddenByNotation : .available
    case .addPredecessor:
        return session.predecessorCandidates(to: elementId).isEmpty
            ? .forbiddenByNotation : .available
    case .changeType:
        // A group answers from a different list, and answers `.notApplicable`
        // rather than `.forbiddenByNotation` when it is empty: ⌥ must not reach a
        // boundary kind, since the unknown group type exists only as the result of
        // a document naming one no notation defines.
        if isPlainGroup(elementId, in: session) {
            return session.groupTypes().isEmpty ? .notApplicable : .available
        }
        // An edge answers `.notApplicable` for the group's reason, not the
        // node's: there is no break here, so ⌥ must not enable an item whose
        // conversation would have nothing to offer (ADR-0023).
        //
        // Except on an edge wearing a minted type, where there is always
        // something to offer even when the notation names no alternative:
        // declaring a relationship is how that edge stops being red (ADR-0024).
        if session.kind(of: elementId) == .edge {
            if session.hasUnknownType(edge: elementId) { return .available }
            return session.retypeCandidates(edge: elementId).isEmpty
                ? .notApplicable : .available
        }
        return session.retypeCandidates(for: elementId).isEmpty
            ? .forbiddenByNotation : .available
    case .changeDirection:
        return session.reverseCandidates(for: elementId).isEmpty
            ? .forbiddenByNotation : .available
    case .split:
        return session.splitCandidates(for: elementId).isEmpty
            ? .forbiddenByNotation : .available
    case .setLabel:
        return session.canRename(elementId) ? .available : .notApplicable
    case .decompose:
        return session.canDecompose(elementId) ? .available : .notApplicable
    case .openURL:
        return session.urlToOpen(of: elementId) != nil ? .available : .notApplicable
    case .removeURL:
        return session.storedURL(of: elementId) != nil ? .available : .notApplicable
    default:
        return .notApplicable
    }
}

/// What to call it. Two are dynamic — folding and whether a link is already
/// there — and the "(breaks notation)" suffix is derived from availability so
/// every breakable command says it the same way.
///
/// These strings live here rather than in `VGraph` because they are UI text: an
/// engine that also runs headless in the CLI and MCP has no business holding
/// English, and a second adapter may want its own words or another language.
public func title(
    of command: VCommandID, on elementId: String, availability: VAvailability,
    in session: some ForEditAGraphVisually
) -> String {
    let base: String
    switch command {
    case .addNode: base = "Add node…"
    case .toggleFolding: base = session.isFolded(elementId) ? "Unfold group" : "Fold group"
    case .addSuccessor: base = "Add successor"
    case .addPredecessor: base = "Add predecessor"
    case .changeType: base = "Change type"
    case .changeDirection: base = "Change direction"
    case .split: base = "Split"
    case .setLabel: base = "Rename"
    case .openURL: base = "Open URL"
    case .setURL: base = session.storedURL(of: elementId) != nil ? "Change URL…" : "Add URL…"
    case .removeURL: base = "Remove URL"
    case .ungroup: base = "Ungroup"
    case .decompose: base = "Decompose"
    case .delete: base = "Delete"
    default: base = command.raw
    }
    return availability == .forbiddenByNotation ? "\(base) (breaks notation)" : base
}

// MARK: - Choices a command needs before it can run

// Each returns the options *worth showing* — empty when there is no question.
// That judgement used to be made inside the command, which could only report it
// by being run; the adapter now makes it up front (ADR-0013).
//
// They live here rather than in the editor so the judgement is testable; only
// drawing the list belongs in `VGraphWasm`.

/// The reversals to offer for an edge, or empty when reversing is not a
/// question: one candidate is picked without asking, and none at all means a
/// permitted [[Notation break]] reverses anyway.
public func reversalOptions(
    for edgeId: String, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let candidates = session.reverseCandidates(for: edgeId)
    guard candidates.count > 1 else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(
            VCommandOption(
                id: candidate.id.id,
                title: session.menuTitle(ofEdgeType: candidate.id) ?? candidate.id.id))
    }
    return options
}

/// The entry that opens the full type list. Its id is a key for the view, not a
/// sentinel — `isBreak` is what carries the meaning, so no adapter has to know
/// a reserved string.
///
/// Computed, not a stored global. This target is linked into the wasm module,
/// and a module-level `let` with a runtime initialiser needs lazy
/// initialisation under Embedded Swift — storage worth avoiding for a value
/// that is three literals.
public var breakOption: VCommandOption {
    VCommandOption(id: "__break__", title: "Other type…", isBreak: true)
}

/// The way out of a [[Notation break]], offered in an unknown-typed edge's
/// **Change type** list. Not `isBreak`: it does not go past the notation, it
/// *widens* the notation — the answer is a name, and what comes back is a
/// `vnotation` block and an ordinary typed edge (ADR-0024). Its id is a key for
/// the view, like `breakOption`'s and `plainGroupOption`'s.
public var declareOption: VCommandOption {
    VCommandOption(id: "__declare__", title: "New relationship…")
}

/// The name to seed the field with: what this edge's pair would conventionally
/// be called, in the notation's own `concept_to_relation` style. A default the
/// author can accept with Return is the whole reason naming is not a burden.
public func suggestedEdgeTypeName(
    forEdge edgeId: String, in session: some ForEditAGraphVisually
) -> String {
    let source = session.node(atEdge: edgeId, end: .from).flatMap { session.nodeType(of: $0) }
    let target = session.node(atEdge: edgeId, end: .to).flatMap { session.nodeType(of: $0) }
    return "\((source?.id ?? "node").lowercased())_to_\((target?.id ?? "node").lowercased())"
}

/// The relationships to offer when adding a successor or predecessor: what the
/// notation permits, plus the break entry, which is *always* present so a
/// [[Notation break]] stays reachable. With no candidates at all the break is
/// the only entry, which is the case a terminal node type lands in.
public func relatedOptions(
    from nodeId: String, outgoing: Bool, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let candidates =
        outgoing
        ? session.successorCandidates(from: nodeId)
        : session.predecessorCandidates(to: nodeId)

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(VCommandOption(id: candidate.edgeType.id.id, title: candidate.title))
    }
    options.append(breakOption)
    return options
}

/// The node types to offer when creating a node from nothing, or **empty when
/// there is no question**.
///
/// No break entry, unlike `relatedOptions`: ⌥ widens the list itself to every
/// type, which is the break (ADR-0032). And no [[Candidate]]s — those are edge
/// types, and there is no edge here for the notation to decide (ADR-0016).
public func addNodeOptions(
    on target: String, notationBreak: VNotationBreak = .forbidden, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let types = addableNodeTypes(on: target, notationBreak: notationBreak, in: session)
    guard types.count > 1 else { return [] }

    var options: [VCommandOption] = []
    for type in types {
        options.append(VCommandOption(id: type.id, title: type.id))
    }
    return options
}

func addableNodeTypes(
    on target: String, notationBreak: VNotationBreak, in session: some ForEditAGraphVisually
) -> [NodeType] {
    notationBreak == .permitted ? session.nodeTypes() : session.nodeTypes(placeableIn: target)
}

/// The node types behind "Other type…". Unknown types are excluded — they are
/// the *result* of a break, never an option for one.
///
/// `excluding` drops that element's own type, which is right when *retyping*
/// something — "change it to what it already is" is not an offer — and wrong
/// when *creating* a node, where every type is a real choice.
public func breakTypeOptions(
    in session: some ForEditAGraphVisually, excluding elementId: String? = nil
) -> [VCommandOption] {
    let current = elementId.flatMap { session.nodeType(of: $0) }

    var options: [VCommandOption] = []
    for type in session.nodeTypes() where type.id != current?.id {
        options.append(VCommandOption(id: type.id, title: type.id))
    }
    return options
}

/// What may be inserted into an edge, or **empty when there is no question** —
/// the notation leaving exactly one insertion and the user not asking for more.
///
/// Unlike `relatedOptions`, the break entry appears only under a permitted
/// break. Adding a node always has somewhere to put one; splitting an edge the
/// notation has no shape for is a request the user has to make.
public func splitOptions(
    for edgeId: String, notationBreak: VNotationBreak, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let candidates = session.splitCandidates(for: edgeId)
    guard candidates.count > 1 || notationBreak == .permitted else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(VCommandOption(id: candidate.id, title: candidate.title))
    }
    if notationBreak == .permitted { options.append(breakOption) }
    return options
}

/// The edge types to choose between when joining two nodes, or **empty when
/// there is no question**: one type the command uses, none at all, or a
/// permitted break — ⌥ is this gesture's escape hatch and mints an unknown type
/// outright rather than offering a list, which is why it asks nothing.
public func connectOptions(
    from: String, to: String, notationBreak: VNotationBreak,
    in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    guard notationBreak == .forbidden else { return [] }

    let candidates = session.connectCandidates(from: from, to: to)
    guard candidates.count > 1 else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(
            VCommandOption(
                id: candidate.id.id,
                title: session.menuTitle(ofEdgeType: candidate.id) ?? candidate.id.id))
    }
    return options
}

/// The same judgement for a [[Reattach]] drop: empty when there is nothing to
/// ask — one candidate the command picks itself, none at all, or a permitted
/// break, which mints an unknown type without asking (ADR-0021).
public func reattachOptions(
    edge: String, end: VEdgeEnd, to nodeId: String, notationBreak: VNotationBreak,
    in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    guard notationBreak == .forbidden else { return [] }

    let candidates = session.reattachCandidates(edge: edge, end: end, to: nodeId)
    guard candidates.count > 1 else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(
            VCommandOption(
                id: candidate.id.id,
                title: session.menuTitle(ofEdgeType: candidate.id) ?? candidate.id.id))
    }
    return options
}

/// The types a node may become, or **empty when there is no question** — the
/// notation leaving exactly one and the user not asking for more. The break
/// entry appears only under a permitted break, as with `splitOptions`.
public func retypeOptions(
    for nodeId: String, notationBreak: VNotationBreak, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let candidates = session.retypeCandidates(for: nodeId)
    guard candidates.count > 1 || notationBreak == .permitted else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(VCommandOption(id: candidate.id, title: candidate.id))
    }
    if notationBreak == .permitted { options.append(breakOption) }
    return options
}

/// The types an edge may become, or **empty when there is no question** — one
/// alternative the command picks itself, or none at all. No `notationBreak`
/// parameter and no break entry, as `reversalOptions` has neither: ⌥ reaches
/// nothing here (ADR-0023).
public func edgeRetypeOptions(
    for edgeId: String, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let candidates = session.retypeCandidates(edge: edgeId)
    // An unknown-typed edge always has a question, even where the notation
    // names nothing: the list is then the one entry that gets it out of the
    // break it is in (ADR-0024).
    let unknown = session.hasUnknownType(edge: edgeId)
    guard unknown || candidates.count > 1 else { return [] }

    var options: [VCommandOption] = []
    for candidate in candidates {
        options.append(
            VCommandOption(
                id: candidate.id.id,
                title: session.menuTitle(ofEdgeType: candidate.id) ?? candidate.id.id))
    }
    if unknown { options.append(declareOption) }
    return options
}

func isPlainGroup(_ elementId: String, in session: some ForEditAGraphVisually) -> Bool {
    session.kind(of: elementId) == .group && !session.isDetailed(elementId)
}

/// A group with no type is a real state — most groups in most notations are
/// plain — so typing one must not be a one-way door. Its id is a key for the
/// view, like `breakOption`'s.
public var plainGroupOption: VCommandOption {
    VCommandOption(id: "__plain__", title: "Plain group")
}

/// The boundary kinds a group may take, or **empty when there is no question**.
/// No break entry, unlike `retypeOptions`: there is no such thing as a boundary
/// kind outside the notation to reach for.
public func groupRetypeOptions(
    for groupId: String, in session: some ForEditAGraphVisually
) -> [VCommandOption] {
    let types = session.groupTypes()
    guard !types.isEmpty else { return [] }

    let current = session.groupType(of: groupId)
    var options: [VCommandOption] = []
    for type in types where type.id != current?.id {
        options.append(VCommandOption(id: type.id, title: type.id))
    }
    if current != nil {
        options.append(plainGroupOption)
    }
    return options
}

/// The questions retyping leaves behind, as option lists ready to show. One per
/// ambiguous edge, in the order `changeType` expects the answers.
public func ambiguousEdgeOptions(_ edge: VAmbiguousEdge) -> [VCommandOption] {
    var options: [VCommandOption] = []
    for option in edge.options {
        options.append(VCommandOption(id: option.id.id, title: option.id.id))
    }
    return options
}
