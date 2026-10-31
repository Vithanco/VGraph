# 27. Judge the OriginGraph, present the display graph

Date: 2026-09-26

## Status

Accepted. Refines [0002](./0002-origingraph-graphsession-vcommands.md) and
[0003](./0003-c4-zoom-as-group-fold-state.md) without replacing them: folding still
redirects edges onto a stand-in node reusing the group's id.

Note: The display graph of this record is called the **view graph** since OLD-191 (see [0029](./0029-one-model-many-views.md)).

## Context

Folding runs in the [[Display pipeline]] and turns each folded group into a node of
type `FoldedGroup`, with every crossing edge redirected onto it. That graph — the
display graph, now the [[View graph]] — was already kept away from quality checks, but not from
everything that judges: loop markers were computed on it. So a folded group could
hide a loop the model has, and invent one it does not (A→x1 and x2→A, both inside
the fold, become A→box→A).

The stand-in also leaked into the SVG as `node-<groupId>`. Every editor lookup for a
group asks for `group-<groupId>`, so double-click rename and the move drop-target
wash silently skipped folded groups, and the fold step did not carry the group's
link across, so its badge vanished.

## Decision

- **Judging reads the OriginGraph; presenting reads the display graph.** Quality
  checks, [[Bound]]s, [[Graph criterion]]s and loop detection take the OriginGraph.
  Layout, sizing, boundary chrome, hover highlighting and the *drawing* of loop
  markers take the display graph.
- **The stand-in node stays**, in the display graph only. The concern it raised —
  a node the model does not have — is met by the rule above, not by removing it.
- **A folded box is stamped `group-<id>`**, since the glossary stamps each rendered
  element with the OriginGraph id of what it represents. One function names a
  display node's element, so the box, its hover rule and its glow cannot disagree.
- **Parallel edges onto a folded box become an [[Edge bundle]]**, one per
  direction: "×n", members listed on hover, their type's style when they share one
  and a neutral one when they do not. A bundle offers unfolding, never an edge
  action. A single edge stays an edge.
- **Loop markers are projected.** Loops come from the OriginGraph. One wholly inside
  a folded group is not drawn; one passing through it is drawn with its hidden
  stops at the box and its polarity from the model's edges.

## Considered options

- **No stand-in node in `VGraph` at all**, the Graphviz adapter inventing one. The
  cleanest statement of "folding is a view", and rejected for now: sizing, the SVG,
  hover and the editor all expect a node, and none of the defects came from the
  stand-in existing — they came from judging it. Revisit with 0003's declarable
  views.
- **Draw every parallel edge.** Truthful, and cluttered past a handful: a large
  folded group turns one relationship into a fan of identical lines.
- **Bundle per direction and edge type.** Keeps a Causal Loop Diagram's `same` and
  `opposite` apart, at the cost of more lines. The neutral style of a mixed bundle,
  with members on hover, shows the mix without splitting it.

## Consequences

- **Hover stays on the display graph.** Hovering a folded box lights its bundles,
  which is a statement about the screen, not the model.
- **A bundle cannot be retyped or reattached**, so `noParallelEdges` never has to
  reason about one: it is judged on the OriginGraph, where a bundle does not exist.
- **The "↻n" hint for loops hidden inside a fold is left out**; nothing marks that
  a folded group contains loops.
