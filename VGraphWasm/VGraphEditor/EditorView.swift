//
//  EditorView.swift
//  VGraphEditor
//

import App
import EditorCore
import ElementaryUI
import JavaScriptKit
import VGraph

@View
struct EditorView {
    var body: some View {
        div {
            if editorModel.fileMenuAt != nil { FileMenu() }
            if editorModel.viewMenuAt != nil { ViewMenu() }
            if editorModel.displayMenuAt != nil { DisplayPanel() }
            if editorModel.menuVisible { ContextMenuPanel() }

            div {}
                .attributes(.id(DOMId.dragOverlay))

            if let placement = editorModel.inlineEdit { InlineEditor(placement: placement) }

            Toolbar()

            div {
                div {
                    SourcePane()
                    Preview()
                }
                .attributes(.custom(name: "class", value: "vg-editor-panes"))

                DiagnosticsPane()
            }
            .attributes(.custom(name: "class", value: "vg-editor-body"))
        }
        .attributes(
            .custom(name: "class", value: rootClasses())
        )
        // On the root so keydowns bubbling up from the focused textarea are caught.
        .onKeyDownRaw { handleKeyDown($0) }
        .onKeyUpRaw { handleKeyUp($0) }
        .onPointerMoveRaw { event in handlePointerMove(event) }
        .onPointerUpRaw { event in handleRelease(event) }
        .onPointerCancelRaw { _ in abandonGesture() }
    }
}

// MARK: - Menus

@View
struct DismissLayer {
    var onPress: () -> Void

    var body: some View {
        div {}
            .attributes(.custom(name: "class", value: "vg-dismiss"))
            .onPointerDownRaw { _ in onPress() }
    }
}

/// A greyed row is still clickable: what it means is re-checked by whoever
/// runs it, so the row only has to look unavailable.
@View
struct MenuRow {
    var title: String
    var enabled: Bool
    var onPick: (MouseEvent) -> Void

    var body: some View {
        button { title }
            .onClick { event in onPick(event) }
            .attributes(
                .custom(name: "class", value: enabled ? "vg-ctx-item" : "vg-ctx-item vg-ctx-disabled"))
    }
}

/// Borrows the context menu's panel and dismiss layer so it inherits the dark
/// theme with it.
@View
struct FileMenu {
    var body: some View {
        DismissLayer(onPress: { editorModel.fileMenuAt = nil })

        div {
            MenuRow(title: "Open…", enabled: true) { _ in
                editorModel.fileMenuAt = nil
                openFile()
            }
            MenuRow(title: "Save VGL", enabled: true) { _ in
                editorModel.fileMenuAt = nil
                saveVGL()
            }
            MenuRow(title: "Save SVG", enabled: true) { _ in
                editorModel.fileMenuAt = nil
                saveSVG()
            }
            MenuRow(title: "Copy link", enabled: true) { _ in
                editorModel.fileMenuAt = nil
                copyShareLink()
            }
        }
        .attributes(
            .id(DOMId.fileMenuPanel),
            .custom(name: "class", value: "vg-ctx-menu"),
            .custom(name: "style", value: dropdownPositionStyle(editorModel.fileMenuAt)))
    }
}

@View
struct ViewMenu {
    var body: some View {
        DismissLayer(onPress: { editorModel.viewMenuAt = nil })

        div {
            ForEach(viewPickerOptions, key: { $0.key }) { choice in
                MenuRow(title: (choice.isSelected ? "✓ " : "") + choice.title, enabled: true) { _ in
                    editorModel.viewMenuAt = nil
                    viewPicked(choice.name ?? "")
                }
            }
            div {}
                .attributes(.custom(name: "class", value: "vg-ctx-sep"))
            ForEach(viewMenuRows(), key: { $0.id.raw }) { row in
                MenuRow(title: row.title, enabled: row.enabled) { _ in
                    if row.enabled {
                        performViewCommand(row.id)
                    } else {
                        editorModel.viewMenuAt = nil
                    }
                }
            }
        }
        .attributes(
            .id(DOMId.viewMenuPanel),
            .custom(name: "class", value: "vg-ctx-menu"),
            .custom(name: "style", value: dropdownPositionStyle(editorModel.viewMenuAt)))
    }
}

