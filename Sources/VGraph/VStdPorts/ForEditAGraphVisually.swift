//
//  ForEditAGraphVisually.swift
//  VGraph
//
//  Driving port: what the outside may do to the diagram. Declared in the core
//  and re-exported by App under its plain name, exactly as a driven port is —
//  see docs/hexagonal-architecture.md.
//

/// What the **diagram pane** may do: draw the graph, and change it by a named
/// command or a [[Gesture]].
///
/// **The pane cannot read the graph.** Everything it shows — menu titles,
/// candidate lists, an element's current label — arrives already decided, so no
/// adapter can re-derive a notation's rules. ADR-0013 originally put the whole
/// of `VGraph` here as `origin` and flagged it as the first thing to revisit;
/// implementation found exactly one use, which is now `label(of:)`.
///
/// **Every command is named.** There is no generic "run command X with these
/// answers" any more, so an adapter cannot invoke one it does not understand —
/// and a thirteenth command is work in every adapter rather than free. That is
/// the trade this port makes, and the first thing an author of a second adapter
/// needs to know (ADR-0013).
public protocol VForEditAGraphVisually {
    /// The text an [[Inline edit]] starts from, or `nil` if the id resolves to
    /// nothing. The only thing the pane reads out of the graph.
    func label(of elementId: String) -> String?

    /// Render the current OriginGraph to SVG, embedding its VGL for round-trip.
    func render(darkMode: Bool) throws(VError) -> RenderResult

    // MARK: - Queries for building a menu
    //
    // Precise questions in place of the graph itself. `origin` is off this port
    // (ADR-0013, reversed) and these are what replace it: the pane asks what it
    // needs to title, grey and populate, and never derives a notation rule.

    /// What kind of thing this id names.
    func kind(of elementId: String) -> VElementKind?
    /// The node's own type, a [[Detailed node]]'s included — `nil` for anything
    /// that is not a node.
    func nodeType(of elementId: String) -> NodeType?
    func isDetailed(_ elementId: String) -> Bool
    /// What unfolding a [[Detailed node]] would reveal: its direct details, a
    /// nested detailed node counting once. Zero for anything else.
    func detailCount(of elementId: String) -> Int
    /// "Fold group" vs "Unfold group".
    func isFolded(_ groupId: String) -> Bool
    /// The link as stored — for the "Add URL…" vs "Change URL…" title, and for
    /// seeding the field. Distinct from `urlToOpen`, which is `nil` for a stored
    /// link too dangerous to follow.
    func storedURL(of elementId: String) -> String?
    /// Whether renaming would show the user anything — false for a node type
    /// that displays no text of its own (ADR-0009).
    func canRename(_ elementId: String) -> Bool

    func successorCandidates(from nodeId: String) -> [VCandidate]
    func predecessorCandidates(to nodeId: String) -> [VCandidate]
    func retypeCandidates(for nodeId: String) -> [NodeType]
    func reverseCandidates(for edgeId: String) -> [EdgeType]
    /// What an edge could become with both ends where they are. `edge:` rather
    /// than `for:`: an overload of the node form differing only in return type
    /// would not resolve at a call site that reads `.first`.
    func retypeCandidates(edge edgeId: String) -> [EdgeType]
    /// Whether this edge wears a minted type. **Change type** is reachable on an
    /// edge the notation offers nothing else for, because declaring a
    /// relationship for it is the way out (ADR-0024).
    func hasUnknownType(edge edgeId: String) -> Bool
    func splitCandidates(for edgeId: String) -> [VSplitCandidate]
    /// The types the notation allows between two existing nodes.
    func connectCandidates(from: String, to: String) -> [EdgeType]
    /// What a chooser should call a relationship, or `nil` where the notation
    /// offers nothing better than the id.
    func menuTitle(ofEdgeType id: EdgeType.Id) -> String?
    /// Every node a drag may start from, and where one may land — the two
    /// questions [[Gesture]] feedback asks while the pointer is moving.
    func connectSources() -> [String]
    func connectTargets(from nodeId: String, notationBreak: VNotationBreak) -> [String]

    /// The same two questions for a [[Reattach]] drag, where one [[Edge end]]
    /// moves and the other stays. Not the `connect` pair with different
    /// arguments: that answers only "from a fixed source, where may I land", so
    /// a moving `from` end has no mirror to ask — and both must count the bounds
    /// against the graph **minus this edge**, which is the domain's job and not
    /// the pane's (ADR-0021).
    func reattachTargets(edge: String, end: VEdgeEnd, notationBreak: VNotationBreak) -> [String]
    func reattachCandidates(edge: String, end: VEdgeEnd, to nodeId: String) -> [EdgeType]
    /// The node id at one end of an edge — what a [[Reattach]] choice prompt
    /// needs for the end the drag left untouched, since the pane holds only the
    /// edge, the side grabbed, and the node dropped on. `nil` for a stale edge id.
    func node(atEdge edgeId: String, end: VEdgeEnd) -> String?
    /// The edges retyping a node leaves ambiguous, in the order `changeType`
    /// consumes the answers.
    func ambiguousEdges(ifRetyping nodeId: String, to type: NodeType) -> [VAmbiguousEdge]
    /// Every type a [[Notation break]] may reach for.
    func nodeTypes() -> [NodeType]
    /// Those a node added to `groupId` may take without a [[Notation break]]:
    /// what the containment check accepts there (ADR-0032).
    func nodeTypes(placeableIn groupId: String) -> [NodeType]
    /// The boundary kinds this notation registered. Empty for most notations, and
    /// that emptiness is the answer to whether typing a group is worth offering.
    func groupTypes() -> [GroupType]
    /// `nil` for a plain group and for anything that is not a group. An ancestor's
    /// type is not the group's own.
    func groupType(of elementId: String) -> GroupType?
    /// What a click on blank canvas resolves to. The pane must be able to *name*
    /// the root, not merely recognise it: a miss carries no id, and a menu cannot
    /// be built without a target (ADR-0016).
    func rootGroupId() -> String

