# 15. SVG rendering via a typed IR; Elementary SVG adoption via upstream fixes

Date: 2026-07-29

## Status

Accepted. The IR is the only rendering backend as of 2026-08-12; the string
`SVGRenderer` is deleted and the `.raw` islands are retired (2026-08-15). The
editor preview is mounted through ElementaryUI as of 2026-11-15 (F1); what F1
still owes — transitions among it — is listed there.

## Context

Elementary 0.8.0 introduced first-class SVG types, and ElementaryUI mounts them
namespaced with keyed reconciliation. The editor is heading toward a full
graph-editor interface with animated transitions, so `SVGRenderer` returning
`String` is not a contract worth preserving — but the wasm plugin API
(`renderGraph`), Save SVG and document export still need a string produced
*inside* the Embedded build.

Building the renderer's output directly from Elementary's SVG types was spiked
and hit four blockers:

1. **No string rendering under Embedded Swift.** `_Renderable` requires a
   generic protocol requirement, the one protocol feature Embedded cannot
   witness; under Embedded the protocol degrades to `Any` and rendering is
   compiled out. The token pipeline below it is already Embedded-clean.
2. **No way to unify a switch over element kinds.** Elementary carries the tag
   *in the type*. A graph is a tree of unknown shape, so rendering switches over
   kinds with differently-typed branches. There is no `AnyView`, the Embedded
   SDK of the time forbade `any`, and the runtime-tag initialiser is internal.
3. **No per-element SVG events or animation modifiers.** The whole modifier
   surface is `extension View`, and only `SVGTag.svg` conforms to `View`. The
   machinery underneath is namespace-agnostic — the constraint is type-level.
4. **Minor gaps.** No typed `dx`/`dy` factories; `SVGRaw` is deliberately not
   mountable, so there is no raw-string escape hatch on the mounted path.

The spike also established that Elementary SVG types mount fine under Embedded
(+73.6 KB, so size is not what defers this), that `ForEach(_, key:)` patches in
place, and that a **nominal recursive view** over a concrete tree compiles —
which is what makes a dynamic graph mountable at all.

## Decision

**One concrete IR, two backends.** `VSVGNode`
(`Sources/VGraphSVG/Domain/VSVGNode.swift`) is an indirect enum
(`element`/`text`/`raw`/`fragment`/`empty`) over a closed `VSVGTag` set, with
its own Embedded-clean emitter. The editor will mount the same tree through a
recursive ElementaryUI view; string consumers render through the emitter.

The IR is the hexagon seam and stays even after upstream fixes land: it gives
overlay providers a uniform existential-free return type, owns the export path
(CDATA-embedded VGL stays string-land), and keeps `VGraphSVG` describing *what*
to draw while adapters decide *how*.

What it fixes over the string builder, independently of Elementary: attribute
values are escaped (`SVGBuilder` never escaped them, so a label with a quote
could inject markup — apostrophes deliberately are *not* escaped, which would
mangle every `font-family` for no safety gain); nesting is structural, so a `<g>`
cannot be left unclosed; the fill/stroke block duplicated five times is one
function.

Two *rendering* backends were the accepted cost of the migration while it
lasted; the string renderer is gone. Two answers to the same question about the
graph were never acceptable: theme-token resolution, reads behind bounds,
watermark avoidance and neighbour-hover CSS live once (`SVGThemeColor`,
`SVGRenderQueries`, `SVGHoverStyles`). Anything that is not markup construction
belongs there.

**The tree stays in `VGraphSVG`, and the ports say only that a renderer draws
*something*.** `VForRenderAGraph` has an associated `Drawing`, which
`VSVGRenderer` makes `VSVGNode`; `RenderResult` is generic over it, and
`VForEditAGraphVisually` carries it to the pane, which constrains it to the
kind it can mount. Moving the tree into the core instead was tried first
(2026-11-15) and reversed the same day: it kept every port concrete, but put a
list of SVG tags in the domain every notation is written against.
`ArchitectureTest.theCoreNamesNoSVGTreeType` holds the line. The associated
type is [0013](./0013-driving-ports-and-named-commands.md)'s one amendment.

