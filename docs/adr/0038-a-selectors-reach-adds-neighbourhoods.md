# 38. A selector's reach adds neighbourhoods

Date: 2026-11-14

## Status

Accepted. Settles the question [0037](./0037-a-neighbourhood-follows-the-claims-a-node-is-part-of.md)
left open; amends the reach of [0029](./0029-one-model-many-views.md).

## Context

Reach (`+n`, `downstream n`, `upstream n`, `expand n`) counted edges, so it
stopped where a claim had not ended. In a Concept Map `include node prompt +1`
showed the Relation pill pointing at nothing; in a CRT `a downstream 1` showed
an AND with one input. Hovering the same node showed the whole claim, so
"around x" meant two things.

## Decision

Every reach adds neighbourhoods, the same walk hover draws. Direction only picks
the edges the walk leaves an ordinary start node by; past that, each node
carries it by its own `addsToNeighborhood`. So `a downstream 1` brings `b`, which
is not downstream of `a`: an AND shown with one input reads as a claim the
diagram does not make. For the same reason a start node that carries the walk
brings its whole neighbourhood whatever the direction: `carries downstream 1`
shows the Relation's subjects as well as its objects.

A further round starts only from nodes reached in the reach's direction:
`downstream 2` goes on from the AND's output, not from its other inputs, whose
own effects are not downstream of `a`. `+n` goes on from every node reached.

The walk lives in the core, so hover and views share one definition. Hover runs
it on the view graph, selectors on the origin graph.

## Consequences

Results change only in notations with `all` or `onward` nodes. No version flag:
the earlier results there were the dangling-node bug, and no shipped document
used reach in those notations.
