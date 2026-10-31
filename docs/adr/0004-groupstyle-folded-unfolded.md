# 4. Groups gain a first-class GroupStyle with folded and unfolded faces

Date: 2026-07-24

## Status

Accepted. Since [0030](./0030-attributes-live-in-a-layered-property-store.md) a
group type is no longer an attribute tag: it is the second step of a group's
chain, held by the group structure, and `resolvedGroupStyle` reads the style
through that chain. The two faces stand.

A [[Detailed node]] folds into its node type's own look, not a `GroupStyle` —
see [0032](./0032-hierarchical-notations-via-detailing.md). The two faces stand
for plain groups.

## Context

[[0003-c4-zoom-as-group-fold-state]] models a C4 element you can zoom into as a
group that renders one way when folded (the element's box) and another when
unfolded (a boundary around its contents). To do that, a group needs to carry
**two appearances**, not one.

Before this, a node had a rich `NodeStyleLayout`, but a group had only loose,
individual attributes (border colour, dash, corner radius, label) and folding
produced a generic proxy box. There was no single value that said "here is how
this group looks folded, and here is how it looks unfolded."

## Decision

Give a group a first-class `GroupStyle` with two faces, symmetric to a node's
style:

- `GroupStyle { folded: NodeStyleLayout, unfolded: BoundaryChrome }`.
  - `folded` — the collapsed box (reuses the node styling vocabulary, so a folded
    C4 system looks exactly like the element card it stands for).
  - `unfolded` — the frame drawn round the contents (dashed border, colour, fill).
- A group resolves its style through `VGraph.resolvedGroupStyle`: a per-group
  override wins, else the group's [[GroupType]]'s registered style, else `nil`
  (caller falls back to the generic proxy).
- `GroupType` is an attribute-based type tag (unlike the structural `NodeType`),
  registered with `add(groupType:)` and styled with `set(groupType:attribute:)`.

Rendering consumes each face through a transform, not by special-casing the SVG
renderer: `FoldingLayoutStep` stamps the `folded` face onto the collapsed proxy
node, and `BoundaryChromeStep` stamps the `unfolded` face onto the group's loose
`Attributes.Group.*` so the renderer draws it with no knowledge of `GroupType`.

## Consequences

- C4 boundaries get their Structurizr look (muted dashed border, transparent
  fill) from data, not renderer branches.
- This is a **general** capability, not a C4 special case. It also unlocks, for
  example, a STRIDE `TrustBoundary` later, with its own `GroupStyle`.
- The colour round-trip through the attribute store is lossy (a `SemanticColor`
  with an id comes back as a `literal` with a recomputed dark hex), so tests
  compare `GroupStyle` canonically (`x.asString`) rather than by structural
  equality.
- Changed the fold path (`FoldingLayoutStep`) and introduced the boundary path
  (`BoundaryChromeStep`), both under the [[Display pipeline]].
