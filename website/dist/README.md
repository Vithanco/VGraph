# VGraph JavaScript Library

**Version:** 1.1.0

A small JavaScript library for rendering and converting Vithanco Graph Language
(VGL) in the browser. It wraps the VGraph WebAssembly engine and exposes a simple
programmatic API. Graphviz layout is compiled **into** the WASM module (in-process),
so there is no separate Graphviz/CDN dependency to load.

> Looking for an interactive editor UI (text area + live preview + examples)?
> Use the editor page (`index.html`) instead — it mounts the whole editor from
> WASM. This library is for programmatic use: calling `render`/`toDot`/`exportVGL`
> from your own code.

## Quick start

```html
<script type="module">
  import VGraphLib from '/vgraph/v1.1.0/vgraph-v1.1.0.js';

  const vgraph = new VGraphLib();
  await vgraph.init({ wasmPath: '/vgraph/Package' });

  const svg = vgraph.render(`vgraph demo: IBIS "My Graph" {
    node q1: Question "What should we do?";
    node a1: Answer "Option A";
    edge q1 -> a1;
  }`);
  document.getElementById('output').innerHTML = svg;
</script>
```

The page needs an import map for the WASI shim the WASM glue depends on:

```html
<script type="importmap">
{ "imports": { "@bjorn3/browser_wasi_shim": "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.3.0/dist/index.js" } }
</script>
```

## API

### `new VGraphLib()`
Create an instance.

### `async init({ wasmPath }): Promise<VGraphLib>`
Initialize the engine. `wasmPath` (default `'./Package'`) points at the deployed
`Package/` directory. Must be called before any other method.

### `render(vglText): string`
VGL → styled SVG. Throws on parse/render failure.

### `toDot(vglText): string`
VGL → Graphviz DOT.

### `exportVGL(vglText): string`
Parse and re-export VGL (normalized round-trip).

### `debug(vglText): string`
Human-readable graph stats for debugging.

### `static getVersion(): object`
`{ version, wasm, features }`.

## Deployment

Files are staged into a website by `just stage-website` (see
`docs/DEPLOYMENT_GUIDE.md`): the versioned library (`v<version>/vgraph-v<version>.js`
+ `.d.ts`), the `Package/` WASM directory, this README, and `VGL_GUIDE.md`. Old
library versions stay accessible at `/vgraph/v<old>/` so existing embeds don't break.

## Serving notes

- `.wasm` must be served as `application/wasm`; `.js` as ES modules.
- Cache `Package/` and the versioned library dir aggressively (`immutable`).
- CORS headers are only needed if the assets are on a different origin than the page.
- All rendering happens in the WASM sandbox in the browser; nothing is sent to a server.

## Compatibility

Modern browsers with ES-module + WebAssembly support (Chrome/Edge 90+, Firefox 89+,
Safari 15+).

## Versioning

Semantic versioning. Within a major version, the WASM exports, the JS API
(`init`/`render`/`toDot`/`exportVGL`), and existing VGL syntax remain stable.

## Reference & support

- **VGL language guide:** `VGL_GUIDE.md`
- **Issues:** https://github.com/Vithanco/VGraph/issues
- **Source:** https://github.com/Vithanco/VGraph
- **License:** Apache-2.0 (`LICENSE`); third-party components, including
  Graphviz under EPL-2.0, are listed in `NOTICE`
