# 29. One model, many views

Date: 2026-09-27

## Status

Accepted. Replaces the *Interim* section of
[0003](./0003-c4-zoom-as-group-fold-state.md) — its trigger, "when views become
declarable in VGL", is this. Builds on [0027](./0027-judge-the-origin-graph-present-the-display-graph.md).
The *two cascades* and the *look* are superseded by
[0030](./0030-attributes-live-in-a-layered-property-store.md): one stack of
layers, with views limited to presentation attributes.

## Context

A document could show its model one way only. C4's reason for zoom — System
Context beside Container — needed two fold states of one graph at once, and fold
state lived on the group. The same held for every other setting that changes
what is shown rather than what is true: layout direction, `loopMarkers`, and the
Display pipeline's *Select Subset* stage, which had no input at all.

0003's interim note also said `isFolded` "appears in no `.vgl` file". It was
already wrong: VGL has had a `folded group` prefix, and the guide ships an
example using it.

## Decision

- **Three layers: model → view → look.** The model (`vgraph`) is what is true;
  a **view** (`vview`) is what is shown and how it is arranged; the **look** is
  how each kind of thing is drawn.
- **The test is ADR-0027's, generalised:** if anything judges a setting, it is
  model. Fold state, the subset, `rankdir`, `alignGroup`, edge `weight` and
  `loopMarkers` are view.
- **Views live in the document**, after the `vgraph` block, and are addressed
  by name when rendering. A host shows view X of file Y without VGL referring to
  files.
- **Two cascades, never one.** View settings: notation < `vgraph` block <
  `vview`. Appearance: the look's rule
  for a type < the element's own attribute. Each attribute belongs to exactly
  one. They cannot share an order: a view must beat the `vgraph` block's fold,
  while a node's own colour must beat any look, because it marks meaning.
- **The `vgraph` block keeps its view settings** and is the default view. Its
  `folded` prefix stays. A view declares state the same way
  (`folded group type: SystemBoundary`), never as an action.
- **A view chooses elements by ordered rules.** `include`/`exclude` over
  `node`, `group`, `node type`, `group type`, lists and `*`; neighbourhood
  (`+n`, `downstream n`, `upstream n`) on any selector; `expand n` on the result
  so far. A view whose first rule is `include` starts empty, any other starts
  with everything. Edges are never selected: one shows when both its ends do.
- **Hiding the middle of a chain draws a derived edge** — dotted, one per pair
  and direction — unless the view turns them off. *Amended with OLD-206: it carries
  no polarity, label or hover. It says "related through something hidden"; to see
  what, show the nodes.*
- **One look per document**, written in `vnotation` for now. A type's colour
  is how a reader recognises it, so a view may not change it.
- **Judging never reads a view.** The quality report gains a view section —
  coverage, derived edges, findings about hidden elements, rules naming nothing —
  that describes and judges nothing.
- **Selection is never stored.** A view can be made from one.

## Considered options

- **A single cascade with the view below the `vgraph` block.** Would let a look
  sit per view, and makes a view unable to unfold what the document folded.
- **Views in separate files** referencing a model. The engine is
  string-in/string-out and every plugin passes one text blob; addressing a view
  by name gives the same reach without a second file format.
- **Hiding without derived edges**, as 0027 does for bundles ("nothing is
  inferred"). Rejected: a view hiding the middle of a chain would claim its ends
  are unrelated, which is false. Clutter is visible; that silence is not.
- **A look per view.** Rejected for recognition across views; the appearance
  cascade has the slot if it is ever wanted.

## Consequences

- `toggleFolding` stops being a model change and becomes a change to the active
  view. In the default view that is still the `vgraph` block, so today's files
  and behaviour are unchanged.
- The look has no VGL of its own yet. The code gets the seam first — a look
  separate from `NodeTypeDefinition`, applied as a Display pipeline step — so
  the classic look, which survives only in history before f8909fc, can return
  without touching any grammar.
- Deleting an element in the editor also removes it from every view's rules; an
  unknown id in a hand-written view is a view finding, not an error.

## Amendments

- **Selectors run on the origin graph.** `downstream 1` follows the model's
  edges, not a graph the earlier rules thinned; otherwise a result would depend
  on the other statements and on derived edges.
- **A result is a set of nodes and groups.** A node adds its enclosing groups
  implicitly; `include group g` adds the group itself and its members, and the
  group stays when the members are excluded afterwards. A second rule dropping a
  box that frames everything was tried and rejected: it made a box appear or
  vanish when an unrelated node was added.
- **"Display graph" is now "view graph"** — the graph a view's recipe produces.
  The pipeline keeps its name.
