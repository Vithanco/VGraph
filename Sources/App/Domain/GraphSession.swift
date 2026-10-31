// Stateful App-layer coordinator over one OriginGraph.

import VGraph

/// A live, stateful session over one **OriginGraph** — the single source of
/// truth (the rawest `VGraph`, parsed from VGL). Owns the in-memory graph and
/// composes the pure engine functions; adapter-agnostic (the WASM Editor drives
/// it). A [[VCommand]] mutates `origin` in place then re-exports/renders with no
/// reparse; only `textEdited`/`replaceDocument` reparse text into a fresh
/// `origin`.
/// `VGraph` is a value type, so rendering never mutates `origin`.
///
/// It is also the conformer for all three driving ports (`Sources/App/Ports/
/// Inbound/`, ADR-0013) — an adapter names the port its component needs rather
/// than this class and its parameters. A port is a contract and not a summary of
/// a class, so a new public member here needs a port decision: which of the
/// three, or none. `ArchitectureTest.everyPublicSessionMemberHasAPortDecision`
/// is what stops "or none" being chosen by default.
public final class GraphSession<
    Ports: AppPorts,
    VersionStore: ForStoreDocumentVersions,
    Observer: ForObserveDocumentChanges
> {
    private let app: VGraphApplication<Ports>

    /// The OriginGraph — the single source of truth.
    public private(set) var origin: VGraph

    /// Invariant: `origin` is always semantically
    /// `parse(store.vgl(of: store.current))`.
    private var store: VersionStore
    /// While a typing burst is open, edits amend the current version in place
    /// rather than cutting a new undo step (see [[Text-edit run]]).
    private var textRunOpen: Bool
    /// Told after each settled change, so views the session cannot see can catch
    /// up. One, not a list: fanning out is the adapter's job (ADR-0013).
    private let observer: Observer
    /// The view being shown, `nil` for the default view (the model). Navigation:
    /// never written to the document and never a history step. Presentation
    /// commands write to it while it is set (ADR-0029).
    private var shownView: String?
    private let display: (VGraph, String?) throws(VError) -> VGraph

    public init(
        app: VGraphApplication<Ports>,
        vgl: String,
        versionStore: VersionStore,
        observer: Observer,
        display: @escaping (VGraph, String?) throws(VError) -> VGraph = { (graph, view) throws(VError) in
            try graph.displaying(view: view)
        }
    ) throws(VError) {
        self.app = app
        self.display = display
        self.origin = try app.parseGraph(vgl)
        self.store = versionStore
        self.textRunOpen = false
        self.observer = observer
        self.shownView = nil
        try self.store.reset(vgl: vgl)
        // No announcement: construction is not a change, and nothing built
        // around this session can be listening yet.
    }

    /// Load a **new document**, resetting history (host push / example / `?vgl=`):
    /// undo can no longer cross back into what was open before. Contrast
    /// `textEdited`.
    public func replaceDocument(vgl: String) throws(VError) {
        origin = try app.parseGraph(vgl)
        try store.reset(vgl: vgl)
        textRunOpen = false
        shownView = nil
        observer.documentChanged()
    }

    /// A view that the document no longer declares cannot stay shown; the
    /// default view takes over, silently, since the author just removed it.
    private func settleShownView() {
        if let name = shownView, !origin.views.contains(where: { $0.name == name }) { shownView = nil }
    }

    /// The text-edit path: reparse `vgl` and fold it into the current [[Text-edit
    /// run]] — a continuous burst collapses into one undo step (the top entry is
    /// replaced in place) until sealed. Reparsing before mutating leaves `origin`
    /// and history untouched on a parse failure.
    public func textEdited(vgl: String) throws(VError) {
        guard vgl != currentVGL else { return }
        origin = try app.parseGraph(vgl)
        settleShownView()
        if textRunOpen {
            try store.amend(vgl: vgl)
        } else {
            try store.record(vgl: vgl)
            textRunOpen = true
        }
        observer.documentChanged()
    }

    /// The VGL of the version `origin` currently reflects.
    private var currentVGL: String? { store.vgl(of: store.current) }

    /// Seal the current [[Text-edit run]] so the next `textEdited` cuts a fresh
    /// undo step (called on textarea blur; commands and loads seal implicitly).
    public func textEditingEnded() {
        textRunOpen = false
    }

    /// The OriginGraph serialised back to VGL. Transform-free — see
    /// `exportDocument`. Reparsing this is semantically identical to `origin`.
    public func exportVGL() throws(VError) -> String {
        try app.exportDocument(graph: origin)
    }

    // MARK: - Undo / redo

    public var canUndo: Bool { store.canUndo }
    public var canRedo: Bool { store.canRedo }

    /// Step back one state, restoring the snapshot into `origin` and returning its
    /// VGL (`nil` at the oldest state).
    @discardableResult
    public func undo() throws(VError) -> String? {
        guard let ref = try store.undo() else { return nil }
        guard let vgl = store.vgl(of: ref) else {
            try store.redo()  // moved but can't produce text: put the store back
            return nil
        }
        return try restore(vgl)
    }

    /// Step forward one state (the inverse of `undo`). Returns the restored VGL,
    /// or `nil` if already at the newest state.
    @discardableResult
    public func redo() throws(VError) -> String? {
        guard let ref = try store.redo() else { return nil }
        guard let vgl = store.vgl(of: ref) else {
            try store.undo()
            return nil
        }
        return try restore(vgl)
    }

    /// Adopt a stored snapshot as the new `origin`, keeping the invariant that
    /// `origin` is always `parse` of the store's current version.
    private func restore(_ vgl: String) throws(VError) -> String {
        origin = try app.parseGraph(vgl)
        settleShownView()
        textRunOpen = false
        observer.documentChanged()
        return vgl
    }

    // MARK: - Diff

    /// The version `origin` currently reflects. Hold one to diff against later.
    public var currentVersion: VersionRef { store.current }

    /// `nil` if either version has aged out of the store.
    public func diff(from: VersionRef, to: VersionRef) -> [DiffLine]? {
        guard let oldVGL = store.vgl(of: from), let newVGL = store.vgl(of: to) else { return nil }
        return TextDiff.lines(from: oldVGL, to: newVGL)
    }

    public func diffToParent() -> [DiffLine]? {
        guard let (old, new) = parentAndCurrentVGL() else { return nil }
        return TextDiff.lines(from: old, to: new)
    }

    public func unifiedDiffToParent(context: Int = 3) -> String? {
        guard let (old, new) = parentAndCurrentVGL() else { return nil }
        return TextDiff.unified(from: old, to: new, context: context)
    }

    private func parentAndCurrentVGL() -> (old: String, new: String)? {
        guard let parent = store.parent(of: store.current),
            let old = store.vgl(of: parent),
            let new = currentVGL
        else { return nil }
        return (old, new)
    }

    /// Render the current OriginGraph to SVG, embedding its VGL for round-trip.
    ///
    /// `interactive: true` because this is the diagram *pane*'s render — every
    /// other caller reaches the renderer through the string form
    /// `renderGraph(_:darkMode:)` and keeps today's output (ADR-0021).
    public func render(darkMode: Bool = false) throws(VError) -> RenderResult {
        let vgl = try exportVGL()
        return try app.renderGraph(
            graph: origin, sourceVGL: vgl, view: shownView, darkMode: darkMode, interactive: true)
    }

    /// The VGL a rendered artefact carries. Relayed to the renderer, which is
    /// the only thing that knows how it was carried — the same shape as
    /// `render`, in the other direction.
    public func sourceVGL(from rendered: String) -> String? {
        app.sourceVGL(from: rendered)
    }

    /// The text an [[Inline edit]] starts from — the element's own label, `nil`
    /// if the id resolves to nothing.
    ///
    /// The one thing a diagram pane needs to *read* out of the graph, which is
    /// why `origin` is not on its port: everything else the pane displays is
    /// handed to it already decided (ADR-0013).
    public func label(of elementId: String) -> String? {
        guard let target = origin.resolveCommandTarget(id: elementId) else { return nil }
        return origin.label(of: target)
    }

    // MARK: - Queries a pane needs to build its own menu (phase 5)

    // Each resolves an element id and forwards to `origin`, because the pane has
    // ids and not `Node`s. This is the shape that lets `origin` stay off the
    // port: the pane asks precise questions instead of being handed the graph.

    /// The node this id names, or `nil` for a stale id or an element of another
    /// kind. A menu query shrugs where a named command refuses — see
    /// `target(_:_:)` for the strict half.
    private func node(_ elementId: String) -> Node? {
        guard case .node(let node)? = origin.resolveCommandTarget(id: elementId) else { return nil }
        return node
    }

    /// The edge half of `node(_:)`. An id rather than an `Edge`, because that is
    /// what `VCommandTarget.edge` carries.
    private func edge(_ elementId: String) -> Edge.Id? {
        guard case .edge(let edge)? = origin.resolveCommandTarget(id: elementId) else { return nil }
        return edge
    }

    /// What kind of thing this id names — what `appliesTo` decides today.
    public func kind(of elementId: String) -> VElementKind? {
        origin.resolveCommandTarget(id: elementId)?.kind
    }

    /// One of the two dynamic titles: "Fold group" vs "Unfold group".
    public func isFolded(_ groupId: String) -> Bool {
        guard case .group(let group)? = origin.resolveCommandTarget(id: groupId),
            let folded = try? shown.get(group: group, attribute: Attributes.Group.isFolded)
        else { return false }
        return folded
    }

    /// The node's own type, for a pane that wants to name it — or exclude it
    /// from a list of what the node could become.
    public func nodeType(of elementId: String) -> NodeType? {
        if case .group(let group)? = origin.resolveCommandTarget(id: elementId) {
            return origin.nodeType(of: group)
        }
        guard let node = node(elementId) else { return nil }
        return try? origin.nodeType(for: node)
    }

    public func isDetailed(_ elementId: String) -> Bool {
        guard case .group(let group)? = origin.resolveCommandTarget(id: elementId) else { return false }
        return origin.isDetailed(group)
    }

    public func detailCount(of elementId: String) -> Int {
        guard case .group(let group)? = origin.resolveCommandTarget(id: elementId), origin.isDetailed(group),
            let (groups, nodes) = try? origin.getDirectContent(group: group)
        else { return 0 }
        return groups.count + nodes.count
    }

    /// Whether renaming this element would show the user anything. False for a
    /// node type that displays no text of its own — an icon-only type has a
    /// label in the model and nowhere to type it (ADR-0009).
    public func canRename(_ elementId: String) -> Bool {
        let type: NodeType?
        switch origin.resolveCommandTarget(id: elementId) {
        case .node(let node)?: type = try? origin.nodeType(for: node)
        case .group(let group)? where origin.isDetailed(group): type = origin.nodeType(of: group)
        case .edge?, .group?: return true
        case nil: return false
        }
        guard let type else { return false }
        return origin.hasUserText(nodeType: type)
    }

    /// The link as stored, whatever it is. Two jobs: the other dynamic title
    /// ("Add URL…" vs "Change URL…") and seeding the field when the user edits
    /// it. Deliberately *not* `urlToOpen`, which is `nil` for a stored link too
    /// dangerous to follow — seeding from that would silently discard what the
    /// user had typed.
    public func storedURL(of elementId: String) -> String? {
        guard let target = origin.resolveCommandTarget(id: elementId) else { return nil }
        return origin.url(of: target)
    }

    public func successorCandidates(from nodeId: String) -> [VCandidate] {
        guard let node = node(nodeId) else { return [] }
        return origin.successorCandidates(from: node)
    }

    public func predecessorCandidates(to nodeId: String) -> [VCandidate] {
        guard let node = node(nodeId) else { return [] }
        return origin.predecessorCandidates(to: node)
    }

    public func retypeCandidates(for nodeId: String) -> [NodeType] {
        if case .group(let group)? = origin.resolveCommandTarget(id: nodeId) {
            return origin.retypeCandidates(for: group)
        }
        guard let node = node(nodeId) else { return [] }
        return origin.retypeCandidates(for: node)
    }

    /// What an edge could become without either end moving. `edge:` rather than
    /// `for:`, after `reattachCandidates(edge:end:to:)`: an overload differing
    /// from the node form only in return type would not resolve at a call site
    /// that reads `.first`.
    public func retypeCandidates(edge edgeId: String) -> [EdgeType] {
        guard let edge = edge(edgeId) else { return [] }
        return origin.retypeCandidates(edge: edge)
    }

    public func reverseCandidates(for edgeId: String) -> [EdgeType] {
        guard let edge = edge(edgeId) else { return [] }
        return origin.reverseCandidates(for: edge)
    }

    public func splitCandidates(for edgeId: String) -> [VSplitCandidate] {
        guard let edge = edge(edgeId) else { return [] }
        return origin.splitCandidates(for: edge)
    }

    /// The edges retyping `nodeId` to `type` leaves ambiguous, in the order the
    /// change asks about them. Usually empty.
    public func ambiguousEdges(ifRetyping nodeId: String, to type: NodeType) -> [VAmbiguousEdge] {
        guard let node = node(nodeId) else { return [] }
        return origin.ambiguousEdges(ifRetyping: node, to: type)
    }

    /// Every node a drag may start from — all of them. "Where can this go?" is
    /// answered by a red line while dragging, not by refusing the grab (ADR-0012).
    public func connectSources() -> [String] {
        var result: [String] = []
        for node in origin.nodes { result.append(node.id) }
        return result
    }

    /// Where a drag from `nodeId` may legally land. A permitted break opens
    /// every other node; otherwise only those the notation joins.
    public func connectTargets(
        from nodeId: String, notationBreak: VNotationBreak = .forbidden
    ) -> [String] {
        guard let grabbed = node(nodeId) else { return [] }

        var result: [String] = []
        for node in origin.nodes where node != grabbed {
            guard
                notationBreak == .permitted
                    || !origin.connectCandidates(from: grabbed, to: node).isEmpty
            else { continue }
            result.append(node.id)
        }
        return result
    }

    /// The edge types the notation allows between two existing nodes — the
    /// question a [[Gesture]] asks after the drop, when there is more than one.
    public func connectCandidates(from: String, to: String) -> [EdgeType] {
        guard let source = node(from), let destination = node(to) else { return [] }
        return origin.connectCandidates(from: source, to: destination)
    }

    /// Where a [[Reattach]] drag of `end` may legally land. A permitted break
    /// opens every node; otherwise only those the notation joins — counted
    /// against the graph minus this edge, which is what `reattachCandidates`
    /// does and `connectCandidates` cannot (ADR-0021).
    ///
    /// The node the end already occupies is excluded: releasing where you
    /// started is not an edit, and offering it would burn an undo step doing
    /// nothing. The *other* end's node is **not** excluded — a self-loop is a
    /// legal shape where the notation declares one, and unlike `connect` the
    /// drag did not begin there.
    public func reattachTargets(
        edge edgeId: String, end: VEdgeEnd, notationBreak: VNotationBreak = .forbidden
    ) -> [String] {
        guard case .edge(let edge)? = origin.resolveCommandTarget(id: edgeId),
            let existing = origin.get(edge: edge)
        else { return [] }
        let moving = end == .from ? existing.from : existing.to

        var result: [String] = []
        for node in origin.nodes where node != moving {
            guard
                notationBreak == .permitted
                    || !origin.reattachCandidates(edge: edge, end: end, to: node).isEmpty
            else { continue }
            result.append(node.id)
        }
        return result
    }

    /// The edge types the notation allows once `end` has moved to `nodeId` — the
    /// question the [[Gesture]] asks after the drop, when there is more than one.
    public func reattachCandidates(
        edge edgeId: String, end: VEdgeEnd, to nodeId: String
    ) -> [EdgeType] {
        guard case .edge(let edge)? = origin.resolveCommandTarget(id: edgeId),
            let node = node(nodeId)
        else { return [] }
        return origin.reattachCandidates(edge: edge, end: end, to: node)
    }

    /// The node id at one end of an edge — what a [[Reattach]] choice prompt
    /// needs for the end the drag left untouched.
    public func node(atEdge edgeId: String, end: VEdgeEnd) -> String? {
        guard case .edge(let edge)? = origin.resolveCommandTarget(id: edgeId),
            let existing = origin.get(edge: edge)
        else { return nil }
        return (end == .from ? existing.from : existing.to).id
    }

    /// Empty is the notation declining to name it, which reads the same to a
    /// caller as never having set one.
    public func menuTitle(ofEdgeType id: EdgeType.Id) -> String? {
        guard let title = try? origin.get(edgeType: id, attribute: Attributes.Edge.menuTitle),
            !title.isEmpty
        else { return nil }
        return title
    }

    /// Every type a [[Notation break]] may reach for. Unknown types are excluded:
    /// they exist only as the *result* of a break and are never offered as one.
    public func nodeTypes() -> [NodeType] {
        var result: [NodeType] = []
        for type in origin.nodeTypes where !type.id.hasPrefix(NodeType.unknownPrefix) {
            result.append(type)
        }
        return result
    }

    public func nodeTypes(placeableIn groupId: String) -> [NodeType] {
        let group = Group(rawValue: groupId)
        return nodeTypes().filter { origin.allows($0, in: group) }
    }

    /// The unknown type is excluded for the same reason an unknown node type is:
    /// it is the *result* of a bad document, never something to offer.
    public func groupTypes() -> [GroupType] {
        var result: [GroupType] = []
        for type in origin.groupTypes where !type.isUnknown {
            result.append(type)
        }
        return result
    }

    /// The group's own type, not one inherited from a group it sits inside.
    public func groupType(of elementId: String) -> GroupType? {
        guard case .group(let group)? = origin.resolveCommandTarget(id: elementId) else { return nil }
        return origin.groupType(of: group)
    }

    /// Asked for rather than hard-coded: a blank-canvas click carries no id, so
    /// the pane must be able to *name* the root before it can build a menu — and
    /// the constant's own name says it is internal (ADR-0016).
    public func rootGroupId() -> String { rootGroup }

    // MARK: - The commands (ADR-0013)

    // Thirteen named methods, and no registry behind them: each checks that its
    // arguments name something the notation allows, builds the changed graph
    // through a `VGraph` operation, and hands it to `commit`. An argument that
    // matches no candidate throws rather than quietly applying nothing.
    //
    // `changeType` is the one that still holds a conversation — it needs an
    // answer per edge its new type leaves ambiguous, and how many that is
    // depends on the type just chosen.

    /// Adopt a changed graph as the document.
    ///
    /// The one place a named command commits, so the rules live once: an
    /// unchanged export cuts no undo step and tells nobody, and any change seals
    /// the open [[Text-edit run]].
    ///
    /// The export runs *before* `origin` is replaced, so a graph that cannot be
    /// serialised is refused rather than adopted: the throw would otherwise leave
    /// the session holding an unexportable OriginGraph, and every later call
    /// would fail too. "A refusal changes nothing" is a property of commit and
    /// not only of the guards each command runs first.
    private func commit(_ edited: VGraph) throws(VError) {
        let changed = edited.removingFromViews(
            nodes: Set(origin.nodes.map { $0.id }).subtracting(edited.nodes.map { $0.id }),
            groups: Set(origin.groups.map { $0.id.id }).subtracting(edited.groups.map { $0.id.id }))
        let exported = try app.exportDocument(graph: changed)
        origin = changed
        guard exported != currentVGL else {
            textRunOpen = false
            return
        }
        try store.record(vgl: exported)
        textRunOpen = false
        observer.documentChanged()
    }

    /// The element this id names, or a refusal. Named commands do not shrug at a
    /// stale id the way a menu does.
    private func target(_ elementId: String, _ command: VCommandID) throws(VError) -> VCommandTarget {
        guard let target = origin.resolveCommandTarget(id: elementId) else {
            throw VError.commandUnavailable(command, target: elementId)
        }
        return target
    }

    /// The [[Root group]] has always resolved as an ordinary group, so every
    /// group command already ran against it and did something undefined —
    /// `delete` destructively. Nothing could reach it until the menu could
    /// (ADR-0016).
    private func refuseRoot(_ elementId: String, _ command: VCommandID) throws(VError) {
        guard elementId != rootGroup else {
            throw VError.commandUnavailable(command, target: elementId)
        }
    }

    /// What the pane shows: the origin read through the shown view.
    /// Getters cannot report a failure and fall back to the model; commands use `shownGraph()`.
    private var shown: VGraph { (try? shownGraph()) ?? origin }

    private func shownGraph() throws(VError) -> VGraph { try display(origin, shownView) }

    public func toggleFolding(of groupId: String) throws(VError) {
        try refuseRoot(groupId, .toggleFolding)
        guard case .group(let group) = try target(groupId, .toggleFolding) else {
            throw VError.commandUnavailable(.toggleFolding, target: groupId)
        }
        let folded: Bool = try shownGraph().get(group: group, attribute: Attributes.Group.isFolded)
        let flipped = try Attributes.Group.isFolded.attribute(!folded)
        if let view = shownView {
            try commit(origin.settingInView(view, flipped, for: ItemKey(.group, groupId)))
        } else {
            try commit(origin.set(group: group, attribute: flipped))
        }
    }

    public func loopMarkers() -> LoopMarkers? {
        origin.marksLoops ? shown.loopMarkers : nil
    }

    public func setLoopMarkers(_ markers: LoopMarkers) throws(VError) {
        guard origin.marksLoops else { throw VError.commandUnavailable(.loopMarkers, target: rootGroup) }
        try setPresentation(Attributes.Group.loopMarkers.attribute(markers))
    }

    /// A setting of the whole diagram goes to the shown view, or to the model.
    private func setPresentation(_ attribute: Attribute) throws(VError) {
        if let view = shownView {
            try commit(origin.settingInView(view, attribute, for: .root))
        } else {
            try commit(origin.set(graphAttribute: attribute))
        }
    }

    public func layoutDirection() -> LayoutDirection {
        (try? shown.get(attribute: Attributes.Group.layoutDirection)) ?? .topToBottom
    }

    public func setLayoutDirection(_ direction: LayoutDirection) throws(VError) {
        try setPresentation(Attributes.Group.layoutDirection.attribute(direction))
    }

    // MARK: - Views

    public func views() -> [ViewDeclaration] { origin.views }

    public func activeView() -> String? { shownView }

    /// Navigation: the document, its history and its export stay as they are.
    public func selectView(_ name: String?) throws(VError) {
        if let name, !origin.views.contains(where: { $0.name == name }) {
            throw VError.unknownView(name, available: origin.views.map { $0.name })
        }
        shownView = name
    }

    private func newViewName(forLabel label: String) throws(VError) -> String {
        guard let name = VGraph.viewName(forLabel: label, taken: origin.views.map { $0.name }) else {
            throw VError.viewLabelRefused(label: label)
        }
        return name
    }

    public func createView(label: String) throws(VError) {
        let name = try newViewName(forLabel: label)
        try commit(origin.declaring(view: ViewDeclaration(name: name, label: label)))
        shownView = name
    }

    public func duplicateActiveView(label: String) throws(VError) {
        guard let source = shownView else { throw VError.defaultViewIsFixed }
        let name = try newViewName(forLabel: label)
        try commit(origin.duplicating(view: source, as: ViewDeclaration(name: name, label: label)))
        shownView = name
    }

    public func renameView(_ name: String?, label: String) throws(VError) {
        guard let name else { throw VError.defaultViewIsFixed }
        guard !label.allSatisfy({ $0 == " " }) else { throw VError.viewLabelRefused(label: label) }
        try commit(origin.relabelling(view: name, as: label))
    }

    public func deleteView(_ name: String?) throws(VError) {
        guard let name else { throw VError.defaultViewIsFixed }
        try commit(origin.removing(view: name))
        if shownView == name { shownView = nil }
    }

    public func delete(_ elementId: String) throws(VError) {
        try refuseRoot(elementId, .delete)
        switch try target(elementId, .delete) {
        case .node(let node):
            // A command that empties a group removes it, cascading upward
            // (ADR-0018). Part of *this* change, so one undo brings back the
            // node and the boundary it was the last of.
            let held = origin.group(of: node)
            try commit(origin.delete(node: node).removingEmptied(from: held))
        case .edge(let edge): try commit(origin.delete(edge: edge))
        // Contents and all. `ungroup` is how you keep them (ADR-0018).
        case .group(let group): try commit(origin.deletingWithContents(group))
        }
    }

    /// An empty label restores the type's placeholder rather than storing "" —
    /// an absent label does not survive a reparse unchanged (ADR-0009).
    ///
    /// Returns nothing. It used to hand back the element to open an [[Inline
    /// edit]] on, which is what calling the *generic* command with no answer
    /// meant; a named call always carries the text, so the adapter opens the
    /// editor itself and calls this to commit ("Rename" and a double-click are
    /// still one command — the editor makes them so).
    public func setLabel(of elementId: String, to label: String) throws(VError) {
        try refuseRoot(elementId, .setLabel)
        let target = try target(elementId, .setLabel)
        // A node type that displays no text of its own has a label in the model
        // and nowhere to show it, so renaming it would change nothing visible.
        guard canRename(elementId) else {
            throw VError.commandUnavailable(.setLabel, target: elementId)
        }
        let text = label.isEmpty ? Attributes.Node.placeholderLabel : label
        try commit(origin.set(label: text, on: target))
    }

    /// Blank clears the link — the user already has the field open, so sending
    /// them to `removeURL` for it would be silly. Anything `VURL` will not accept
    /// is refused, and the adapter re-asks holding what was typed.
    public func setURL(of elementId: String, to url: String) throws(VError) {
        try refuseRoot(elementId, .setURL)
        let target = try target(elementId, .setURL)

        if VURL.isBlank(url) {
            try commit(origin.set(url: "", on: target))
            return
        }
        guard let safe = VURL.safe(url) else {
            throw VError.urlRefused(target: elementId, url: url)
        }
        try commit(origin.set(url: safe, on: target))
    }

    /// Works for *any* stored link, unlike `urlToOpen` — one too dangerous to
    /// follow is one you especially want to be able to delete. "" is the declared
    /// default, so the exporter drops it and a reparse sees no link.
    public func removeURL(from elementId: String) throws(VError) {
        try refuseRoot(elementId, .removeURL)
        guard origin.url(of: try target(elementId, .removeURL)) != nil else {
            throw VError.commandUnavailable(.removeURL, target: elementId)
        }
        try commit(origin.set(url: "", on: try target(elementId, .removeURL)))
    }

    /// The link to hand the host, or `nil` when there is none worth following —
    /// a URL typed straight into the VGL never passed `VURL`. A query, because
    /// opening it changes no graph.
    public func urlToOpen(of elementId: String) -> String? {
        guard let target = origin.resolveCommandTarget(id: elementId),
            let url = origin.url(of: target)
        else { return nil }
        // Not merely "has a url": one typed straight into the VGL never passed
        // `VURL`, and an item offered as openable must open when clicked.
        return VURL.safe(url)
    }

    /// `type` may be `nil` **only when there is nothing to choose** — one
    /// reversal the command picks itself, or none, where a permitted break
    /// reverses anyway. With more than one it throws rather than guess, so ask
    /// `reverseCandidates(for:)` first (`EditorCore.reversalOptions` wraps that
    /// judgement and is what the editor uses).
    public func changeDirection(
        of edgeId: String, to type: EdgeType.Id? = nil,
        notationBreak: VNotationBreak = .forbidden
    ) throws(VError) {
        guard case .edge(let edge) = try target(edgeId, .changeDirection) else {
            throw VError.commandUnavailable(.changeDirection, target: edgeId)
        }
        let candidates = origin.reverseCandidates(for: edge)
        // The notation offering no reversal is what makes this breakable.
        guard !candidates.isEmpty || notationBreak == .permitted else {
            throw VError.commandUnavailable(.changeDirection, target: edgeId)
        }

        guard candidates.count > 1 else {
            guard let only = candidates.first else {
                try commit(origin.reversingWithUnknownType(edge))
                return
            }
            try commit(origin.reversing(edge, as: only))
            return
        }

        guard let type else {
            throw VError.commandAnswersMismatched(.changeDirection, target: edgeId)
        }
        guard let chosen = candidates.named(type) else {
            throw VError.commandOptionNotOffered(
                .changeDirection, target: edgeId, option: type.id)
        }
        try commit(origin.reversing(edge, as: chosen))
    }

    /// The inserted node's id, when it is one worth naming — an icon-only node
    /// type gives `nil` and there is nothing to open an editor on.
    @discardableResult
    public func split(_ edgeId: String, with candidate: VSplitCandidate) throws(VError) -> String? {
        guard case .edge(let edge) = try target(edgeId, .split) else {
            throw VError.commandUnavailable(.split, target: edgeId)
        }
        guard !origin.splitCandidates(for: edge).isEmpty else {
            throw VError.commandUnavailable(.split, target: edgeId)
        }
        let (changed, created) = try origin.splitting(
            edge, into: candidate.nodeType, incoming: candidate.incoming,
            outgoing: candidate.outgoing)
        try commit(changed)
        return created?.id
    }

    /// The [[Notation break]] path, for an edge the notation gives nothing to
    /// insert into: any node type, joined by unknown edge types. Asking for it
    /// *is* permitting the break, so there is nothing to grey out.
    @discardableResult
    public func split(_ edgeId: String, ofType node: NodeType) throws(VError) -> String? {
        guard case .edge(let edge) = try target(edgeId, .split) else {
            throw VError.commandUnavailable(.split, target: edgeId)
        }
        let (changed, created) = try origin.splitting(
            edge, into: node, incoming: nil, outgoing: nil)
        try commit(changed)
        return created?.id
    }

    /// Delete a whole [[Effective selection]] in one [[Snapshot]].
    ///
    /// Not the adapter calling `delete` in a loop: that would be one undo step
    /// per element, and the user who deleted five things would have to press ⌘Z
    /// five times to get them back.
    ///
    /// The set is collapsed first, so a boundary whose members were all selected
    /// is what gets deleted — and a group takes its contents with it.
    public func delete(all ids: [String]) throws(VError) {
        let members = origin.outermostElements(of: ids)
        guard !members.isEmpty else {
            throw VError.commandUnavailable(.delete, target: "")
        }
        var changed = origin
        for member in members {
            try refuseRoot(member, .delete)
            guard let element = changed.resolveCommandTarget(id: member) else { continue }
            switch element {
            case .node(let node):
                let held = changed.group(of: node)
                changed = try changed.delete(node: node).removingEmptied(from: held)
            case .edge(let edge):
                changed = try changed.delete(edge: edge)
            case .group(let group):
                changed = try changed.deletingWithContents(group)
            }
        }
        try commit(changed)
    }

    /// Take a group apart, leaving its contents where the group was.
    public func ungroup(_ groupId: String) throws(VError) {
        try refuseRoot(groupId, .ungroup)
        guard case .group(let group) = try target(groupId, .ungroup) else {
            throw VError.commandUnavailable(.ungroup, target: groupId)
        }
        try commit(origin.ungrouping(group))
    }

    public func decompose(_ nodeId: String) throws(VError) {
        guard case .node(let node) = try target(nodeId, .decompose) else {
            throw VError.commandUnavailable(.decompose, target: nodeId)
        }
        let group = Group(rawValue: node.id)
        try commit(origin.decomposing(node).unfolding(group, onlyIn: shownView))
    }

    public func canDecompose(_ elementId: String) -> Bool {
        guard case .node(let node) = origin.resolveCommandTarget(id: elementId) else { return false }
        return origin.canDecompose(node)
    }

    /// The [[Effective selection]] of a set the pane is holding. A query, not a
    /// command: nothing is recorded, because a selection is never the document's
    /// (ADR-0018).
    public func outermostElements(of ids: [String]) -> [String] {
        origin.outermostElements(of: ids)
    }

    public func groupingTarget(for ids: [String]) -> VGroupingTarget? {
        origin.groupingTarget(for: ids)
    }

    public func moveDestinations(
        for ids: [String], notationBreak: VNotationBreak = .forbidden
    ) -> [String] {
        origin.moveDestinations(for: ids, notationBreak: notationBreak)
    }

    /// A folded destination stays folded: folding is the author's alone.
    public func move(
        _ ids: [String], into groupId: String, notationBreak: VNotationBreak = .forbidden
    ) throws(VError) {
        try commit(origin.moving(ids, into: groupId, notationBreak: notationBreak))
    }

    /// Make a group of these, refusing if anything would have to leave the group
    /// it is in.
    @discardableResult
    public func addGroup(containing ids: [String]) throws(VError) -> String? {
        try makeGroup(ids, detaching: false)
    }

    /// The same, having been told that detaching is intended. One command is one
    /// [[Snapshot]], so the whole restructuring is a single undo — which is why
    /// it needs no confirmation beyond a menu row that says what it will do.
    @discardableResult
    public func addGroup(moving ids: [String]) throws(VError) -> String? {
        try makeGroup(ids, detaching: true)
    }

    private func makeGroup(_ ids: [String], detaching: Bool) throws(VError) -> String? {
        let (changed, created) = try origin.addingGroup(of: ids, detaching: detaching)
        try commit(changed)
        return created.id.id
    }

    public func addNode(
        in groupId: String? = nil, ofType type: NodeType, notationBreak: VNotationBreak = .forbidden
    ) throws(VError) -> String? {
        var group: Group? = nil
        if let groupId {
            guard case .group(let named) = try target(groupId, .addNode) else {
                throw VError.commandUnavailable(.addNode, target: groupId)
            }
            group = named
        }
        guard notationBreak == .permitted || origin.allows(type, in: group) else {
            throw VError.commandOptionNotOffered(.addNode, target: groupId ?? rootGroupId(), option: type.id)
        }
        let (changed, created) = try origin.addingNode(ofType: type, in: group)
        try commit(changed)
        return created?.id
    }

    /// The new node's id, or `nil` if the command produced nothing to name.
    @discardableResult
    public func addSuccessor(from nodeId: String, using edge: EdgeType.Id) throws(VError) -> String? {
        try addRelated(nodeId, using: edge, outgoing: true)
    }

    /// The [[Notation break]] path: any node type, joined by an unknown edge
    /// type. Asking for it *is* permitting the break, so nothing greys it out —
    /// which is what makes it reachable on a type the notation leads nowhere from.
    @discardableResult
    public func addSuccessor(from nodeId: String, ofType node: NodeType) throws(VError) -> String? {
        try addRelated(nodeId, ofType: node, outgoing: true)
    }

    @discardableResult
    public func addPredecessor(to nodeId: String, using edge: EdgeType.Id) throws(VError) -> String? {
        try addRelated(nodeId, using: edge, outgoing: false)
    }

    @discardableResult
    public func addPredecessor(to nodeId: String, ofType node: NodeType) throws(VError) -> String? {
        try addRelated(nodeId, ofType: node, outgoing: false)
    }

    /// Successor and predecessor are one operation with the ends swapped, so
    /// they are one body here too — the direction is the only thing that differs.
    private func addRelated(
        _ nodeId: String, using edge: EdgeType.Id, outgoing: Bool
    ) throws(VError) -> String? {
        let command: VCommandID = outgoing ? .addSuccessor : .addPredecessor
        guard case .node(let source) = try target(nodeId, command) else {
            throw VError.commandUnavailable(command, target: nodeId)
        }
        let candidates =
            outgoing
            ? origin.successorCandidates(from: source)
            : origin.predecessorCandidates(to: source)
        // The notation offering nothing is what makes this breakable — and the
        // break has its own overload, so this one refuses.
        guard !candidates.isEmpty else {
            throw VError.commandUnavailable(command, target: nodeId)
        }

        guard let chosen = candidates.joined(by: edge) else {
            throw VError.commandOptionNotOffered(command, target: nodeId, option: edge.id)
        }

        let (changed, created) = try origin.addingRelated(
            to: source, ofType: chosen.nodeType, using: chosen.edgeType, outgoing: outgoing)
        try commit(changed)
        return created?.id
    }

    private func addRelated(
        _ nodeId: String, ofType type: NodeType, outgoing: Bool
    ) throws(VError) -> String? {
        let command: VCommandID = outgoing ? .addSuccessor : .addPredecessor
        guard case .node(let source) = try target(nodeId, command) else {
            throw VError.commandUnavailable(command, target: nodeId)
        }
        let (changed, created) = try origin.addingRelated(
            to: source, ofType: type, using: nil, outgoing: outgoing)
        try commit(changed)
        return created?.id
    }

    /// Retype a node, answering `ambiguousEdges(ifRetyping:to:)` positionally.
    ///
    /// The one command that still holds a conversation: how many edge questions
    /// there are depends on the type just chosen, so ask first and pass the
    /// answers in the order they came back. Passing none is right whenever the
    /// list was empty, which is the common case.
    public func changeType(
        of nodeId: String, to type: NodeType, edgeTypes: [EdgeType.Id] = [],
        notationBreak: VNotationBreak = .forbidden
    ) throws(VError) {
        let target = try target(nodeId, .changeType)
        if case .group(let group) = target, origin.isDetailed(group) {
            try changeType(ofDetailedNode: group, to: type, edgeTypes: edgeTypes, notationBreak: notationBreak)
            return
        }
        guard case .node(let node) = target else {
            throw VError.commandUnavailable(.changeType, target: nodeId)
        }
        // The notation offering nothing to become is what makes this breakable.
        let candidates = origin.retypeCandidates(for: node)
        guard !candidates.isEmpty || notationBreak == .permitted else {
            throw VError.commandUnavailable(.changeType, target: nodeId)
        }
        guard candidates.contains(type) || notationBreak == .permitted else {
            throw VError.commandOptionNotOffered(.changeType, target: nodeId, option: type.id)
        }
        // The answers are positional, so a caller holding a different number of
        // them is holding a different list of questions — and its answers may
        // line up with edges it was never asked about.
        guard edgeTypes.count == origin.ambiguousEdges(ifRetyping: node, to: type).count else {
            throw VError.commandAnswersMismatched(.changeType, target: nodeId)
        }

        try commit(origin.retyping(node, to: type, edgeTypes: edgeTypes))
    }

    /// A detailed node keeps its details whatever it becomes; with ⌥ the
    /// containment check then reports those that no longer fit (ADR-0032). Its
    /// edges end at its details, so there are no edge questions to answer.
    private func changeType(
        ofDetailedNode group: Group, to type: NodeType, edgeTypes: [EdgeType.Id],
        notationBreak: VNotationBreak
    ) throws(VError) {
        let groupId = group.id.id
        guard edgeTypes.isEmpty else {
            throw VError.commandAnswersMismatched(.changeType, target: groupId)
        }
        let candidates = origin.retypeCandidates(for: group)
        guard !candidates.isEmpty || notationBreak == .permitted else {
            throw VError.commandUnavailable(.changeType, target: groupId)
        }
        guard candidates.contains(type) || (notationBreak == .permitted && origin.has(nodeType: type)) else {
            throw VError.commandOptionNotOffered(.changeType, target: groupId, option: type.id)
        }
        try commit(origin.typing(group: group, as: type))
    }

    /// Retype an edge, both ends staying where they are.
    ///
    /// `using:` and not `to:`, because the group form's `GroupType?` would make
    /// a `nil` call site ambiguous — and because an edge type is what `using:`
    /// names everywhere else on this port. `nil` only where there is nothing to
    /// choose, as `changeDirection`'s `to:` is.
    ///
    /// No `notationBreak`, following the group form and for the group's reason:
    /// the list is empty only when the notation permits one type for a pair it
    /// already permits, and minting an unknown type there de-types a legal edge
    /// into a quality warning. There is no rule here worth breaking (ADR-0023).
    public func changeType(of edgeId: String, using type: EdgeType.Id? = nil) throws(VError) {
        guard case .edge(let edge) = try target(edgeId, .changeType) else {
            throw VError.commandUnavailable(.changeType, target: edgeId)
        }
        let candidates = origin.retypeCandidates(edge: edge)
        guard !candidates.isEmpty else {
            throw VError.commandUnavailable(.changeType, target: edgeId)
        }

        if let type {
            guard let chosen = candidates.named(type) else {
                throw VError.commandOptionNotOffered(.changeType, target: edgeId, option: type.id)
            }
            // Both ends `nil`: the identity, the label, the comments and the
            // edge's place in the document all survive, and a flip is unreachable rather than
            // merely refused (ADR-0021, ADR-0023).
            try commit(origin.reattach(edge: edge, edgeType: chosen))
            return
        }

        guard candidates.count == 1 else {
            throw VError.commandAnswersMismatched(.changeType, target: edgeId)
        }
        try commit(origin.reattach(edge: edge, edgeType: candidates[0]))
    }

    public func changeType(of groupId: String, to type: GroupType?) throws(VError) {
        try refuseRoot(groupId, .changeType)
        // A detailed node is typed by its node type; a boundary kind would
        // replace it.
        guard case .group(let group) = try target(groupId, .changeType), !origin.isDetailed(group) else {
            throw VError.commandUnavailable(.changeType, target: groupId)
        }
        guard let type else {
            try commit(origin.typing(group: group, as: nil))
            return
        }
        guard groupTypes().contains(where: { $0.id == type.id }) else {
            throw VError.commandOptionNotOffered(.changeType, target: groupId, option: type.id)
        }
        try commit(origin.typing(group: group, as: type))
    }

    /// Join two existing nodes. `edge` may be `nil` when only one edge type
    /// joins the pair — the command picks it.
    public func connect(
        _ from: String, to: String, using edge: EdgeType.Id? = nil,
        notationBreak: VNotationBreak = .forbidden
    ) throws(VError) {
        guard case .node(let source) = try target(from, .connect),
            case .node(let destination) = try target(to, .connect),
            source != destination
        else { throw VError.commandUnavailable(.connect, target: to) }

        // ⌥ is this gesture's escape hatch rather than an "Other type…" entry:
        // it mints an unknown type outright, even over a pair the notation would
        // have joined. So a permitted break asks nothing.
        //
        // Minted *here* rather than inside `connecting`, which takes a
        // non-optional type: every mint site is then visible at its call site
        // instead of hiding behind a `nil` that also serves the ordinary path
        // (ADR-0024).
        guard notationBreak == .forbidden else {
            let (minted, unknown) = try origin.ensureUnknownEdgeType(
                from: try origin.nodeType(for: source), to: try origin.nodeType(for: destination))
            try commit(minted.connecting(source, to: destination, using: unknown))
            return
        }

        let candidates = origin.connectCandidates(from: source, to: destination)
        guard candidates.count > 1 else {
            guard let only = candidates.first else {
                throw VError.commandUnavailable(.connect, target: to)
            }
            try commit(origin.connecting(source, to: destination, using: only))
            return
        }

        guard let edge else { throw VError.commandAnswersMismatched(.connect, target: to) }
        guard let chosen = candidates.named(edge) else {
            throw VError.commandOptionNotOffered(.connect, target: to, option: edge.id)
        }
        try commit(origin.connecting(source, to: destination, using: chosen))
    }

    /// Give an edge wearing a minted type a real one, and declare it.
    ///
    /// The way *out* of a [[Notation break]] rather than a second way into one:
    /// ⌥ still mints on a drag, cheaply and with nothing to answer, and this is
    /// what turns that red edge into a relationship the notation names. The
    /// edge keeps its identity — `reattach` with both ends unmoved, so the
    /// label, the comments and its place in the document all survive (ADR-0023, ADR-0024).
    public func declareEdgeType(for edgeId: String, named name: String) throws(VError) {
        guard case .edge(let edge) = try target(edgeId, .changeType),
            let existing = origin.get(edge: edge)
        else { throw VError.commandUnavailable(.changeType, target: edgeId) }

        guard origin.canDeclare(edgeTypeNamed: name) else {
            throw VError.edgeTypeNameRefused(name: name)
        }

        let wasWearing = try origin.edgeType(for: edge).id
        let sourceType = try origin.nodeType(for: existing.from)
        let targetType = try origin.nodeType(for: existing.to)
        let (declared, edgeType) = try origin.declaring(
            EdgeType.Id(string: name), from: sourceType, to: targetType)
        var result = try declared.reattach(edge: edge, edgeType: edgeType)

        // Take the minted type away with the last edge wearing it. Promotion
        // makes the document a `vnotation`, and `reconstructVNotation` emits
        // *every* declaration — so an orphan would be written into the block as
        // a dead `edge type: __UNKNOWN_EDGE_TYPE__…` line, on every export
        // afterwards. Only when nothing references it: two broken edges over
        // one pair share a single minted type.
        if wasWearing.id.hasPrefix(EdgeType.unknownPrefix),
            !result.edges.contains(where: { (try? result.edgeType(for: $0.id))?.id == wasWearing })
        {
            result = try result.delete(edgeType: wasWearing)
        }
        try commit(result)
    }

    /// Whether this edge wears a minted type — the one state `declareEdgeType`
    /// exists to leave, and what makes **Change type** reachable on an edge the
    /// notation offers nothing else for.
    public func hasUnknownType(edge edgeId: String) -> Bool {
        guard let edge = edge(edgeId), let type = try? origin.edgeType(for: edge) else {
            return false
        }
        return type.isUnknown
    }

    /// Move one [[Edge end]] to `nodeId`, keeping the edge's id, its label and
    /// its comments. `edge` follows `connect`'s rule: `nil` when there is
    /// nothing to choose.
    ///
    /// The type must be restated rather than kept, and cannot simply be carried:
    /// `add(edge:)` refuses a type whose declared ends do not match the actual
    /// node types, so a moved end usually needs a different one — and a break
    /// mints an unknown type rather than preserving the old (ADR-0021).
    public func reattach(
        _ edgeId: String, end: VEdgeEnd, to nodeId: String, using edge: EdgeType.Id? = nil,
        notationBreak: VNotationBreak = .forbidden
    ) throws(VError) {
        guard case .edge(let target) = try self.target(edgeId, .reattach),
            case .node(let landing) = try self.target(nodeId, .reattach),
            let existing = origin.get(edge: target)
        else { throw VError.commandUnavailable(.reattach, target: edgeId) }

        // Releasing where the end already is is not an edit. Refused rather than
        // ignored, so it cannot burn an undo step doing nothing.
        let moving = end == .from ? existing.from : existing.to
        guard landing != moving else {
            throw VError.commandUnavailable(.reattach, target: nodeId)
        }

        // ⌥ mints outright, exactly as it does for `connect`, and for the same
        // reason: a drag has no list on screen for it to widen.
        guard notationBreak == .forbidden else {
            let newFrom = end == .from ? landing : existing.from
            let newTo = end == .to ? landing : existing.to
            let (minted, unknown) = try origin.ensureUnknownEdgeType(
                from: try origin.nodeType(for: newFrom), to: try origin.nodeType(for: newTo))
            try commit(minted.reattaching(target, end: end, to: landing, using: unknown))
            return
        }

        let candidates = origin.reattachCandidates(edge: target, end: end, to: landing)
        guard candidates.count > 1 else {
            guard let only = candidates.first else {
                // Onto a detail, R1 decides the type and the move never fails (ADR-0032).
                guard origin.isDetailType(try origin.nodeType(for: landing), of: try origin.nodeType(for: moving))
                else { throw VError.commandUnavailable(.reattach, target: nodeId) }
                try commit(
                    origin.reattachRetyping(
                        edge: target, from: end == .from ? landing : nil, to: end == .to ? landing : nil))
                return
            }
            try commit(origin.reattaching(target, end: end, to: landing, using: only))
            return
        }

        guard let edge else { throw VError.commandAnswersMismatched(.reattach, target: edgeId) }
        guard let chosen = candidates.named(edge) else {
            throw VError.commandOptionNotOffered(.reattach, target: edgeId, option: edge.id)
        }
        try commit(origin.reattaching(target, end: end, to: landing, using: chosen))
    }

    // MARK: - Highlighting

    /// Highlight HTML for the text pane's overlay, through the app's highlighter.
    /// Takes the source rather than reading `origin`, because the per-keystroke
    /// pass runs on text that has not been `edit`ed in yet — and may not parse.
    ///
    /// Here rather than only on `VGraphApplication` so that a text pane needs
    /// `ForEditVGL` alone: reaching the app would make it name `Ports` again,
    /// which is what the driving ports exist to avoid.
    public func highlightHTML(
        _ input: String, semantic: Bool, diagnostics: QualityReport? = nil
    ) -> String {
        app.highlightHTML(input, semantic: semantic, diagnostics: diagnostics)
    }
}

// MARK: - Driving ports (ADR-0013)

extension GraphSession: ForEditVGL {}

extension GraphSession: ForEditAGraphVisually {}

extension GraphSession: ForManageADocument {}
