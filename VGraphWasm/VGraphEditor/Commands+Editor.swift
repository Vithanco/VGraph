//
//  Commands+Editor.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import VGraph
import VGraphSVG

/// Run the chosen VCommand against the menu's target: apply the graph change
/// (mutates the session's OriginGraph in place), push the re-exported VGL
/// into the text editor, and render from the mutated graph — no reparse.
/// Pure in-process Swift, so every embedding host inherits it on the next
/// WASM rebuild.
///
/// `forcingChoice` is ⌥ held on the menu click. One gesture, two effects: show
/// the candidate list even when there is only one candidate, and permit the
/// command to go beyond the notation — both are "give me more than the
/// notation offers".
func performCommand(_ commandId: VCommandID, on itemTarget: String? = nil, forcingChoice: Bool = false) {
    let targetId = itemTarget ?? editorModel.menuTargetId
    guard !targetId.isEmpty else {
        dismissMenu()
        return
    }

    // Commands about a *set* rather than an element. Both are reached only
    // from a selection menu, and both are one [[Snapshot]] however many
    // elements they name (ADR-0018).
    if menuFromSelection, commandId == .addGroup || commandId == .delete {
        performSelectionCommand(commandId)
        return
    }

    openConversation(commandId, on: targetId, forcingChoice: forcingChoice)
}

/// Ask `EditorCore` where a command starts. The text is folded in first, as
/// every command that reads the graph does — the question is about the graph
/// the user can see, not the one before their last keystroke.
func openConversation(
    _ commandId: VCommandID, on targetId: String, forcingChoice: Bool
) {
    guard let session = sessionSyncedToText() else { return }
    let (step, opened) = EditorCore.begin(
        commandId, on: targetId, forcingChoice: forcingChoice, in: session)
    conversation = opened
    apply(step)
}

/// Deciding reads `graphSession` rather than `sessionSyncedToText()`: the
/// question on screen was asked about the graph as it stood, and a keystroke
/// behind the menu must not change what the answer means. The text is folded
/// in by `perform`, on the way to the command itself.
func optionPicked(_ option: VCommandOption) {
    guard let current = conversation, let session = graphSession else {
        dismissMenu()
        return
    }
    let (step, answered) = EditorCore.next(after: option, in: current, session: session)
    conversation = answered
    apply(step)
}

func apply(_ step: ConversationStep) {
    switch step {
    case .ask(let prompt, let options):
        showChoice(prompt: prompt, options: options)
    case .askText(let prompt, let initial):
        showText(prompt: prompt, initial: initial)
    case .perform(let action):
        perform(action)
    case .dismiss:
        dismissMenu()
    }
}