The renderer port speaks in two steps so that a drawing which is both mounted
and saved is drawn once: `draw` returns the drawing and `serialize` turns one
into the artefact. `render` is their composition.

**`VGraphSVG` must not gain an Elementary dependency.** `VSVGNode`, `VSVGTag`
and `VShapeStyle` are ours, so nothing in the module needs Elementary's types.
Elementary stays declared only by the wasm editor target. Wanting it inside
`VGraphSVG` means revisiting this ADR — it would put an adapter dependency
inside a domain hexagon.

Output is guarded by the snapshots under `Tests/VGraphSVGTests/__Snapshots__`,
recorded from the bytes the old equality tests passed on. Equality against the
string renderer stopped being the right guard the moment the IR became the live
path: it pinned what ships against a reference nobody ran, and made every
deliberate rendering change a change that had to be made twice.

## Upstream contributions (we provide PRs)

Suggested sequence **4 → 1 → 3 → 2**: trivial goodwill first, the long-pole
design discussion started early but landed last.

1. **elementary-ui: generalise the modifier system beyond `View`.** *Landed as
   elementary-ui#119, released in 0.8.0 — events and the style modifiers
   (`opacity`, `offset`, `blur`, …). `.transition`, `.animation(value:)` and the
   lifecycle modifiers are still `View`-only.* Spiked
   2026-08-12 and it works: relax `DOMEffectView` to
   `Wrapped: MarkupContent & _Mountable`, conform `MarkupContent`
   unconditionally, then conditionally conform `HTML, View where Wrapped: View`
   and `SVGContent, SVGView where Wrapped: SVGView`. Eleven lines. The
   unconditional `MarkupContent` is forced — a type may conform once, and both
   `HTML` and `SVGContent` inherit it. Branch `svgview-modifiers` in the local
   clone; ~15 modifiers remain. No open issue covers this (elementary-ui#52 is
   about the `.attributes(…)` wrapper, not `SVGView`), so it goes as its own PR.
   *Unlocks:* per-node event handlers (pointer-capture drag) and FLIP
   enter/exit/reorder animations.
2. **elementary: Embedded string rendering.** An `#if hasFeature(Embedded)`
   variant of `_render` taking a *concrete* token-sink type; async stays
   non-Embedded. Open an issue first — this touches the protocol every content
   type witnesses, and the open question is how to avoid writing every `_render`
   twice. *Unlocks:* `render()` in wasm; our emitter becomes optional.
3. **elementary + elementary-ui: dynamic-tag element.** A public
   `DynamicElement` (tag as value) rendering through the existing token path and
   mounting through the internal `_ElementNode(tag:namespaceURI:)`. *Unlocks:*
   the IR→view adapter collapses from a ~24-case switch to one node type. Do not
   assume this is the shared primitive for elementary-ui#85 — that is about Web
   Components, not runtime-known tags.
4. **elementary: attribute factories.** Typed `dx`/`dy` and any other gaps.
   Trivial; good first contribution.
5. **elementary-ui: a bezier timing curve that honours x1 and x2.** *Landed
   as elementary-ui#164, released in 0.9.2.* `UnitCurve.bezier` evaluates y at the parameter instead of solving for the
   parameter at which x is the elapsed time, so `.easeInOut` and every custom
   curve differ from their CSS namesakes. Found 2026-11-15; small and
   self-contained. *Unlocks:* any curve for the frame, not only the one both
   sides happen to agree on.

Build against `main` and expect churn: the pull request elementary-ui#115 is an
active draft touching the same internals.

### Revisit triggers