/// Text is asked here only for what the element does not display — a label is
/// typed inline (ADR-0009).
@View
struct ContextMenuPanel {
    var body: some View {
        DismissLayer(onPress: { dismissMenu() })

        div {
            switch editorModel.prompt {
            case .choice(let title):
                div { title }
                    .attributes(.custom(name: "class", value: "vg-ctx-head"))
                ForEach(promptOptions, key: { $0.id }) { option in
                    MenuRow(title: option.title, enabled: true) { _ in optionPicked(option) }
                }
            case .text(let title):
                div { title }
                    .attributes(.custom(name: "class", value: "vg-ctx-head"))
                input()
                    .attributes(
                        .id(DOMId.promptInput),
                        .custom(name: "class", value: "vg-ctx-input"),
                        .custom(name: "value", value: pendingText),
                        .custom(
                            name: "placeholder",
                            value: title == "URL" ? "https://…" : "")
                    )
                    .onInput { event in
                        pendingText = event.targetValue ?? ""
                    }
                    .onKeyDown { event in
                        if event.key == "Enter" { textSubmitted() }
                        if event.key == "Escape" { dismissMenu() }
                    }
                    .onAppear {
                        guard
                            let field = element(DOMId.promptInput)
                        else { return }
                        _ = field.focus?()
                        _ = field.select?()
                    }
                MenuRow(title: "OK", enabled: true) { _ in textSubmitted() }
            case .commands:
                // `ForEach`, not a bare `for`: the latter's buildArray only
                // accepts plain HTML, and these rows carry ElementaryUI
                // modifiers.
                ForEach(menuItems, key: { $0.id.raw + ($0.target ?? "") }) { item in
                    MenuRow(title: item.title, enabled: item.enabled) { event in
                        performCommand(item.id, on: item.target, forcingChoice: event.altKey)
                    }
                }
            }
        }
        .attributes(
            .custom(name: "class", value: "vg-ctx-menu"),
            .custom(name: "style", value: contextMenuPositionStyle()))
    }
}

// MARK: - Inline editor

/// Deliberately *outside* the SVG (ADR-0009): every render replaces the
/// preview's innerHTML, which would destroy anything nested in it mid-edit. No
/// dismiss layer — blur leaves it open on purpose, and a render closes it.
@View
struct InlineEditor {
    var placement: InlineEditPlacement

    var body: some View {
        input()
            .attributes(
                .id(DOMId.inlineEdit),
                .custom(name: "class", value: "vg-inline-edit"),
                .custom(name: "value", value: pendingText),
                .custom(name: "style", value: inlineEditPositionStyle(placement))
            )
            .onInput { event in
                pendingText = event.targetValue ?? ""
            }
            // `onKeyDownRaw` for `preventDefault`: both keys remove the field
            // and refocus the textarea, so without it the key's default action
            // runs against the textarea instead — Enter typed a newline into
            // the document and armed the debounce.
            .onKeyDownRaw { event in
                guard event.key == "Enter" || event.key == "Escape" else { return }
                event.preventDefault()
                if event.key == "Enter" { commitInlineEdit() } else { endInlineEdit() }
            }
            // Clicking away finishes the edit. Safe against the paths that
            // remove the field themselves — Escape and a render both clear
            // `inlineEdit` first, so the blur they cause hits the
            // empty-target guard and does nothing.
            .onBlur { commitInlineEdit() }
            .onAppear {
                guard
                    let field = element(DOMId.inlineEdit)
                else { return }
                _ = field.focus?()
                // Select the placeholder so typing replaces it outright.
                _ = field.select?()
            }
    }
}

// MARK: - Toolbar