/// The named call the conversation settled on (ADR-0013). The two tails
/// differ only in what follows: a command that makes a node opens an
/// [[Inline edit]] on it, and one that does not simply refreshes.
private func perform(_ action: EditorAction) {
    switch action {
    case .toggleFolding(let group):
        runNamed { s throws(VError) in try s.toggleFolding(of: group) }

    case .ungroup(let group):
        runNamed { s throws(VError) in try s.ungroup(group) }

    case .decompose(let node):
        runNamed { s throws(VError) in try s.decompose(node) }

    case .delete(let element):
        runNamed { s throws(VError) in try s.delete(element) }

    case .removeURL(let element):
        runNamed { s throws(VError) in try s.removeURL(from: element) }

    case .openURL(let element):
        openNamedURL(element)

    case .rename(let element):
        renameCommand(element)

    case .addNode(let group, let type, let allowed):
        applyMakingNode(group) { s throws(VError) in try s.addNode(in: group, ofType: type, notationBreak: allowed) }

    case .addRelated(let target, let outgoing, let edge):
        applyMakingNode(target) { s throws(VError) in
            outgoing
                ? try s.addSuccessor(from: target, using: edge)
                : try s.addPredecessor(to: target, using: edge)
        }

    case .addRelatedBreaking(let target, let outgoing, let type):
        applyMakingNode(target) { s throws(VError) in
            outgoing
                ? try s.addSuccessor(from: target, ofType: type)
                : try s.addPredecessor(to: target, ofType: type)
        }

    case .connect(let from, let to, let using, let allowed):
        runNamed { s throws(VError) in
            try s.connect(from, to: to, using: using, notationBreak: allowed)
        }

    case .declareEdgeType(let edge, let name):
        // The refusal path `setURL` already walks: a name the graph will not
        // take re-opens the field rather than closing the conversation.
        guard let session = sessionSyncedToText() else { return }
        do {
            try session.declareEdgeType(for: edge, named: name)
            commandApplied(edit: nil, in: session)
        } catch {
            guard let current = conversation else { return }
            apply(EditorCore.next(afterRefusing: error, typed: name, in: current))
        }

    case .reattach(let edge, let end, let to, let using, let allowed):
        runNamed { s throws(VError) in
            try s.reattach(edge, end: end, to: to, using: using, notationBreak: allowed)
        }

    case .split(let edge, let candidate):
        applyMakingNode(edge) { s throws(VError) in try s.split(edge, with: candidate) }

    case .splitBreaking(let edge, let type):
        applyMakingNode(edge) { s throws(VError) in try s.split(edge, ofType: type) }

    case .changeType(let node, let type, let edgeTypes, let allowed):
        runNamed { s throws(VError) in
            try s.changeType(
                of: node, to: type, edgeTypes: edgeTypes, notationBreak: allowed)
        }

    case .changeGroupType(let group, let type):
        runNamed { s throws(VError) in try s.changeType(of: group, to: type) }

    case .setLoopMarkers(let markers):
        runNamed { s throws(VError) in try s.setLoopMarkers(markers) }

    case .setLayoutDirection(let direction):
        runNamed { s throws(VError) in try s.setLayoutDirection(direction) }

    case .createView(let label):
        askingAgainIfRefused(label) { s throws(VError) in try s.createView(label: label) }

    case .duplicateView(let label):
        askingAgainIfRefused(label) { s throws(VError) in try s.duplicateActiveView(label: label) }

    case .renameView(let name, let label):
        askingAgainIfRefused(label) { s throws(VError) in try s.renameView(name, label: label) }

    case .deleteView(let name):
        runNamed { s throws(VError) in try s.deleteView(name) }

    case .changeEdgeType(let edge, let using):
        runNamed { s throws(VError) in try s.changeType(of: edge, using: using) }

    case .setURL(let element, let url):
        guard let session = sessionSyncedToText() else { return }
        do {
            try session.setURL(of: element, to: url)
            commandApplied(edit: nil, in: session)
        } catch {
            // `setURL` is `throws(VError)`, so `error` is already one —
            // no untyped binding for Embedded Swift to object to.
            guard let current = conversation else { return }
            apply(EditorCore.next(afterRefusing: error, typed: url, in: current))
        }

    case .changeDirection(let edge, let to, let allowed):
        runNamed { s throws(VError) in
            try s.changeDirection(of: edge, to: to, notationBreak: allowed)
        }
    }
}

/// `openURL` changes no graph, so there is nothing to re-export or render —
/// but the text is still folded in first, as for every command.
private func openNamedURL(_ targetId: String) {
    guard let session = sessionSyncedToText() else { return }
    let url = session.urlToOpen(of: targetId)
    dismissMenu()
    if let url { openInNewTab(url) }
}

/// Bring the whole surface up to date after a command changed the graph.
func commandApplied(
    edit: (elementId: String, kind: VElementKind)?, in session: VGraphWasmSession
) {
    dismissMenu()
    syncSurface(to: (try? session.exportVGL()) ?? editorModel.vgl)
    // After the render, never before: a render closes any open editor, so
    // opening first would have the command cancel its own request.
    if let edit {
        beginInlineEdit(elementId: edit.elementId, kind: edit.kind)
    } else {
        focusEditor()
    }
}

/// The session with the textarea folded in, or `nil` when the text will not
/// parse — then the graph the user right-clicked is the last good one and
/// nothing should act on it.
func sessionSyncedToText() -> VGraphWasmSession? {
    guard let session = graphSession,
        (try? session.textEdited(vgl: editorModel.vgl)) != nil
    else {
        dismissMenu()
        return nil
    }
    return session
}

