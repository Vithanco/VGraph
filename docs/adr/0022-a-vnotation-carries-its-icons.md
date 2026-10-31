# 22. A `vnotation` carries its icons

Date: 2026-08-28

## Status

Accepted and implemented, less the editor path it never claimed. The syntax is
documented in the [VGL Guide](../VGL_GUIDE.md#icon--artwork-of-your-own). Takes
the registry shape of [0020](./0020-a-graph-carries-its-group-type-registry.md)
and the visible-mistake rule with it.

Since [0030](./0030-attributes-live-in-a-layered-property-store.md) declared
artwork lives in the notation definition the graph carries, not in a computed
root attribute. The graph still carries it, which is what this ADR requires; the
rest stands.

Amended 2026-10-14 (OLD-248): neither the eighteen traced from SF Symbols nor the
legacy app's catalogue may ship in a public repo, so the built-in set is only
what the project drew or owns: `and`, `or`, `conflict`, `default` and the
`vithanco` logo. That reverses "worth doing on its own merits" under *Considered
and rejected*. The style guide's `ICONS` table is the master; a test holds
`BuiltinIcons` to it. Everything else stands: declared names win, and an unknown
name draws the placeholder and is reported.

Amended 2026-10-15 (OLD-249): the node type badge and the Arithmetic operators draw
icons too, so the built-in set grows to 30 artworks under 43 further names, and
several names share one artwork. The registry therefore stores an artwork once
and maps names to it, and `VSVGDefs` writes the path once: the first name draws
it and the others are symbols that point at that one. "One `<symbol>` per name"
below still holds; the symbol is what is now small. A node's own style counts as
well as its type's, since an Equals node is repainted per instance.

## Context

A `vnotation` can say everything about a notation except what its nodes look
like. `IconInfo` holds `position | name | colour | size` — **the name is the only
channel between a notation and the renderer** — and the only names that resolve
are the eighteen entries of `SFSymbolPaths`. A user-defined notation therefore
has colours, shapes and meanings of its own, and eighteen icons borrowed from
whoever needed them first.

Four mechanical facts constrain the answer:

- **`SFSymbolPaths` lives in VGraphSVG, and VGraphSVG depends on VGraph, never
  the reverse.** Anything in VGraph that wants to know whether a name resolves
  cannot see that table.
- **An unresolvable name aborts the render.** `SFSymbolRenderer` throws
  `VError.iconNotFound` from three call sites, and `StyleFactories` defaults a
  missing `icon:` to `questionmark.circle.fill` precisely to stay away from it.
  There is no such thing today as a diagram with one icon missing.
- **Node sizing includes the icon** (`NodeStyleLayout+Dimensions` returns
  `VSize(iconSize, iconSize)`), and sizing happens before rendering. An icon
  dropped at render time leaves a reserved hole.
- **Not every path escapes.** The IR escapes attribute values, but
  `SVGBuilder.path` interpolates `d` raw. Untrusted path data reaching it
  escapes its attribute.

The eighteen built-in paths run 160–1768 characters, 15.5 KB in total.

## Decision

**Artwork is one path, named, declared in the `vnotation` block, carried by the
graph, resolved in one lookup, restricted on the way in, and visible when it is
missing.**

- **A path, not a picture** — one path plus a viewBox, exactly `SFSymbolPath`.
  Monochrome is not a simplification: `iconColor:` is documented on every
  icon-bearing `nodeStyle` and works by putting `fill` on the `<use>`. Artwork
  that carries its own colours makes that attribute a lie.
- **Named, in the block**: `icon flame [viewBox: "0 0 24 24", path: "M12 2c…"]`.
  The pipeline is name-keyed end to end — `collectIcons` returns a
  `Set<String>`, `VSVGDefs` emits one `<symbol id="icon-…">` per name — so
  artwork without a name has nothing to hang its dedup on. Two node types share an
  icon by naming it twice.
- **Declared artwork is a computed graph attribute**, appended to as the notation
  installs and rebuilt on every parse, exactly as `graph.groupTypes` is. The
  renderer is handed a laid-out `VGraph` and never a `NotationEntry`, so the
  graph is the only thing in the room that can answer.
- **One lookup, `declared ?? built-in`.** A notation's `flame` *is* `flame`. The
  built-in table moves into VGraph as `BuiltinIcons`, because a name that
  resolves to nothing has to be reportable and a `QualityCheck` is a pure
  function of a `VGraph`. (Found while building: the first draft of this ADR said
  the table stays in VGraphSVG, which cannot both be true and leave the report
  possible.) That is a move, not a seeding: the graph still carries
  only what the document declared, so the exporter still knows what the user
  wrote.
- **A `path:` value admits only** path commands `MmLlHhVvCcSsQqTtAaZz`, digits,
  `.,+-eE` and whitespace, capped at 4 KB; `viewBox:` is four numbers.
- **An unresolvable name draws a dedicated missing-icon placeholder** in the space it
  reserved, reported by a quality check and coloured in the source view — the
  `__UNKNOWN_NODE_TYPE__` shape, not the group one: an icon is a small claim, so
  it does not redden the node.

### Why shadowing is silent rather than an error

`flame` resolves to nothing today, so someone will draw their own. If VGraph
later ships a built-in `flame` and built-ins won — or worse, if the collision
were a parse error — that release would change or break documents already in the
wild. Declared-first is the only order under which a document's appearance is
stable against what VGraph adds later, which is the same promise as "renders
everywhere VGL renders".

### Why the input is restricted rather than the output escaped

Escaping is a rule every current and future output path has to remember; a
charset makes `"`, `<` and `&` unrepresentable, so the raw interpolation in
`SVGBuilder.path` is safe by construction. It also puts the error on the line
that caused it instead of in a silently broken diagram. The cost is accepted:
`M M M` is legal here and renders as nothing.

## Considered and rejected

- **Compiling the old app's 101 icons in, instead of this.** It makes converted
  documents work and closes nothing: the icon a user-defined notation wants is
  the one nobody shipped. Still worth doing on its own merits, separately.
- **An arbitrary SVG fragment as artwork.** Buys multi-colour logos; costs
  `iconColor:`, and buys a sanitiser — script, `foreignObject`, external `href`,
  and id collisions with the document's own `icon-…` symbols — on a website that
  renders other people's `.vgl`.
- **Embedded raster.** Renders anything, recolours nothing, and puts
  multi-kilobyte base64 in a hand-edited text file.
- **Artwork inline on each node type.** No name to invent, but the artwork is
  duplicated verbatim when two types share an icon and the symbol id has to be
  synthesised from the path.
- **A top-level icon block, outside `vnotation`.** Would let a document on a
  built-in notation carry an icon without declaring a notation. Rejected while
  there is no editor path that would need it; `vnotation X extends IBIS` already
  covers the hand-written case.
- **Seeding the eighteen into the graph's registry**, so a declaration overwrites
  a dictionary entry and there is one literal table. The exporter reconstructs
  the `vnotation` block
  *from the graph*, so it could no longer tell a declared `flame` from a shipped
  `lightbulb.fill` without an origin flag. The two-table distinction reappears at
  export time, in the one place where getting it wrong writes eighteen blobs of
  path data into the user's file. (Where the table *lives* is a separate
  question, settled above.)
