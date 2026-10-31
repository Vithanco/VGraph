# 2. OriginGraph as source of truth, GraphSession, and VCommands

Date: 2026-07-17

## Status

Accepted. The `VCommand` registry it introduced is gone — see
[0013](./0013-driving-ports-and-named-commands.md) — but the OriginGraph and
GraphSession decisions stand.

"Source of truth" below means among graphs: every derived graph (folded, laid
out, a view's) comes from the OriginGraph and never folds back. Across
interactions the document is the VGL the OriginGraph exports — history is built
on it ([0006](./0006-undo-redo-history.md)) and it wins if graph and text ever
disagree.

## Context

The editor gained a right-click "Fold / Unfold group" action, first implemented
as a one-off: re-parse the VGL, flip `isFolded`, re-export. Every future graph
operation would otherwise need its own ad-hoc method and bespoke menu wiring.

Two things needed a home: a **reusable operation abstraction**, so an operation
is declared once and the menu and execution machinery stay generic; and a **place
for mutable graph state**, since the editor was stateless and re-parsed the VGL
on every render. A command that mutates the graph should not have to round-trip
through text on every step.

Per ADR-0001 the engine is a pure, stateless VGL→SVG core that the website and
both plugins depend on, and direct-manipulation editing was explicitly out of
scope. This is the first deliberate step into that stage while keeping the pure
engine contract intact.

## Decision

- **OriginGraph** — the rawest `VGraph`, parsed from VGL and held in memory as
  the single source of truth. Pre-transform: folding, layout and rendering are
  all *derived* from it and never fold back in. Round-trip invariant:
  export→reparse is semantically identical.
- **GraphSession** — a stateful App-layer coordinator owning one OriginGraph and
  *composing* the pure engine functions. It applies a command's graph change in
  place, re-runs the display pipeline to SVG, and exports back to VGL. The engine
  functions stay pure; GraphSession holds the state they deliberately don't.
- **VCommand** — a value-type struct catalogued in a static registry, mirroring
  the `Notations.entries` idiom that exists to avoid metatypes under Embedded
  Swift. A command's effect is called a **graph change**, never a "transform" —
  that word is reserved for the display pipeline's visual-only stage.

Supporting choices:

- **Execution flow.** Command → mutate OriginGraph → export VGL into the text
  editor and render from the OriginGraph. No reparse. Editing the VGL text is the
  *only* path that reparses.
- **Target resolution by id.** Element ids are globally unique within a valid
  graph (shared attribute keyspace; a duplicate fails the parse), and the display
  pipeline stamps each rendered element with the OriginGraph id it represents — a
  folded group renders as a node reusing the group id. So a right-click resolves
  by a single id lookup, with no provenance map.
- **Render-from-graph entry point.** `renderGraph(graph:sourceVGL:darkMode:)`
  renders an already-parsed graph; the string overload parses then delegates, so
  the pure functions are unchanged for the plugins.

## Alternatives considered

- **Stateless re-parse per command.** Every command would re-parse and re-export,
  making text — reformatted by the exporter — the round-trip medium between every
  step.
- **Commands emit VGL text patches.** Each command would have to reason about
  whitespace, ordering and id inference; operating on the typed graph is safer.
- **Make `VGraphApplication` itself stateful.** Would break the pure stateless
  engine contract the plugins depend on. GraphSession keeps the state on the
  composition side.
- **Bake command affordances into the render** (clickable controls drawn on the
  SVG, like the CLD loop indicator). Deferred: only needed for on-canvas
  controls.

## Consequences

- **First in-memory source of truth.** Text is now a projection regenerated on
  each command and re-ingested on manual edit, which inverts ADR-0001's
  text-centric framing — recorded here so it is not surprising later.
- **Fold reformats the VGL** as the exporter normalises it (tabs, no trailing
  `;`, inferred edge types) — inherent to round-tripping through the graph.
- **Plugins untouched.** The pure `@JS` render functions and the display pipeline
  are unchanged; the plugins inherit the framework on their next WASM rebuild,
  with no host JS. GraphSession is additive.