/// Seeded from the step, not the field: whether a re-ask holds what was
/// typed is `EditorCore`'s decision, not this function's.
private func showText(prompt: String, initial: String) {
    pendingText = initial
    editorModel.prompt = .text(title: prompt)
    editorModel.menuVisible = true
}

/// A typed answer settles a conversation exactly as a picked one does.
func textSubmitted() {
    guard let current = conversation else {
        dismissMenu()
        return
    }
    let (step, answered) = EditorCore.next(afterText: pendingText, in: current)
    conversation = answered
    apply(step)
}

func showChoice(prompt: String, options: [VCommandOption]) {
    promptOptions = options
    editorModel.prompt = .choice(title: prompt)
    editorModel.menuVisible = true
}

/// "Rename" changes nothing — it opens an [[Inline edit]] on the element.
/// The menu has already greyed it where a node type shows no user text, so
/// there is nothing left to ask, and this is the one migrated command that
/// calls no named method at all. The surface is still refreshed first,
/// because folding the textarea in may have moved the graph the editor is
/// about to position itself against.
func renameCommand(_ targetId: String) {
    guard let session = sessionSyncedToText(), let kind = session.kind(of: targetId) else {
        return
    }
    // Deliberately *not* `commandApplied`: nothing was applied. Re-seeding
    // the textarea from a canonical export without the session recording it
    // leaves `currentVGL` and the visible text disagreeing, and the next
    // sync then reparses — which renumbers edge ids and strands the id this
    // editor is about to open on. Opening an editor changes nothing, so it
    // touches nothing.
    dismissMenu()
    beginInlineEdit(elementId: targetId, kind: kind)
}

/// No pointer, so it names the [[Root group]] itself — and it must seed the
/// prompt's position, which a right-click would have set on its way past.
func addNodeFromToolbar(_ event: RawPointerEvent) {
    guard let session = graphSession else { return }
    dismissMenu()
    editorModel.menuTargetId = session.rootGroupId()
    editorModel.menuAt = VPoint(x: event.clientX, y: event.clientY)
    performCommand(.addNode)
}

/// Shared tail: the named method hands back the new node's id when it made
/// one worth naming, and that is what the inline editor opens on. An
/// icon-only node type returns nil and nothing opens, as before.
private func applyMakingNode(
    _ targetId: String, _ body: (VGraphWasmSession) throws(VError) -> String?
) {
    guard let session = sessionSyncedToText() else { return }
    do {
        let created = try body(session)
        commandApplied(edit: created.map { (elementId: $0, kind: .node) }, in: session)
    } catch {
        dismissMenu()
    }
}

/// A label the domain will not take re-opens the field with what was typed,
/// as `setURL` does; any other refusal closes the menu.
private func askingAgainIfRefused(
    _ typed: String, _ body: (VGraphWasmSession) throws(VError) -> Void
) {
    guard let session = sessionSyncedToText() else { return }
    do {
        try body(session)
        commandApplied(edit: nil, in: session)
    } catch {
        guard let current = conversation else { return }
        apply(EditorCore.next(afterRefusing: error, typed: typed, in: current))
    }
}

/// Run a named command that asks the user nothing. A stale or disabled click
/// throws, and is still nothing worth reporting — it closes the menu.
func runNamed(_ body: (VGraphWasmSession) throws(VError) -> Void) {
    guard let session = sessionSyncedToText() else { return }
    do {
        try body(session)
        commandApplied(edit: nil, in: session)
    } catch {
        dismissMenu()
    }
}

/// Hand a link to the browser. `noopener` because the opened page must not
/// reach back through `window.opener`; the URL was restricted to real link
/// schemes by `VURL` before it got here.
private func openInNewTab(_ url: String) {
    _ = JSObject.global.open?(url.jsValue, "_blank".jsValue, "noopener,noreferrer".jsValue)
}

/// Close the menu and drop any in-flight conversation. Nothing to unwind:
/// no answer has touched the graph until the command said `.applied`.
func dismissMenu() {
    editorModel.menuVisible = false
    editorModel.prompt = .commands
    conversation = nil
    promptOptions = []
    pendingText = ""
}
