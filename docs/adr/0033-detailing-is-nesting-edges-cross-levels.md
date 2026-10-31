# 33. Detailing is nesting: edges cross levels

Date: 2026-10-18

## Status

Accepted. Records what [0032](./0032-hierarchical-notations-via-detailing.md)
chose implicitly, so a later notation knows which choice it would be changing.
Nothing in the code changes.

## Context

0032 makes a [[Detailed node]] a group whose details are nodes, and Decompose
moves every edge onto a detail. So an edge cannot stay on the detailed node, and
edges between a detail and a node outside it are normal. Whether that suits
notations other than C4 was open.

Notations that refine an element differ on one point: what an edge may join
across the boundary of the refined element.

| | Nested | Assigned |
|---|---|---|
| The detail is | inside the element, in the same model | a separate model the element points to |
| Examples | C4, Harel's higraphs and statecharts, ArchiMate nesting | ARIS eEPC function assignment, BPMN sub-process, IDEF0, DFD levelling |
| An edge may join a detail to a node outside | yes, at any depth | no |
| The element keeps its own edges | no, they are summarised from the details' | yes |
| Consistency comes from | the parent's edges being derived from the details' | the child's inputs and outputs matching the parent's (DFD *balancing*, IDEF0 ICOM) |
| Layer vocabulary | same or similar | often different |

"Nested" and "assigned" are the sources' own words (ArchiMate, ARIS), not ours;
the table is from memory of those notations, not checked against their specs.

## Decision

**VGraph's detailing is nested, and stays so.** Edges may end on details at any
depth; the gained pairs of 0032 are that rule. Folding shows the summary, with
the bundle count, which is the derived edge of a nested model.

**Layer vocabulary is already per level.** `detailedBy` names different node
types per level (C4: system → container → component → code), so "each layer its
own node language" needs nothing new. Only how edges cross is fixed.

**Assigned detailing is not built.** No notation here needs it; only C4
details today. If one does, it adds a declared choice on [[Detailing]] and is
decided in its own ADR. The known cost is that a detailed node would have to keep
its own edges, which 0032 rejects ("the original node kept inside the group").
The names for that choice are open; "gained" is 0032's term for the widened
pairs and should not be reused for it.

## Consequences

- C4, ArchiMate-like and statechart-like notations fit as they are.
- A notation whose sub-models are walled off (ARIS, BPMN) cannot be expressed
  faithfully yet: its parent-level flow would be moved onto the details.
- Self-detailing types (sub-process, work package) are unaffected: the same
  edge type holds at every depth.

## What the widening does not stop

Edges are checked by type pair, never by where the two ends sit in the tree.
Still allowed: Person → CodeElement (`uses` reaches depth 3), `depends_on` onto
another system's component, and a container → component where container →
container exists. An element's edge to its own detail cannot be written: a
detailed node is a group, and an edge cannot end on a group.

c4model.com states none of the three as a rule, so C4 does not enforce them.
When a notation does state one, it is a warning criterion beside
`noParallelEdges` (guidance, and real diagrams need exceptions), not a change to
the widening.

C4's checklist does give one: every arrow has a label (`unlabelledRelationship`,
a warning; code-level `references` are exempt, being UML arrows). Its other items
(technology on elements and relationships, a description on every element) wait
for those attributes (0032, *Still open*).