- **Storage on the notation entry.** 0020 rejected the same shape for group
  types, and for the same reason.
- **Silent degradation** — the node simply loses its icon. It is what the draft
  asked for and it is the failure mode 0020 named: the mistake becomes invisible
  in the diagram, the quality report and the source at once.
- **Dropping the icon and re-sizing the node**, so there is no hole and no
  placeholder. The best-looking answer, and it needs resolution to happen before
  layout — which means the built-in table has to be visible in VGraph after all.

## Consequences

- VGraph gains a value type that is unambiguously about drawing, and the
  eighteen paths with it. `NodeStyle` and `IconInfo` already live there, so the
  line was never pristine, but it moves. VGraphSVG stops owning content and only
  emits markup.
- Four tests assert `iconNotFound` is thrown; they encode the abort this removes.
- Icons remain unreachable without writing VGL — a stated gap against the
  ambition that, in the long run, every feature is reachable in the editor.
- A converted legacy document renders, with a report naming every icon it wants.
  That is what makes compiling the 101 optional rather than blocking.
- A node is drawn from an icon's *name* alone: `<use>` takes a square viewport
  and the `<symbol>`'s viewBox does the fitting. That is what keeps the render
  path — which holds a `NodeStyleLayout` and no graph — free of resolution.
- Nothing here helps a notation that wants an icon in more than one colour. That
  is a second feature, and it would need `iconColor:` to mean something new.
