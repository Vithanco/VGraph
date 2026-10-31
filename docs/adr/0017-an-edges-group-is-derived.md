# 17. An edge's group is derived from its endpoints

Date: 2026-08-16

## Status

Accepted. Refines the group model of
[0016](./0016-canvas-is-the-root-group.md), whose root group is what the
derivation below bottoms out in. Nothing is superseded.

The attribute inheritance kept here is superseded by
[0030](./0030-attributes-live-in-a-layered-property-store.md): nothing is
inherited from an enclosing group. The derived membership stands.

## Context

`GroupStructure` stored three kinds of membership: node-in-group,
group-in-group, and edge-in-group. The parser wrote the third one, assigning
each edge to whichever group it was declared in.

Nothing could read it back out. The gap was found from the round-trip rule —
after a command applies, the exported text is already the document, and feeding
it back must change nothing ([`ReparseIdentityTest`](../../Tests/AppTests/ReparseIdentityTest.swift)):

- **The exporter cannot write it.** `GraphStructureTraverser` visits every edge
  at the end, at top level, so an edge declared inside a group came back at the
  root. One parse/export/reparse cycle and the membership was gone. Teaching the
  exporter to emit an edge inside its group's braces would have *created* the
  ability to say "this edge is in group A" while both its ends are in group B —
  a state no renderer could honour and the parser would faithfully preserve.
- **Nothing consumed it.** `getDirectContent(group:)` drops edge entries on the
  floor; no exporter, layout step or renderer asked which edges a group held.
- **The one place that genuinely needs the question already derives it.**
  `FoldingLayoutStep` decides internal-versus-crossing edges from the endpoints
  (`FoldingLayoutStep.swift:94`), ignoring the stored membership entirely. So
  did `connecting`, which computed the group of a new edge by comparing its two
  ends.
- **It went stale.** Moving a node out of a group left every edge at that node
  still claiming membership, and `delete(edge:)` never removed the mapping entry
  at all.

The one live consumer was attribute inheritance: `getAttributes(edge:)` and
`get(edge:attribute:)` walk the group chain, so an edge inside a group picks up
that group's edge attributes. It is reachable only through the API —
`set(group:attribute:)` does not check the attribute's target, so a caller can
put an `edge`-target attribute on a group. VGL cannot: attributes written inside
a group block resolve against `.graph` only (`VGraphParser.swift:174`). No
notation and no example `.vgl` depends on it.

## Decision

**An edge is in the innermost group that holds both of its ends.** It is
computed on demand, not stored.

- `VGraph.group(of: Edge.Id)` walks each endpoint's group ancestry and returns
  the first group common to both. `GroupStructure` no longer has an `edge` case,
  an `addTo(group:edge:)`, or a `group(of: edge)`, and `add(edge:)` no longer
  takes a `group:`.
- **Sibling subgroups resolve to their parent.** An edge from a node in `A.1` to
  one in `A.2` belongs to `A` — which is where it is drawn, and a question the
  stored form could not answer at all.
- **The fallback is the root group, not `nil`.** Every parsed node is under the
  root ([0016](./0016-canvas-is-the-root-group.md)), so the ancestry always terminates there and `group(of: edge)`
  agrees with `group(of: node)` about what "no particular group" means. `nil`
  now means only "this edge has no endpoints in any group" — hand-built graphs
  that never grouped anything.
- **Attribute inheritance keeps working and starts being consistent.**
  *Superseded by [0030](./0030-attributes-live-in-a-layered-property-store.md):*
  an edge inherits nothing from its group.

## Consequences

- **The round-trip gap closes by construction.** There is nothing left to export
  or restore, so no exporter change and no reparse hazard.
- **Two bugs go with the storage.** The stale membership after a node moves, and
  the mapping entry `delete(edge:)` leaked.
- **`group(of: edge)` is O(depth) rather than a dictionary hit.** Group nesting
  is shallow and the call sites are edit commands and attribute lookups, not
  inner loops.
- **An edge can no longer be given a group its endpoints contradict.** One test
  set up exactly that (`VGraphTest.edgeAttributesOnAllLevels`) to exercise
  group-level edge attributes; it now puts both ends in the group instead, which
  is the same assertion about a state the model can represent.
- **`VError.edgeAlreadyInGroup` is gone.** It could only be thrown by the
  storage.

## Considered alternatives

- **Emit the edge inside its group's braces on export.** The obvious repair, and
  the reason it was rejected is the whole of this ADR: it makes the
  contradictory state expressible and durable, to preserve a membership nothing
  but attribute inheritance ever read.
- **Drop edge-group membership entirely,** removing the attribute-inheritance
  lookups too. Rejected here; [0030](./0030-attributes-live-in-a-layered-property-store.md)
  later removed the inheritance, while the derived membership stays.
- **Keep `nil` for "no common group"** instead of the root, preserving the old
  `connecting` behaviour and one test line. Rejected: it would leave the two
  `group(of:)` overloads disagreeing about the root, which is the kind of split
  that gets rediscovered as a bug.
