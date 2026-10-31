Write tests before fixing problems or implementing features.

Work on the current checked-out branch, not on worktrees.

Keep documentation minimal and focused on *why*. Don't repeat what the code
already says. Anything worth keeping goes in `/docs` and stays updated.

## Where to look

- `CONTEXT.md` — the domain vocabulary. `grep -n "^### " CONTEXT.md` lists the
  terms; read the section before naming or placing a new concept.
- `docs/adr/` — why things are the way they are. Read the ADR before reversing
  a design.
- `docs/where-things-live.md` — the layer chain a feature crosses (domain, port,
  app, editor, MCP, wasm, node) and which test target and entry point a test
  uses. Read it before tracing by hand.
- `docs/design/` — the normative visual reference for the default theme (light
  and dark). Read its `README.md` before adding or changing a notation, colour,
  token or dark-mode behaviour; renderer output that disagrees with the guide
  is a bug.

## What VGraph is

A Swift package that parses the Vithanco Graph Language (VGL) and renders it to
SVG via Graphviz. Targets iOS 18+, macOS 15+ and WebAssembly (WASI), so the same
graph logic runs in browsers.

Targets:

- **VGraph** — the core. Domain types and every port protocol. Depends only on
  MathUtils.
- **VGLanguage** (parser, highlighter, VGL exporter) and **VGraphSVG** —
  platform-agnostic hexagons.
- **VGraphvizLib** — Graphviz layout adapter, in-process via the C library.
- **App** — orchestrates the hexagons and wires them by dependency injection.
- **EditorCore** — the editor's decisions, minus the DOM: what a right-click is
  about, what a command asks next, what an opened file is called. Compiled into
  the wasm module, so the Embedded rules below apply.
- **VGraphWasm** — depends on App for composition.

## Hexagonal architecture

Each target is a hexagon: `Domain` (pure logic), `Ports/Inbound` (how it is
called), `Ports/Outbound` (how it calls out), `Adapters` (glue between
hexagons), `Application` (wiring).

Ports are named `For[Verb][Noun]` and declared **twice**: as `VFor[Verb][Noun]`
in the core (`Sources/VGraph/VStdPorts/`), then re-exported by each hexagon that
speaks it under the plain name via a typealias in its own ports folder. The
typealias is that hexagon's own port declaration, not redundancy. The `V` prefix
is forced; `ArchitectureTest` fails if a core port lacks its re-export.

A port is one **actor's** conversation, not one use case. A port with a dozen
methods is not thereby too big; splitting per operation is not an improvement.

A port is always a generic parameter, never `any ForSomething`. This is a
choice, not a compiler limit: generics keep every port call statically
dispatched and specialised, and an `any` port could not be handed on to generic
code, which Embedded Swift still rejects. The ports the application layer
drives are bundled into `AppPorts` as associated types rather than listed
one-by-one.

All wiring lives in `Sources/App/Composition/` — `NativePorts` (everything) and
`ParseOnlyPorts` (no rendering or layout). These are the only types that may
name a concrete adapter. Nothing under `Sources/App/Domain/` may import one.

Reasoning for all of the above: `docs/hexagonal-architecture.md`.

Code is written as functionally as possible, favouring immutability and pure
functions.

## Embedded Swift

The WASM build compiles under Embedded Swift
(`-enable-experimental-feature Embedded`, SDK
`swift-6.4.0-RELEASE_wasm-embedded`). The build fails loudly if incompatible
code enters the WASM dependency graph (VGraph, VGLanguage, VGraphSVG,
VGraphvizLib, App, EditorCore, MathUtils, VGraphWasm). In those targets:

- **Key paths** fail to compile — write `map { $0.id }`, not `map(\.id)`.
  `ArchitectureTest` flags them (and `"\(type(of:))"`) under `swift test`, so a
  native run catches them before the wasm build does.
- **A generic function called on an `any` value** fails to compile — pass a
  concrete or generic value, or call a protocol requirement on the existential.
- **Reflection** compiles but prints `(cannot print value in embedded Swift)`
  for `"\(self)"` on enums and `"\(type(of: x))"`. Declare explicit
  `var value: String { switch self { ... } }` and `static let typeName: String`.

Everything else — `any` types including `Any`, existentials in storage,
metatypes, untyped `throws` and `catch { }` — compiles and runs under the 6.4
SDK. The value-type entry structs (`NotationEntry`, `ExtensionEntry`) predate
that; they are not a pattern to copy for new code.

Unicode normalization tables are linked from
`<xctoolchain>/usr/lib/swift/embedded/wasm32-unknown-none-wasm/libswiftUnicodeDataTables.a`
(see `VGraphWasm/Package.swift`). Without it, every `String == String`,
`hasPrefix` and `contains` leaves an undefined symbol.

`vgraph-cli`, `vgraph-mcp`, `vgraph-mcp-http` and `VGraphMCPTools` sit outside
that graph and may use Foundation and key paths freely.
`VGraphvizLib` is *not* one of them — Graphviz compiles into the wasm module.

Graphviz layout runs in-process on every platform, so `#if WASM` appears only in
platform-specific hexagons and at composition boundaries.

## Common patterns

- **Errors** — typed throws with `VError`: `func f() throws(VError) -> R`.
- **Identifiers** — `Identifier<T>` wrapper: `let id: Node.Id = .init(rawValue: "node1")`;
  read the string back with `id.id` (so a node's is `node.id.id`), not `rawValue`.
- **`VProtocol`** — base protocol for domain types (Codable, Hashable, Sendable).
- **`UseIdentifier`** — types with an `id`.
- **`HasReadableNames`** — enums with display names. Every conformer must supply
  `value`, `readableName` and `typeName` explicitly; the reflection-based
  defaults were removed and there is no fallback.
- **`NotationDeclaration` / `NotationExtension`** — authoring contracts for
  compiled notations. Runtime dispatch goes through the value-type
  `NotationEntry` / `ExtensionEntry` snapshots in `NotationRegistry`.

## Building

`just build` (compile only), `just test` (build + full suite), `just release`
(optimized artifacts). `just` with no args lists everything. Plain swift
commands are fine during development.

## Agent skills

The skills themselves are not part of this repo; these are the pointers they read.

### Issue tracker

Issues and specs live in GitHub Issues on `Vithanco/VGraph`, worked with `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage roles, each label named after its role. See `docs/agents/triage-labels.md`.

### Domain docs

Single context: `CONTEXT.md` is the glossary, ADRs are in `docs/adr/`. See `docs/agents/domain.md`.
