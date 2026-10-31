//
//  EditorStyle.swift
//  VGraphEditor
//

/// Injected into `<head>`, out of the ElementaryUI-managed tree, so the
/// reconciler never touches it. The root carries `.vg-dark` when dark.
let editorStyleCSS = """
    .vg-toolbar { display:flex; align-items:center; gap:8px; flex:0 0 auto;
      padding:8px 20px; color:#fff; white-space:nowrap;
      background:linear-gradient(135deg,#EA580C 0%,#FF8000 100%); }
    .vg-toolbar { flex-wrap:wrap; row-gap:4px; }
    .vg-ctx-sep { height:1px; margin:4px 0; background:#eee; }
    .vg-display-row { display:flex; gap:6px; padding:6px 10px; }
    .vg-display-row button { font:13px system-ui,sans-serif; color:#222; background:#fff;
      border:1px solid #ccc; border-radius:4px; padding:4px 10px; cursor:pointer; }
    .vg-display-row button:hover { background:#eef3ff; }
    .vg-toolbar-title { font:600 18px system-ui,sans-serif; margin-right:auto; }
    .vg-toolbar select, .vg-toolbar button { font:13px system-ui,sans-serif; color:#fff;
      background:rgba(255,255,255,0.16); border:1px solid rgba(255,255,255,0.5);
      border-radius:4px; padding:4px 10px; cursor:pointer; }
    .vg-toolbar select:hover, .vg-toolbar button:hover { background:rgba(255,255,255,0.3); }
    /* A select is as wide as its widest option, and the example names are long;
       the popup list still shows them whole. */
    .vg-toolbar select { width:120px; }
    /* The popup list is drawn by the OS on its own surface, where inheriting
       the white toolbar text would leave it unreadable. */
    .vg-toolbar option { color:#1a1a1a; background:#fff; }
    .vg-toolbar .vg-pressed { background:rgba(255,255,255,0.38); }
    .vg-toolbar .vg-gap { margin-left:8px; }
    /* Still clickable: the session no-ops at a boundary. */
    .vg-toolbar .vg-unavailable { opacity:0.4; }
    #vg-file-input { display:none; }
    .vg-editor-root { display:flex; flex-direction:column; height:100%; min-height:0; }
    .vg-editor-body { display:flex; flex-direction:column; gap:12px;
      flex:1 1 auto; min-height:0; padding:16px 20px; }
    .vg-editor-panes { display:flex; gap:16px; flex:1 1 auto; min-height:0; }
    /* `position:relative` anchors the splitter to its right edge. */
    #vg-editor-controls { flex:0 0 auto; position:relative; display:flex;
      flex-direction:column; min-height:0; }
    #vg-vgl-input-wrap { position:relative; flex:1 1 auto; min-height:140px; overflow:auto;
      border:1px solid #ccc; border-radius:3px; background:#ffffff; }
    #vg-vgl-highlight, #vg-vgl-input { margin:0; width:100%; box-sizing:border-box;
      font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:13px; line-height:1.45;
      padding:8px; white-space:pre-wrap; word-break:break-word; }
    #vg-vgl-highlight { position:absolute; top:0; left:0; pointer-events:none; z-index:0;
      color:#1a1a1a; }
    #vg-vgl-input { position:relative; display:block; border:0; outline:none; resize:none;
      overflow:hidden; background:transparent; color:transparent; z-index:1;
      caret-color:#1a1a1a; }
    /* Off-screen rather than display:none, so the textarea keeps a width and
       its autosize still measures a real height. */
    .vg-no-source #vg-editor-controls {
      position:absolute; left:-99999px; visibility:hidden; }
    .vg-no-source .vg-editor-body { padding:0; gap:0; }
    .vg-no-source #vg-editor-preview { border:0; }
    /* The pane shrinks to its head; the list opens over the diagram rather
       than pushing it, so reading an error does not resize the preview. */
    .vg-no-source .vg-diag-pane { position:relative; border-width:1px 0 0; border-radius:0; }
    .vg-no-source .vg-diag-head { cursor:pointer; }
    .vg-no-source #vg-editor-diagnostics { display:none; }
    .vg-no-source.vg-diag-open #vg-editor-diagnostics { display:block; position:absolute;
      left:0; right:0; bottom:100%; z-index:5; background:#fff; border-top:1px solid #ddd;
      box-shadow:0 -4px 12px rgba(0,0,0,0.12); }
    .vg-dark.vg-no-source.vg-diag-open #vg-editor-diagnostics { background:#2a2a2a; color:#e6e6e6; }
    .vg-render-row { margin-top:6px; }
    #vg-editor-status { margin-left:8px; color:#555; }
    .vg-splitter { position:absolute; top:0; bottom:0; right:-8px; width:8px;
      cursor:col-resize; z-index:5; touch-action:none; }
    /* While dragging the splitter: the pointer leaves the thin bar, so this
       catches its moves across the whole viewport. */
    .vg-resize-overlay { position:fixed; inset:0; cursor:col-resize; z-index:9999;
      touch-action:none; }
    .vg-diag-pane { border:1px solid #ddd; border-radius:4px; flex:0 0 auto; }
    .vg-diag-head { background:#f2f2f2; padding:6px 10px; border-bottom:1px solid #ddd;
      font:600 12px system-ui,sans-serif; }
    #vg-editor-diagnostics { padding:8px 10px; max-height:160px; overflow:auto;
      font:12px ui-monospace,SFMono-Regular,Menlo,monospace; }
    #vg-drag-overlay { position:fixed; inset:0; z-index:9996; pointer-events:none; }
    .vg-dismiss { position:fixed; inset:0; z-index:9998; }
    .vg-kw { color:#0b5fff; font-weight:600; }
    .vg-str { color:#0a7d00; }
    .vg-comment { color:#8a8a8a; font-style:italic; }
    .vg-num { color:#a35200; }
    .vg-punct { color:#777; }
    .vg-notation { color:#7a3ce0; font-weight:600; }
    .vg-type { color:#0b7285; }
    .vg-id { color:#1a1a1a; }
    .vg-attr { color:#b5008a; }
    .vg-val { color:#a35200; }
    .vg-error { color:#c62828; text-decoration:underline wavy #c62828; }
    .vg-syntax-error { background:rgba(200,40,40,0.22); border-radius:2px;
      text-decoration:underline wavy #c62828; }
    .vg-diag-error { text-decoration:underline wavy #c62828; text-underline-offset:2px; cursor:help; }
    .vg-diag-warn { text-decoration:underline wavy #b26a00; text-underline-offset:2px; cursor:help; }
    .vg-ctx-menu { position:fixed; z-index:9999; min-width:160px; max-height:calc(100vh - 16px); overflow-y:auto; background:#fff; color:#222;
      border:1px solid #ccc; border-radius:6px; box-shadow:0 4px 16px rgba(0,0,0,0.18);
      padding:4px 0; font:13px system-ui,sans-serif; overflow:hidden; }
    .vg-ctx-head { padding:5px 14px; font:600 11px system-ui,sans-serif; color:#888;
      border-bottom:1px solid #eee; white-space:nowrap; }
    .vg-ctx-item { display:block; width:100%; text-align:left; border:0; background:transparent;
      padding:7px 14px; font:13px system-ui,sans-serif; color:#222; cursor:pointer; }
    .vg-ctx-item:hover { background:#eef3ff; }
    .vg-ctx-input { display:block; width:calc(100% - 20px); margin:6px 10px; padding:5px 7px;
      font:13px system-ui,sans-serif; color:#222; background:#fff;
      border:1px solid #ccc; border-radius:4px; outline:none; box-sizing:border-box; }
    /* Touch. `preventDefault()` on pointerdown does not stop a finger from
       scrolling — only `touch-action` does — so the two gestures are split by
       where the press lands. The preview stays pannable, because it is the
       scroll surface for a diagram bigger than the pane; the draggable
       surfaces opt out, so a press on a node or a group label is a connect or
       a move rather than a scroll.

       The cost falls on the [[Rubber band]], and only on touch: it is armed
       by exactly the blank-canvas drag that now pans, so a finger has no
       gesture left for it. Tap still selects, and the band's ⇧-additive mode
       needed a keyboard regardless. `touch-action` is inert for a mouse, so
       the desktop band is untouched (ADR-0018).

       `-webkit-touch-callout` and `user-select` keep iOS's own press-and-hold
       callout off the SVG, where it would race our long press. */
    #vg-editor-preview { flex:1 1 auto; min-height:0; border:1px solid #ddd; padding:8px;
      overflow:auto; touch-action:pan-x pan-y;
      -webkit-touch-callout:none; -webkit-user-select:none; user-select:none; }
    #vg-editor-preview .vgraph-node,
    #vg-editor-preview .vgraph-group-label { touch-action:none; }
    /* Red because an unknown edge type already renders red, so the ghost line
       and the edge a ⌥ drop makes agree. */
    .vg-drag-line { stroke-width:2.5; stroke-dasharray:6 4; stroke-linecap:round; }
    .vg-drag-legal { stroke:#2e7d32; }
    .vg-drag-illegal { stroke:#c62828; }
    /* Rubber band, and the halo on what it caught. A halo rather than a
       stroke override because strokes carry notation meaning — red is a
       notation break, green a legal drop — and a glow speaks neither
       language while working on an ellipse, a diamond and a boundary rect
       alike (ADR-0018). */
    .vg-band { fill:rgba(11,95,255,0.10); stroke:#0b5fff; stroke-width:1;
      stroke-dasharray:4 3; }
    /* Violet, and !important, because the renderer's hover styles own both
       channels this needs: hovering any node dims every other to
       opacity 0.15 and glows the hovered one in near-identical blue
       (SVGBuilder). Selection is standing state and hover is transient, so
       selection wins — and it says so in a colour hover does not speak. */
    .vg-selected { opacity:1 !important;
      filter:drop-shadow(0 0 2px #a855f7) drop-shadow(0 0 6px #a855f7) !important; }
    /* The group a drop would move into. A wash rather than an outline: move
       is about ending up inside a volume, and the stroke palette is spent
       (ADR-0019). `opacity` beats the renderer's hover dimming. */
    .vg-drop-target { opacity:1 !important; }
    .vg-drop-target > rect, .vg-drop-target > path, .vg-drop-target > polygon {
      fill:rgba(14,159,110,0.16) !important; }
    /* The root group's wash. It draws no element of its own, so the canvas
       carries it — which is what the canvas *is* (ADR-0016). */
    .vg-drop-root { box-shadow:inset 0 0 0 2px rgba(14,159,110,0.45); }
    /* The edge whose end is in the user's hand. Dimmed rather than hidden, so
       the ghost line reads as replacing it and the user keeps the reference
       point for what they are moving away from (ADR-0021). `!important`
       because the renderer's hover styles own opacity on edges too. */
    .vg-reattaching { opacity:0.25 !important; }
    /* Style guide §13: --pill-bg chip, --ink-2 count. */
    .vg-details-marker { pointer-events:none; }
    .vg-details-marker rect { fill:#eeece8; }
    .vg-details-marker text { fill:#5a564e; font:700 10px 'DM Sans',sans-serif; }
    .vg-inline-edit { position:fixed; z-index:9997; padding:3px 6px; box-sizing:border-box;
      font:13px system-ui,sans-serif; color:#1a1a1a; background:#fff;
      border:2px solid #0b5fff; border-radius:4px; outline:none;
      box-shadow:0 2px 10px rgba(0,0,0,0.18); }
    .vg-ctx-input:focus { border-color:#0b5fff; }
    .vg-ctx-item.vg-ctx-disabled { color:#aaa; cursor:default; }
    .vg-ctx-item.vg-ctx-disabled:hover { background:transparent; }
    .vg-dark #vg-vgl-input-wrap { background:#1e1e1e; }
    .vg-dark #vg-vgl-highlight { color:#e6e6e6; }
    .vg-dark #vg-vgl-input { caret-color:#e6e6e6; }
    .vg-dark .vg-kw { color:#6ea8fe; }
    .vg-dark .vg-str { color:#7ec699; }
    .vg-dark .vg-comment { color:#8a8a8a; }
    .vg-dark .vg-num { color:#e6a86b; }
    .vg-dark .vg-punct { color:#999; }
    .vg-dark .vg-notation { color:#c39bff; }
    .vg-dark .vg-type { color:#5bc0de; }
    .vg-dark .vg-id { color:#e6e6e6; }
    .vg-dark .vg-attr { color:#f08fd0; }
    .vg-dark .vg-val { color:#e6a86b; }
    .vg-dark .vg-error { color:#ff6b6b; text-decoration:underline wavy #ff6b6b; }
    .vg-dark .vg-syntax-error { background:rgba(255,90,90,0.28);
      text-decoration:underline wavy #ff6b6b; }
    .vg-dark .vg-diag-error { text-decoration:underline wavy #ff6b6b; }
    .vg-dark .vg-diag-warn { text-decoration:underline wavy #e0a030; }
    .vg-dark .vg-ctx-menu { background:#2a2a2a; color:#e6e6e6; border-color:#444;
      box-shadow:0 4px 16px rgba(0,0,0,0.5); }
    .vg-dark .vg-ctx-sep { background:#3a3a3a; }
    .vg-dark .vg-display-row button { color:#e6e6e6; background:#2a2a2a; border-color:#555; }
    .vg-dark .vg-display-row button:hover { background:#3a3f4b; }
    .vg-dark .vg-ctx-head { color:#999; border-bottom-color:#3a3a3a; }
    .vg-dark .vg-ctx-item { color:#e6e6e6; }
    .vg-dark .vg-ctx-item:hover { background:#3a3f4b; }
    .vg-dark .vg-ctx-item.vg-ctx-disabled { color:#777; }
    .vg-dark .vg-ctx-input { color:#e6e6e6; background:#1f1f1f; border-color:#555; }
    .vg-dark .vg-ctx-input:focus { border-color:#5b8cff; }
    .vg-dark .vg-inline-edit { color:#e6e6e6; background:#2a2a2a; border-color:#5b8cff; }
    .vg-dark .vg-drag-legal { stroke:#7ec699; }
    .vg-dark .vg-drag-illegal { stroke:#ff6b6b; }
    .vg-dark .vg-details-marker rect { fill:#262420; }
    .vg-dark .vg-details-marker text { fill:#a8a49a; }
    .vg-dark .vg-band { fill:rgba(122,167,255,0.14); stroke:#7aa7ff; }
    .vg-dark .vg-selected { opacity:1 !important;
      filter:drop-shadow(0 0 2px #c084fc) drop-shadow(0 0 7px #c084fc) !important; }
    .vg-dark .vg-drop-target > rect, .vg-dark .vg-drop-target > path,
    .vg-dark .vg-drop-target > polygon { fill:rgba(52,211,153,0.20) !important; }
    .vg-dark .vg-ctx-item.vg-ctx-disabled:hover { background:transparent; }
    .vg-dark .vg-toolbar { background:linear-gradient(135deg,#9A3412 0%,#C2410C 100%); }
    .vg-dark .vg-toolbar option { color:#e6e6e6; background:#2a2a2a; }
    """
