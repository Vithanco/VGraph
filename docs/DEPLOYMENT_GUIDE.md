# VGraph — Deployment Guide

Two deliverables go onto the Vithanco website:

1. **The editor** — `website/index.html`, which mounts the ElementaryUI editor
   from `Package/VGraphWasm.wasm` and renders VGL → SVG live. This is what end
   users interact with.
2. **The library** — `website/dist/vgraph-v<version>.js` (+ `.d.ts`), a
   versioned JS wrapper over the same engine, for callers who want to render or
   convert VGL programmatically rather than mount the UI.

## Deploying

```bash
just release        # optimized WASM into website/Package/ (+ full test gate)
just stage-website  # copy editor + Package + library + docs into the website repo
```

`stage-website` runs `deploy.sh`, which populates
`$VITHANCO_WEBSITE_DIR/Resources/vgraph/` with `index.html`, `Package/` (~3 MB
of WASM and JS glue), `v<version>/` (the library and its type definitions), and
the two Markdown docs. Then preview and deploy from the website repo:

```bash
cd "$VITHANCO_WEBSITE_DIR" && swift run
```

To update: change the Swift sources, run `just release`, bump the library
version with `just bump-js <version>` **only if its JS API changed**, then
`just stage-website`.

## Embedding the editor

`index.html` loads `./Package/index.js` relative to itself, so the two just need
to be served together. Embed with an iframe:

```markdown
<iframe src="/vgraph/index.html" width="100%" height="720"
        style="border:1px solid #e0e0e0;border-radius:8px;"
        title="VGraph Editor"></iframe>
```

Seed a specific graph two ways:

- `?vgl=<url-encoded VGL>` — the document itself. Read by the editor, so every
  embedding host inherits it. Note the ceiling: the query travels in the HTTP
  request line, which CDNs cap around 8 KB, so a diagram much over ~5 KB of VGL
  cannot be linked this way.
- `?src=<path or https URL>` — a *reference* to a `.vgl` or `.vithanco.svg`
  file, fetched by the page. No size limit, and the document takes the file's
  name, which is what a later Save writes under.

### Keeping a diagram

Two things stop work disappearing, and both are the host page's to provide or
withhold:

- **`#vgl=<url-encoded VGL>`** — the same document-in-a-URL as `?vgl=`, but in
  the fragment. The browser never sends a fragment to the server, so it escapes
  the request-line cap that makes `?vgl=` unable to carry a larger diagram, and
  the diagram stays out of access logs. This is what the File menu's **Copy
  link** mints. Read by the editor itself, so every host gets it.
- **Autosave** — the editor writes the current VGL after every edit and restores
  it on the next visit, but only through `window.__vgraphDraft` (see
  `index.html`), which owns the `localStorage` calls. That indirection is not
  ceremony: `localStorage` *throws* where site data is switched off rather than
  returning nothing, and the wasm build cannot catch a JS exception. A host that
  omits the object simply has no autosave.

A document named in the URL always wins over a restored draft — including a
`?src=` that has not finished fetching — because a link has to show the same
diagram to everyone who follows it (`EditorCore.documentToOpen`).

**Calling into the editor from a host page:** `mountEditor` returns before the
editor exists. ElementaryUI paints the tree afterwards, and the textarea's
`.onAppear` then renders the document. A call that lands in between — a
`setEditorVGL`, a `setEditorStatus` — either tears the half-built tree down or is
overwritten by that render. Wait for a rendered diagram (`#vg-editor-preview
svg`), which cannot appear until that render has run; `whenEditorReady` in
`index.html` is the reference implementation.

`?src=` lives in `index.html` rather than in the editor, because fetching is
asynchronous and this build cannot invoke a Swift `JSClosure` (see the header of
`VGraphWasm/VGraphEditor/Editor.swift`). A host that replaces `index.html` with
its own boot code therefore inherits `?vgl=` but **not** `?src=` — copy
`loadSource` across if you need it.

What `?src=` will fetch: same-origin on any scheme, another origin only over
`https:`. Requests carry no credentials and no referrer, so a cross-origin
source — `raw.githubusercontent.com`, say, which any public repo can serve —
learns nothing about the visitor. When the document did come from elsewhere, the
status line names that origin, so a stranger's diagram doesn't read as one of
yours.

## Using the library

```javascript
import VGraphLib from '/vgraph/v1.1.0/vgraph-v1.1.0.js';

const vgraph = new VGraphLib();
await vgraph.init({ wasmPath: '/vgraph/Package' });

vgraph.render(vglText)     // VGL → SVG
vgraph.toDot(vglText)      // VGL → DOT
vgraph.exportVGL(vglText)  // VGL → normalized VGL
```

Old versions stay accessible at `/vgraph/v<old>/`, so existing embeds don't
break when a new one ships.

## Serving notes

- `.wasm` must be served as `application/wasm`.
- The WASM and library are large and rarely change:
  `Cache-Control: public, max-age=31536000, immutable` for `Package/` and each
  versioned library directory.
- CORS only matters if the assets are on a different origin than the page.
- Rendering runs entirely in the browser's WASM sandbox — no server-side
  processing, and no data leaves the page.

## Troubleshooting

- **Editor doesn't appear** — check the console, and confirm `Package/index.js`
  and `VGraphWasm.wasm` are served next to `index.html` with the right MIME type.
- **Rendering fails or looks wrong** — the editor's diagnostics box shows parse
  errors and quality warnings, such as an edge type the notation doesn't allow.
- **Import errors** — ES modules only, so `<script type="module">` and correct
  relative paths.
