# @vithanco/vgraph-mcp

The VGraph MCP server, running on your machine.

Same tools and same engine as the hosted server at `mcp.vithanco.com` — the
difference is where the work happens. The engine is compiled to WebAssembly, so
a diagram is laid out and rendered locally, with no round trip and nothing to
pay for.

```bash
npx @vithanco/vgraph-mcp
```

Claude Code, Claude Desktop, Cursor — anywhere an MCP server is configured by
command:

```json
{
  "mcpServers": {
    "vgraph": { "command": "npx", "args": ["-y", "@vithanco/vgraph-mcp"] }
  }
}
```

The hosted server remains the better fit where there is no shell to run a
command in — claude.ai in the browser, ChatGPT connectors — and stays available:

```json
{ "mcpServers": { "vgraph": { "url": "https://mcp.vithanco.com/mcp" } } }
```

## What is in here

No graph logic. This is a host around the engine, the same way the Obsidian and
VS Code plugins are — they put the wasm behind a pane, this one puts it behind
a protocol on stdin.

| file | what it does |
|---|---|
| `src/server.mjs` | MCP plumbing: list tools, dispatch, format the quality report |
| `src/render.mjs` | one render call per view: the report, then a picture per view |
| `src/wasm-host.mjs` | loads the wasm under WASI |
| `src/png.mjs` | rasterises the SVG |
| `tools.json` | tool definitions, generated from the Swift server |
| `vendor/` | the engine, its JS glue, and the fonts |

`tools.json` is not written by hand. `scripts/dump-mcp-tools.sh` starts the
native `vgraph-mcp` binary and asks it, over MCP, what tools it offers — so the
VGL documentation the model reads has one source, in Swift, and a tool added
there appears here without anyone editing JavaScript.

## Building it

From the repository root:

```bash
just mcp-node       # build the wasm, vendor it with the fonts, refresh tools.json
just mcp-node-run   # run it on stdio against the current build
```

`vendor/` is not committed. The wasm is 4.1MB, and a copy in git is a copy that
can disagree with the engine it was built from.

## Two things that look like bugs and are not

**The wasm writes to stderr.** It logs layout DEBUG lines to WASI stdout, and
under a stdio MCP server stdout carries JSON-RPC. `wasm-host.mjs` routes both
wasm fds to stderr; the noise is expected. What the hosted server logs is in
[`SECURITY.md`](../SECURITY.md); this local host is a separate implementation.

**Fonts are bundled rather than read from the SVG.** The SVG carries an
`@import` for DM Sans, which browsers honour and rasterisers ignore — and resvg
ignores an embedded `@font-face` too. See `fonts/README.md` at the repository
root for why the faces are TTF and why there is one file per weight.

## Licence and source

Apache-2.0; see `LICENSE` and `NOTICE` (third-party components, including
Graphviz under EPL-2.0). The engine source is at
https://github.com/Vithanco/VGraph.