| When this lands upstream | Do this here |
| --- | --- |
| Modifier generalisation (PR 1) | Execute F1 — *landed; F1 begun 2026-11-15* |
| Embedded string rendering (PR 2) | Consider retiring the IR emitter (part of F2) |
| Dynamic-tag element (PR 3) | Replace F1's bounded-switch adapter with one `DynamicElement` mapping |
| Attribute factories (PR 4) | Drop the `.custom(name: "dy", …)` fallbacks |

## Interim strategy

*Not carried out, and overtaken.* The planned stopgap — transitions by patching
each group's `transform` after a re-layout — was never built; PR 1 landed first
and the preview is mounted instead (F1).

## Follow-ups (deferred, not currently planned)

### F1 — Mount the editor preview

**Done (2026-11-15).** `Drawing+Editor.swift` mounts the session's `VSVGNode`:
a dynamic tree cannot be type-erased, so a *nominal view recursing into itself*
is the only option, and it compiles because every child is the same type. It
switches over `VSVGTag` — a closed set for exactly this reason. Siblings are
keyed by `mountedChildren` (`VSVGMounting.swift`): by `id` where there is one, otherwise by
place among siblings of the same tag, so an insertion does not re-key what
follows it. The tree is `Equatable`, which lets the reconciler skip a subtree a
redraw left alone. `renderGraph`, Save SVG and the plugins stay on the string.

What mounting changed for the rest of the editor:

- **The DOM follows a render by a microtask.** `performRender` only hands over
  the drawing; ElementaryUI patches afterwards. Everything that measures or
  stamps what is drawn — the details markers, the selection halo, opening
  an inline editor on a new element — runs from `previewPatched`, and
  `whenPreviewPatched` is how a command queues work behind the patch.
- **What the editor paints into the SVG now outlives a render**, because the
  element it was painted into does. Painting has to be idempotent: the details
  markers remove last render's before adding this one's.
- The delegation handlers and `getScreenCTM` anchoring are unchanged.

Measured on a 200-node concept map (2,800 elements, optimized build, Chromium):
a first mount takes 17–19 ms where `innerHTML` took 3 ms; a redraw after adding
one node, which moves most of the layout, 9 ms; a redraw that changes nothing,
0.5 ms. Parsing, layout and drawing are 135–155 ms either way, so the mount is
not what a large diagram waits for.

**Still owed:**

- **Transitions, beyond the first step.** What moves now (2026-11-15): a node
  glides, and so do arrowheads and edge, edge-end and group labels; a line
  bends into its new shape and a group box resizes in engines that treat `d`
  and a rect's geometry as CSS properties. Each is a rule in the editor
  stylesheet — a transition on `transform`, `d`, or the rect's `x`, `y`,
  `width` and `height` — which is all it takes once the elements persist; all
  are off under `prefers-reduced-motion`. `x`/`y` on text and `points` are not
  CSS properties, so labels and arrowheads are placed by `transform` instead.
  An arrowhead is drawn around the end of its line, so the two meet throughout
  the glide; a label at a box's corner keeps to it the same way, the two
  being one interpolation of the same numbers. An edge persists because the renderer keys it by
  its ends (`SVGElementId.keyAttribute`, interactive drawings only): the parser
  mints every edge id afresh, so an id cannot say that an edge is the one
  already drawn. The style guide has no motion section; 0.25 s and the curve
  (`glideSeconds`, `glideCurve`) are placeholders until it does.

  **The frame eases too.** A redraw that changes the diagram's bounds changes
  the `viewBox`; left to jump, that rescales and shifts the whole picture at
  once and the nodes then glide from the wrong place. The root view
  (`Drawing`) is `Animatable` over the frame, so ElementaryUI interpolates the
  `viewBox` — and the width, height and zoom style that follow from it — per
  frame. That made the zoom view state: the `<svg>`'s size is part of the mount,
  so a first mount is fitted in the frame it appears in.

  Two things follow from two clocks moving one picture. The curve has to be
  one both evaluate alike, which since ElementaryUI 0.9.2 (upstream PR 5) is
  any `cubic-bezier`; before it, only one with x control points at 1/3 and
  2/3 was. And nothing synchronises the two clocks: measured on the optimized build, frame
  and nodes stay within 2 % of each other's progress on diagrams of 8 and 40
  nodes, and drift up to 9 % apart on one of 120, whose render takes 46 ms.

  What is measured during the easing is on its way somewhere else. The inline
  editor is placed through `measuringAtRest`, which puts the drawing in the
  frame it is easing to for the length of the measurement.

  What still jumps: an arrowhead's direction — only its place glides, so a
  head that turns takes its new angle at once; a line whose new path has a
  different number of segments (its head still glides, off a line already
  redrawn); the diagram title, the watermark, the link badges on edges and
  groups, and the edge-end handles, all still placed by absolute coordinates.
  WebKit animates none of it but a group box: it does not transition `d`, nor
  `transform` written as an attribute, which is how nodes, labels and heads
  are placed. Entering and leaving elements appear and vanish: that needs
  `.transition` on `SVGView`, and animating a path in every engine needs an
  animatable vector longer than eight floats — both upstream.