    // MARK: - Queries about a set of elements
    //
    // The pane holds a [[Selection]] the domain never hears about, and asks
    // these two about it (ADR-0018).

    /// The [[Effective selection]]: complete groups collapsed upward. Said
    /// without the word "selection" it is a canonical form over the group tree,
    /// which is why it is the domain's answer and not the adapter's — and why
    /// the pane still cannot walk the group structure to work it out itself.
    func outermostElements(of ids: [String]) -> [String]

    /// Where a new group made of these would go, and what it would cost, or
    /// `nil` when there is nothing to group. One call answers the greying, the
    /// destination and the menu row's title, so the row and the command cannot
    /// disagree.
    func groupingTarget(for ids: [String]) -> VGroupingTarget?

    /// Every group this set may move into — what a drag highlights as it passes
    /// over the diagram, so an offered destination and an accepted one cannot
    /// diverge (ADR-0019). Only a permitted break goes past containment (ADR-0032).
    func moveDestinations(for ids: [String], notationBreak: VNotationBreak) -> [String]

    // MARK: - Named commands
    //
    // Twelve operations with their arguments named and checked. These refuse to
    // be a silent no-op: a caller that named a command, a target and — where
    // one is asked for — an option, and got any of the three wrong has said
    // something wrong, so it throws. That includes an option outside the
    // candidate list the domain offered, which no type can catch. A *menu*
    // greys such a command out instead — that is `EditorCore`'s job, not this
    // port's.

    func toggleFolding(of groupId: String) throws(VError)

    /// Which loops get a [[Loop marker]], or `nil` where the notation marks none —
    /// so the canvas menu offers the choice only where it means something.
    func loopMarkers() -> LoopMarkers?

    /// A document edit like any other: written to the file and undoable.
    func setLoopMarkers(_ markers: LoopMarkers) throws(VError)
    /// The layout direction the shown view gives, through the notation's default.
    func layoutDirection() -> LayoutDirection
    func setLayoutDirection(_ direction: LayoutDirection) throws(VError)

    // MARK: - Views
    //
    // Switching is navigation: not a history step, not in the document. Creating,
    // duplicating, relabelling and deleting are edits like any other.

    /// Name and label, in document order.
    func views() -> [ViewDeclaration]
    /// `nil` is the default view, which is the model.
    func activeView() -> String?
    func selectView(_ name: String?) throws(VError)
    func createView(label: String) throws(VError)
    func duplicateActiveView(label: String) throws(VError)
    /// `nil` names the default view, which has no label to change and cannot be deleted.
    func renameView(_ name: String?, label: String) throws(VError)
    func deleteView(_ name: String?) throws(VError)

    /// Deletes a group's contents along with it. `ungroup` is how a caller keeps
    /// them (ADR-0018).
    func delete(_ elementId: String) throws(VError)
    /// Takes a group apart, leaving its contents where the group was.
    func ungroup(_ groupId: String) throws(VError)
    /// Makes a node a detailed node with one new detail per edge (ADR-0032).
    func decompose(_ nodeId: String) throws(VError)
    /// Whether the node's type has a detailing, which is when `decompose` runs.
    func canDecompose(_ elementId: String) -> Bool
    /// Deletes a whole selection in one [[Snapshot]] — not the same as calling
    /// `delete` repeatedly, which would be one undo step per element.
    func delete(all ids: [String]) throws(VError)

    func setLabel(of elementId: String, to label: String) throws(VError)

    func setURL(of elementId: String, to url: String) throws(VError)
    func removeURL(from elementId: String) throws(VError)

    /// The link to hand the host, `nil` when there is none worth following.
    func urlToOpen(of elementId: String) -> String?

    /// `type` may be `nil` — the command only asks when more than one reversal
    /// is on offer.
    func changeDirection(
        of edgeId: String, to type: EdgeType.Id?, notationBreak: VNotationBreak
    ) throws(VError)

    /// The inserted node's id, when it is one worth naming.
    @discardableResult
    func split(_ edgeId: String, with candidate: VSplitCandidate) throws(VError) -> String?
    /// The [[Notation break]] path, for an edge with nothing to insert into.
    @discardableResult
    func split(_ edgeId: String, ofType node: NodeType) throws(VError) -> String?