/// Title strip and menu bar in one. The editor owns it rather than the host
/// page, so mounting the editor brings the whole bar.
@View
struct Toolbar {
    var body: some View {
        div {
            div { "Vithanco" }
                .attributes(.custom(name: "class", value: "vg-toolbar-title"))

            select {
                option { "Examples…" }
                for ex in exampleGraphs {
                    option { ex.name }
                }
            }
            .attributes(.id(DOMId.examples))
            .onInput { event in
                let name = event.targetValue ?? ""
                if let ex = exampleGraphs.first(where: { $0.name == name }) {
                    setEditorVGL(text: ex.vgl)
                    // Reset the dropdown so the same example can be re-selected
                    // (imperative; the select's options are static so the
                    // reconciler won't fight this).
                    if let sel = element(DOMId.examples) {
                        sel.value = "".jsValue
                    }
                }
            }

            button { editorModel.shownViewTitle.isEmpty ? "Default view ▾" : editorModel.shownViewTitle + " ▾" }
                .attributes(.id(DOMId.viewMenuButton))
                .onClick { toggleViewMenu() }

            button { "File ▾" }
                .attributes(.id(DOMId.fileMenuButton))
                .onClick { toggleFileMenu() }

            // The picker the File menu clicks. Hidden but *in* the managed tree
            // — that is what makes its `change` fire (a Swift-authored
            // addEventListener never would; see the header of `Editor.swift`).
            input()
                .attributes(
                    .id(DOMId.fileInput),
                    .custom(name: "type", value: "file"),
                    .custom(name: "accept", value: ".vgl,.svg,text/plain,image/svg+xml")
                )
                .onChangeRaw { handleFilePicked() }

            // The discoverable way in: right-clicking blank canvas is the better
            // interface and nobody tries it unprompted — and the first node of
            // a diagram has nothing else to right-click.
            button { "＋ Node" }
                .onClickRaw { event in addNodeFromToolbar(event) }
                .attributes(.custom(name: "class", value: "vg-gap"))

            // Here for its *disabled* state as much as its enabled one: a
            // control that lights up when you select two things is the only
            // thing telling a user that selection exists (ADR-0018).
            button { "▣ Group" }
                .onClick { groupFromToolbar() }
                .attributes(.custom(name: "class", value: editorModel.groupable ? "vg-gap" : "vg-gap vg-unavailable"))

            button { "↶" }
                .onClick { performUndo() }
                .attributes(
                    .id(DOMId.undo), .custom(name: "title", value: "Undo"),
                    .custom(name: "class", value: editorModel.canUndo ? "vg-gap" : "vg-gap vg-unavailable"))
            button { "↷" }
                .onClick { performRedo() }
                .attributes(
                    .id(DOMId.redo), .custom(name: "title", value: "Redo"),
                    .custom(name: "class", value: editorModel.canRedo ? "" : "vg-unavailable"))

            DisplayControls()
        }
        .attributes(.custom(name: "class", value: "vg-toolbar"))
    }
}

@View
struct DisplayControls {
    var body: some View {
        button { editorModel.zoom.label + " ▾" }
            .attributes(
                .id(DOMId.displayButton), .custom(name: "class", value: "vg-gap"),
                .custom(name: "title", value: "Zoom and theme")
            )
            .onClick { toggleDisplayPanel() }
        button { "◧" }
            .onClick { editorModel.sourceHidden = !editorModel.sourceHidden }
            .attributes(
                .id(DOMId.sourceToggle),
                .custom(name: "class", value: editorModel.sourceHidden ? "vg-pressed" : ""),
                .custom(name: "title", value: editorModel.sourceHidden ? "Show the source pane" : "Hide the source pane"))
        if canEnlarge {
            button { "⤢" }
                .onClick { enlarge() }
                .attributes(.id(DOMId.enlarge), .custom(name: "title", value: "Full window"))
        }
    }
}

@View
struct DisplayPanel {
    var body: some View {
        DismissLayer(onPress: { editorModel.displayMenuAt = nil })

        div {
            div {
                button { "−" }
                    .onClick { zoomStep(.out) }
                    .attributes(.custom(name: "title", value: "Zoom out"))
                button { "+" }
                    .onClick { zoomStep(.in) }
                    .attributes(.custom(name: "title", value: "Zoom in"))
                button { "Fit" }
                    .onClick { setZoom(.fit) }
                    .attributes(.custom(name: "title", value: "Fit the whole diagram in the pane"))
                button { "100%" }
                    .onClick { setZoom(.fixed(1)) }
                    .attributes(.custom(name: "title", value: "Natural size"))
            }
            .attributes(.custom(name: "class", value: "vg-display-row"))
            MenuRow(title: editorModel.darkMode ? "☀ Light theme" : "☾ Dark theme", enabled: true) { _ in
                editorModel.displayMenuAt = nil
                // Plain assignment, not `.toggle()`: the `_modify` accessor
                // on a @Reactive property crashes the Embedded SIL
                // optimizer when inlined into a closure.
                editorModel.darkMode = !editorModel.darkMode
                performRender()
            }
        }
        .attributes(
            .id(DOMId.displayPanel),
            .custom(name: "class", value: "vg-ctx-menu"),
            .custom(name: "style", value: rightAlignedPositionStyle(editorModel.displayMenuAt)))
    }
}

func rootClasses() -> String {
    var classes = "vg-editor-root"
    if editorModel.darkMode { classes += " vg-dark" }
    if editorModel.sourceHidden { classes += " vg-no-source" }
    if editorModel.sourceHidden && editorModel.diagnosticsOpen { classes += " vg-diag-open" }
    return classes
}

