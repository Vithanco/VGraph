# 37. A neighbourhood follows the claims a node is part of

Date: 2026-11-14

## Status

Accepted. Its reach for views is decided in [0038](./0038-a-selectors-reach-adds-neighbourhoods.md).

## Context

Hovering a node lit its edges and the nodes at their far ends, and walked on
past every AND/OR junctor (`isJunctor`) in every direction. In a Concept Map the
walk stops at the Relation: hovering a Concept shows its linking phrases but
never the concept on the other side, so no proposition is ever shown whole.

The obvious fix, making Relation a junctor, is wrong. A junctor's inputs make
one claim: "A and B together cause C", "C needs A, or else B". Hovering A has to
show B. A Relation's subjects each make their own: "Skill carries Method" and
"Prompt carries Method" are disputed separately. `MergeRelationsStep` also joins
Relations the author wrote apart, so a junctor's walk would let a layout merge
decide what a claim seems to include.

## Decision

The neighbourhood shows the claims the hovered element is part of. A node type
says how it carries the walk with `addsToNeighborhood`:

- `all`: every end, so the walk goes on in every direction. AND, OR,
  Arithmetic's `=`, which asserts everything attached to it is equal, and its
  operators, whose terms an equation cannot split. Hovering any part of
  `7 − 4 = 2 + 1` lights the whole equation.
- `onward`: only the ends that continue in the direction the walk came in.
  Concept Map's Relation: hovering a Concept lights every proposition it is
  subject or object of, but not the other subjects or objects a shared Relation
  adds.
- unset: the node is lit and the walk ends there. This covers every other type.

`all` fits a node type only when every edge it can have belongs to its one claim.
`=` has no edges except the terms it equates. EC's conflict fails the test: the
Assumptions attached to it explain the clash, which makes them claims *about* it
rather than part of it, so conflict stays unset.

When several such nodes stand in a row, each carries the walk by its own value.
Hovering an edge lights the claims it is part of. Hovering a Relation lights all
its propositions, as before.

The setting names what it does to the neighbourhood rather than what the node
is. "Junctor" keeps its meaning from logic, AND/OR only. `isJunctor` is removed:
this walk was its only consumer, and `vnotation` never documented it.

A selector's reach adds neighbourhoods too, decided separately in
[0038](./0038-a-selectors-reach-adds-neighbourhoods.md).

## Considered and rejected

- **Relation as a junctor, walking in every direction.** It lights other
  subjects and objects that are not part of the hovered concept's claims.
- **Every junctor walking onward only.** Concept Maps come out right, but every
  AND loses the other half of its claim.
- **Role flags** (`isJunctor`, `isLinkingPhrase`, …). The hover would have to
  know every role. Nodes like the arithmetic operators, which want the junctor's
  walk without being connectives, would each need another flag.
- **A Concept Map overlay adding CSS rules.** It works only for hover, keeps the
  rule as CSS strings in the SVG layer, and a `vnotation` cannot use it.