    /// Make a group of these elements, and return its id so the caller can name
    /// it. Two forms because a node has exactly one parent group and clusters are
    /// strictly nested: a member of another group has to *leave* it, and
    /// `containing` refuses rather than restructuring boundaries the caller did
    /// not name. `moving` is the same command having been told that is fine — a
    /// pair like `split(_:with:)`/`split(_:ofType:)`, not a flag (ADR-0018).
    @discardableResult
    func addGroup(containing ids: [String]) throws(VError) -> String?
    @discardableResult
    func addGroup(moving ids: [String]) throws(VError) -> String?

    /// Change which group these elements belong to. Moving *out* is moving into
    /// the [[Root group]], so there is one command rather than two (ADR-0019).
    ///
    /// A [[Gesture]], with no menu entry: the drop target is what tells it apart
    /// from `connect`, so every adapter that wants it implements it by name.
    func move(_ ids: [String], into groupId: String, notationBreak: VNotationBreak) throws(VError)

    /// Add a node joined to nothing. `groupId` nil means the top level — how a
    /// caller with no pointer (a toolbar button) says so without learning the
    /// [[Root group]]'s id. A folded target group stays folded. Without ⌥ only
    /// a type the containment rule places there is accepted (ADR-0032).
    ///
    /// No default value: Swift forbids one in a protocol requirement, so it lives
    /// on the conforming type, as `changeType`'s do.
    @discardableResult
    func addNode(in groupId: String?, ofType type: NodeType, notationBreak: VNotationBreak) throws(VError) -> String?

    /// The new node's id, when the command made one worth naming.
    @discardableResult
    func addSuccessor(from nodeId: String, using edge: EdgeType.Id) throws(VError) -> String?
    /// The [[Notation break]] path: any node type, joined by an unknown edge type.
    @discardableResult
    func addSuccessor(from nodeId: String, ofType node: NodeType) throws(VError) -> String?
    @discardableResult
    func addPredecessor(to nodeId: String, using edge: EdgeType.Id) throws(VError) -> String?
    @discardableResult
    func addPredecessor(to nodeId: String, ofType node: NodeType) throws(VError) -> String?

    /// Retype a node, answering `ambiguousEdges(ifRetyping:to:)` positionally. The
    /// one command that still holds a conversation: how many edge questions
    /// there are depends on the type just chosen.
    func changeType(
        of nodeId: String, to type: NodeType, edgeTypes: [EdgeType.Id],
        notationBreak: VNotationBreak
    ) throws(VError)

    /// Retype an edge, both ends staying where they are. `using:` because the
    /// group form's `GroupType?` would make a `nil` call site ambiguous, and
    /// because `using:` is what names an edge type everywhere else here. `nil`
    /// only where there is nothing to choose.
    ///
    /// No [[Notation break]], as the group form has none: the list is empty only
    /// where the notation permits one type for a pair it already permits, and an
    /// unknown type there de-types a legal edge (ADR-0023). And no flip — both
    /// ends stay put, so reorienting remains `changeDirection`'s job (ADR-0021).
    func changeType(of edgeId: String, using type: EdgeType.Id?) throws(VError)

    /// `nil` makes a group plain again — untyped is a real state and not the
    /// absence of one, so the way back has to be sayable.
    ///
    /// No conversation to hold, unlike the node form: an edge's group is derived
    /// (ADR-0017), so retyping a boundary leaves nothing ambiguous. And no
    /// [[Notation break]]: a boundary kind the notation never registered is what a
    /// broken *document* produces, never something to offer.
    func changeType(of groupId: String, to type: GroupType?) throws(VError)

    /// Join two existing nodes. `edge` may be `nil` when only one type joins the
    /// pair — then the command picks it.
    func connect(
        _ from: String, to: String, using edge: EdgeType.Id?, notationBreak: VNotationBreak
    ) throws(VError)

    /// Give an edge wearing a minted type a real one, and declare it on the
    /// document's notation — the way *out* of a [[Notation break]].
    ///
    /// ⌥ still mints on a drag: cheap, visible, and nothing to answer. This is
    /// what promotes that red edge afterwards, when the author knows what the
    /// relationship is. The edge keeps its identity, so the label and the
    /// comments survive. `named` is refused with `edgeTypeNameRefused` when it
    /// is not an identifier this graph can take, which is the adapter's cue to
    /// ask again (ADR-0024).
    func declareEdgeType(for edgeId: String, named name: String) throws(VError)

    /// Move one [[Edge end]] to another node, keeping the edge's identity and
    /// everything written on it. `edge` follows `connect`'s rule: `nil` when
    /// there is nothing to choose.
    ///
    /// A [[Gesture]], with no menu entry: the handle grabbed is what tells it
    /// apart from `connect`, so every adapter that wants it implements it by
    /// name. One end at a time — the domain's form takes two optionals and can
    /// express a flip, which is `changeDirection`'s job (ADR-0021).
    func reattach(
        _ edgeId: String, end: VEdgeEnd, to nodeId: String, using edge: EdgeType.Id?,
        notationBreak: VNotationBreak
    ) throws(VError)
}