// MARK: - Panes

/// Only the width is inline: the splitter changes it.
func controlsPaneStyle() -> String {
    "width:\(Int(editorModel.controlsWidthPx))px;"
}

@View
struct SourcePane {
    var body: some View {
        div {
            // Transparent-text textarea over a `<pre>` highlight layer in one
            // scroll wrapper. Both keep NO ElementaryUI content child, so the
            // reconciler never touches the textarea's `.value` or the `<pre>`'s
            // injected HTML (seeded in `.onAppear`, read via `.onInput`).
            div {
                pre {}
                    .attributes(.id(DOMId.highlight), .custom(name: "aria-hidden", value: "true"))
                textarea {}
                    .attributes(.id(DOMId.source), .custom(name: "spellcheck", value: "false"))
                    .onInput { event in
                        let text = event.targetValue ?? ""
                        // No edit, so nothing to reparse and no debounce to arm
                        // — one firing later would close an open inline editor
                        // (ADR-0009).
                        guard text != editorModel.vgl else { return }
                        editorModel.vgl = text
                        repaintHighlight(semantic: false)
                        autosizeTextarea()
                        scheduleRender()
                    }
                    .onMouseMove { event in
                        updateHoverTitle(x: event.clientX, y: event.clientY)
                    }
                    .onBlur { graphSession?.textEditingEnded() }
                    .onAppear {
                        setTextareaValue(editorModel.vgl)
                        repaintHighlight(semantic: false)
                        autosizeTextarea()
                        // Session already holds this VGL (built in mountEditor);
                        // reload to stay robust if the model changed before
                        // mount, then render.
                        reloadAndRender()
                        restoreDraftView()
                        if draftWasRestored {
                            draftWasRestored = false
                            editorModel.status = "Restored your unsaved diagram from last time"
                        }
                    }
            }
            .attributes(.id(DOMId.sourceWrap))

            div {
                button { "Render" }
                    .onClick { reloadAndRender() }
                span {
                    " "
                    EditorCore.statusLine(editorModel.status, viewTitle: editorModel.shownViewTitle)
                }
                .attributes(.id(DOMId.status))
            }
            .attributes(.custom(name: "class", value: "vg-render-row"))

            div {}
                .attributes(.custom(name: "class", value: "vg-splitter"))
                .onPointerDownRaw { _ in editorModel.isResizing = true }

            if editorModel.isResizing {
                div {}
                    .attributes(.custom(name: "class", value: "vg-resize-overlay"))
                    .onPointerMoveRaw { event in
                        let w = max(240, min(960, editorModel.controlsWidthPx + event.movementX))
                        editorModel.controlsWidthPx = w
                    }
                    .onPointerUpRaw { _ in editorModel.isResizing = false }
                    .onPointerCancelRaw { _ in editorModel.isResizing = false }
            }
        }
        .attributes(
            .id(DOMId.controls),
            .custom(name: "style", value: controlsPaneStyle()))
    }
}

/// ElementaryUI-managed but kept childless, like the textarea: the engine's SVG
/// is injected via innerHTML in `performRender`. Being in the managed tree is
/// what lets its events fire (a Swift-authored addEventListener never would;
/// see the header of `Editor.swift`).
@View
struct Preview {
    var body: some View {
        div {}
            .attributes(.id(DOMId.preview))
            .onContextMenu { event in handleContextMenu(event) }
            .onDoubleClick { event in handleDoubleClick(event) }
            .onPointerDownRaw { event in handlePress(event) }
            .onWheelRaw { event in handleWheel(event) }
    }
}

/// Childless `#vg-editor-diagnostics`, filled imperatively by
/// `renderDiagnostics`.
@View
struct DiagnosticsPane {
    var body: some View {
        div {
            // With the source hidden the status line goes with it, so the head
            // stands in for it: one line, opening the full list on a click.
            div {
                editorModel.sourceHidden
                    ? EditorCore.statusLine(editorModel.status, viewTitle: editorModel.shownViewTitle) + " ▴"
                    : "Diagnostics"
            }
            .attributes(.id(DOMId.diagnosticsHead), .custom(name: "class", value: "vg-diag-head"))
            .onClick {
                if editorModel.sourceHidden { editorModel.diagnosticsOpen = !editorModel.diagnosticsOpen }
            }
            div {}
                .attributes(.id(DOMId.diagnostics))
        }
        .attributes(.custom(name: "class", value: "vg-diag-pane"))
    }
}
