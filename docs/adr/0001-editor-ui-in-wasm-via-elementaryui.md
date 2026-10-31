# 1. Editor UI in WASM via ElementaryUI

Date: 2026-07-13

## Status

Accepted; all gates passed in the 2026-07-13 spike. ElementaryUI builds Embedded
through `build-wasm.sh` with no Vite requirement, `mountEditor` mounts and
renders live in the browser, and both plugins rebuild clean against the
JavaScriptKit 0.56.1 glue. Release size settled around +0.23 MB, so the one-wasm
approach holds.

The embedding contract has moved since: the editor reads `?vgl=` and `#vgl=`
itself, so every host honours them; the host keeps only `?src=`. The
`postMessage({type:'setVGL'})` route went with the iframe widget (a24aece) and
is no longer offered.

## Context

The interactive widget was assembled in **JavaScript**: an HTML template owned
the text area, buttons and save controls, calling the WASM engine only for string
transforms. The engine was a pure functional core — VGL string in, SVG string out
— shared by the website, the Obsidian plugin and the VSCode plugin.

Two engine changes removed the historical blockers to a WASM-owned interactive
surface: **in-process Graphviz** (swiftGraphviz compiled into the Embedded-WASM
module, so `renderGraph(vgl)` is a single synchronous in-process call, with no
JS-orchestrated layout round-trip and therefore no re-entrancy hazard), and
**leak-free teardown** (swiftGraphviz 0.8.0), which made live preview tenable.

The near-term target is a text-centric editor with live preview, VGL remaining
the single source of truth. Direct-manipulation editing is explicitly out of
scope here.

## Decision

Build the editor as an **additive driving adapter inside `VGraphWasm`, using
ElementaryUI** — a SwiftUI-like reactive framework compiling to WASM via
JavaScriptKit, with explicit Embedded Swift support.

- **Additive, never replacing.** The pure engine functions (`renderGraph`,
  `renderGraphDark`, …) are untouched. `mountEditor` boots the ElementaryUI app
  into a host-supplied DOM node; `setEditorVGL` feeds it VGL from the host.
- **The editor owns UI, state and rendering.** Live preview is debounced-auto
  plus explicit render; parse failures are non-destructive (last-good SVG stays,
  error to the status line).
- **Saving lives inside**, driven from Swift. SVG save reuses the string the
  editor holds; PNG save drives the browser canvas and is therefore async.
- **The embedding contract stays outside.** A thin JS bootstrap instantiates the
  module, calls `mountEditor`, and serves the published `?vgl=` /
  `postMessage({type:'setVGL'})` contract through `setEditorVGL`.
- **One wasm, with a clean source split.** The editor is its own SwiftPM target
  depending on the engine, so it never contaminates the engine's sources.
  Splitting into lean engine-only and engine+editor products is deferred until
  the size delta justifies it.
- **Vite is dev-only.** `build-wasm.sh` remains the canonical builder of the one
  wasm all three consumers use.

## Constraints discovered during implementation

**JavaScriptKit `JSClosure` cannot be *invoked* in this Embedded build.**
`swjs_call_host_function` and `swjs_free_host_function` are `@_expose(wasm)`
inside the JavaScriptKit *dependency* target, and dependency-target `@_expose`
exports get dead-stripped — only the root executable target's survive. Creating a
`JSClosure` succeeds but JS calling it is a no-op.

The key realisation: **only the JS→Swift *closure* path is broken; JS→Swift
named exports and Swift→JS named calls both work.** So the editor is written
JSClosure-free, using ElementaryUI's own event system, and anything needing a
JS-side callback belongs in the host bootstrap wired to Swift via named exports.
Debounce works this way — `.onInput` calls a named global hook
`vgraphScheduleRender`, the host runs the `setTimeout`, and calls back the
`editorRenderNow` export. PNG rasterisation takes the same route, which revises
the "PNG inside" decision back toward thin JS glue. Only *general* Swift-side
closures (`JSPromise`/`await`, arbitrary `addEventListener` from Swift) would
require fixing the export stripping itself.

**A `bridge-js.js` merge step is needed.** PackageToJS's `SkeletonCollector`
only links the root bridged target's BridgeJS skeleton, not the transitively
imported `BrowserInterop`, so the generated instantiator lacked ElementaryUI's 47
DOM imports. `VGraphWasm/scripts/merge-bridge-js.py` splices our `@JS` export
wrappers into elementary-ui's fully-generated instantiator. It is pinned to the
elementary-ui `main` generator output and hard-fails if that shape changes — a
maintenance liability to watch.

## Alternatives considered

- **Keep the UI in JavaScript.** Perpetuates a second implementation of
  domain-adjacent logic in JS, and forecloses the natural path to
  direct-manipulation editing reusing the Swift domain model. The whole point is
  to move the editor next to the model.
- **Plain Elementary (HTML string generation).** Only relocates the HTML
  template; it produces strings, not an interactive stateful editor.
- **elementary-dom (lower-level reactive DOM).** ElementaryUI sits on top of it
  with a SwiftUI-like state model and explicit Embedded support.
- **Replace Graphviz with a pure-Swift in-module layout engine.** Parked as a
  separate decision. Its payoff is real but independent of and far larger than
  the editor migration — Sugiyama layout with spline routing and cluster
  containment is weeks-to-months of work that would likely still look worse than
  `dot`. It must not gate the editor.

## Consequences

- **Dependency on an early-stage framework**, which self-describes as expecting
  sharp edges and changing APIs. Churn risk accepted, which is why the decision
  was gated on a throwaway spike.
- **Plugins ship editor code they never call** (the one-wasm choice). Bounded:
  the wasm is bundled locally and instantiated once per session, so the extra
  size is a one-time parse cost. The source split keeps a lean engine-only
  product available as a `Package.swift` change, not a refactor.
- **First async path in the editor** (PNG save).
- **Direct manipulation is deferred**, but the WASM-owned-DOM choice is its
  enabler — event-driven interaction on rendered nodes rather than geometric hit
  testing.
- **Engine, website and both plugins are untouched**; existing engine tests
  remain the parity safety net. The editor gets thin JS smoke tests plus
  browser-preview verification. The plugins were build- and lint-validated but
  not launched in-host — a runtime smoke inside Obsidian and VSCode is still owed
  before a plugin release.