- **Anything painted beside a node is left behind when it glides.** The details
  marker goes inside the group that carries the box's transform for that
  reason; the next thing painted into the drawing has to do the same.
- Re-examine ADR-0009's "a render closes the inline editor" rule now that
  elements persist; then selection as reactive state.

### F2 — String-path convergence (separate decision, after F1)

Retire legacy string paths consumer-by-consumer: native export via the emitter
(or Elementary `.render()` if PR 2 lands), Save SVG via DOM serialisation,
plugins possibly via a `mountGraph(elementId)` export. Document-export CDATA/VGL
embedding stays string-based regardless. Retire `SVGBuilder` once nothing
consumes it.

## Consequences

- **One rendering backend.** Snapshots are the drift guard: they cost 84 files
  and one recorded diff per intended change, and buy back the
  duplicate-maintenance tax. A snapshot asserts only "these bytes did not move";
  the assertions beside it say the bytes are *right*, which is why the behaviour
  suites moved to the IR rather than being subsumed. `SnapshotHygieneTests`
  fails the build on an orphaned expectation.
- **The drift guard only covers what a fixture exercises.** The URL badge — a
  real `<a>`, the one element the closed tag set had no case for — shipped on
  `main` while every equality test stayed green, because no fixture carried a
  link. Now closed, and `URLBadgeRenderer` emits *through* the IR so one
  implementation cannot drift from itself. The lesson stands: new render
  features need a fixture from the start.
- **`<style>` needs its own escaping rule.** A CSS body only survived
  `VSVGNode.escape` by accident — it would turn `>` into `&gt;` and `'` into
  `&apos;`. Only `&` and `<` need escaping in XML text, so `VSVGTag.holdsCSS`
  selects a minimal escape and the CSS sources hold the true characters. This is
  not cosmetic: a mounted `<style>` receives the text via `textContent`, which
  performs no unescaping, so over-escaping reaches the CSS parser literally.
- **The `.raw` case survives as the emitter's escape hatch**, documented as
  unmountable at its declaration. Nothing in `VGraphSVG` constructs one.
- **`SVGBuilder` stays as a primitive layer**, not a second backend: the IR
  builds on its `format`, `cssEscapeIdent`, `hoverStyles`, `dmSansFontImport` and
  `embedVGL`/`extractVGL`. Changes are allowed where output-preserving — the
  tests, not the file boundary, are the contract.
- **The `ForRenderAGraph` adapter is a `Sendable` struct**, where the legacy
  renderer was a class writing theme, icon set and bounds onto itself per
  render. The port is now re-entrant.
- Moving the overlay-slot return type from `String` to `VSVGNode` is
  source-breaking for out-of-tree notation providers. Accepted while the
  notation authoring API has no external users — and a reason to settle that API
  before it does.
- We take on upstream engagement (four PRs, two design discussions) with the
  usual risk that maintainer direction differs. The interim architecture is
  complete without them, so no PR is on the critical path.
