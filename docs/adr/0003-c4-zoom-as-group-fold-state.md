# 3. C4 zoom levels as fold states of one graph

Date: 2026-07-24

## Status

Accepted. The fold-as-zoom mechanism stands. Where the fold state is stored is
superseded by [0029](./0029-one-model-many-views.md): it is view state.

A C4 element becomes zoomable by [[Decompose]], a model command, which turns the
node into a [[Detailed node]] — a group carrying its node type — rather than a
group with a group type; see [0032](./0032-hierarchical-notations-via-detailing.md).

## Context

The C4 model describes a software system at four levels of zoom — System Context,
Container, Component, Code. Conventional tooling (Structurizr) keeps a **single
model** and renders **many views**, one per level, each a hand-picked projection.

VGraph already had a mechanism doing most of what C4 zoom needs: group folding. A
folded group collapses to a single proxy node, and folding auto-redirects the
edges that crossed the group's boundary to that proxy.

## Decision

Model the four C4 levels as **fold states of one graph**, not a
document-per-level.

- A C4 element you can zoom into is a **group** carrying a `GroupType`. Folded it
  renders as that element's box; unfolded it shows its contents inside a
  boundary.
- Zooming in is unfolding; zooming out is folding.
- Folding's existing edge redirection is exactly the projection C4 needs at each
  level, so no separate view-projection machinery is required.

## Consequences

- One source of truth, so the four levels cannot drift out of sync — they are the
  same graph.
- The editor's fold/unfold *is* the C4 level switch, with no extra UI concept.
- Structurizr-style "single model, many curated views" was deliberately **not**
  built: named views, per-view style overrides and include/exclude rules are a
  much larger feature that would have duplicated folding. It can be added on top
  later.
- Hard to reverse: a lot of C4 is built on it. See
  [0004](./0004-groupstyle-folded-unfolded.md) for the styling half.

## Interim: fold state lives on the group

*Superseded by [0029](./0029-one-model-many-views.md).* Fold state was briefly a
document attribute of the group; it is view state, declared in a `vview` or, for
the default view, in the `vgraph` block.
