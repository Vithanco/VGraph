//
//  EditorState.swift
//  VGraphEditor
//

import App
import EditorCore
import JavaScriptKit
import Reactivity
import VGraph

// A ConceptMap joins two Concepts *through* a Relation — `idea -> detail` is a
// pair the notation does not carry, so the old default opened with a red edge
// and "1 error(s)" on the status line. It is the first thing anyone sees.
let defaultVGL = """
    vgraph demo: ConceptMap "Demo" {
      node idea: Concept "Idea";
      node leadsTo: Relation "leads to";
      node detail: Concept "Detail";
      edge idea -> leadsTo;
      edge leadsTo -> detail;
    }
    """

/// The options and the typed text are not here but in module globals beside
/// `menuItems`, out of the reconciler's sight (ADR-0013).
enum Prompt: Equatable {
    case commands
    case choice(title: String)
    case text(title: String)
}

/// In viewport (client) coordinates.
struct InlineEditPlacement: Equatable {
    let targetId: String
    let x: Double
    let y: Double
    let width: Double
}

// Every grouped field is a value with `let` members, so a change is a whole
// assignment. A nested mutation would go through the @Reactive `_modify`
// accessor, which crashes the Embedded SIL optimizer when inlined into a
// closure.
@Reactive
final class EditorModel {
    var vgl: String
    var status: String
    var darkMode: Bool
    var isResizing: Bool
    var controlsWidthPx: Double

    // How the diagram is drawn in the preview, and how much of the window it
    // gets. View state only: none of it reaches the document or a view.
    var zoom: Zoom
    var sourceHidden: Bool
    var diagnosticsOpen: Bool

    // The right-click menu's position is set before it opens, by whatever is
    // about to ask; its items live in the module-global `menuItems`.
    var menuVisible: Bool
    var menuTargetId: String
    var menuAt: VPoint
    var prompt: Prompt

    var inlineEdit: InlineEditPlacement?

    // Their own state rather than a mode of `menuVisible`, so neither can
    // inherit the context menu's target or in-flight command.
    var fileMenuAt: VPoint?
    var viewMenuAt: VPoint?
    var displayMenuAt: VPoint?

    // The view being shown (ADR-0029): its name and what to call it, both empty
    // for the default view.
    var shownView: String
    var shownViewTitle: String

    // Mirrored from the GraphSession so the toolbar buttons react.
    var canUndo: Bool
    var canRedo: Bool

    // Derived from `selection`, which is not reactive, so the toolbar has
    // something to grey itself with. The greying is most of why that button
    // exists — it is the only thing telling a user selection is a thing at
    // all (ADR-0018).
    var groupable: Bool

    init(vgl: String) {
        self.vgl = vgl
        self.status = "Ready"
        self.darkMode = false
        self.isResizing = false
        self.controlsWidthPx = 440
        self.zoom = .fit
        self.sourceHidden = false
        self.diagnosticsOpen = false
        self.menuVisible = false
        self.menuTargetId = ""
        self.menuAt = .zero
        self.prompt = .commands
        self.inlineEdit = nil
        self.fileMenuAt = nil
        self.viewMenuAt = nil
        self.displayMenuAt = nil
        self.shownView = ""
        self.shownViewTitle = ""
        self.canUndo = false
        self.canRedo = false
        self.groupable = false
    }
}

// Single-threaded wasm: module-global singletons are safe.
nonisolated(unsafe) let editorModel = EditorModel(vgl: defaultVGL)
// Composition root: highlights per keystroke and mints `graphSession`.
// Held rather than rebuilt because constructing one wires the whole
// Graphviz layout pipeline.
nonisolated(unsafe) let app = VGraphWasmApp()
// The live GraphSession — owns the OriginGraph (source of truth). Built in
// `mountEditor`. Commands mutate it in place; text edits reparse it.
nonisolated(unsafe) var graphSession: VGraphWasmSession? = nil
// Commands to show in the open context menu (set by handleContextMenu just
// before flipping `menuVisible`; read by the view). Non-reactive: the menu's
// visibility is the reactive trigger.
nonisolated(unsafe) var menuItems: [MenuItem] = []
// Whether the open menu was built from the [[Selection]] rather than from a
// single pointed element — false only for the blank-canvas menu, which
// addresses the [[Root group]] and clears the selection to get there.
nonisolated(unsafe) var menuFromSelection = false
// The in-flight command conversation (ADR-0013), or `nil` when no command
// is asking anything. What it holds and what each answer settles is decided
// by `EditorCore`; this is only where it lives between turns. Non-reactive
// for the same reason as `menuItems` — `prompt` is the reactive trigger.
nonisolated(unsafe) var conversation: Conversation? = nil
// The options a choice prompt offers. Non-reactive, as `menuItems` is.
nonisolated(unsafe) var promptOptions: [VCommandOption] = []
// The text request's live value. Deliberately *not* reactive: a reactive bind
// would re-render the input on every keystroke and fight the caret, the same
// reason the VGL textarea is written through `setTextareaValue`.
nonisolated(unsafe) var pendingText: String = ""
// The most recent successfully-rendered SVG, held so "Save SVG" has something
// to download without re-rendering.
nonisolated(unsafe) var lastRenderedSVG: String = ""
// The name the saves reuse, and the only trace an opened file leaves: there
// is no file *handle* behind it, so a save is always a fresh download.
nonisolated(unsafe) var documentBaseName: String = EditorCore.defaultDocumentName
// Set at mount when the last session's work came back, and reported *after* the
// first render rather than during mount: ElementaryUI paints the tree
// afterwards, and the textarea's `.onAppear` renders and stamps its own status
// over anything set before it.
nonisolated(unsafe) var draftWasRestored = false
// Handle of the pending debounced-render `setTimeout` (a JS timer id), held
// so the next keystroke can `clearTimeout` it. `.undefined` when none.
nonisolated(unsafe) var renderTimerHandle: JSValue = .undefined
