# 23. Retyping an edge

Date: 2026-09-22

## Status

Accepted. Completes the retype family: a node has had `changeType` since
[0002](./0002-origingraph-graphsession-vcommands.md), a group since
[0020](./0020-a-graph-carries-its-group-type-registry.md), and an edge has had
nothing. Adds one query and one command to the diagram pane's port from
[0013](./0013-driving-ports-and-named-commands.md). Reads the bounds of
[0011](./0011-bounds-on-edge-and-node-types.md) through the rule
[0021](./0021-reattaching-an-edge-end.md) established for reading them against a
smaller graph.

Decompose and Reattach now retype too, when an edge's ends both become details —
see [0032](./0032-hierarchical-notations-via-detailing.md).

## Context

An IBIS author who drew *supports* and meant *objects-to* has to delete the edge
and draw it again — losing the label, the comments and `itemOrder` with it. A
node in the same position is retyped from the menu, and so is a group boundary.

Two facts found while designing this, and each moved the answer:

- **The graph operation already exists.**
  `VGraph.reattach(edge:from:to:edgeType:)` with *both* ends `nil` is exactly a
  retype: same id, the pairing validated by `add(edge:)`, and the label, comments
  and `itemOrder` carried across. `setEdgeType(edge:type:)` is the other
  candidate and is the wrong one — it does not validate the pairing, which is why
  `retype(node:…)` has to follow it with `ensureEdgeTypeFits`. Nothing new is
  needed below the session.
- **`connectCandidates` cannot be asked directly.** It counts the graph as it
  stands, including the edge being retyped. Under `samePairMax: 1` the list comes
  back empty for the pair the user is standing on — precisely the edges most
  worth retyping. This is 0021's finding, one command over: the query is the only
  place [[Bound]] is read at all, so it is the only place this can be got
  right.

So the command is close to free, but not for the reason the issue behind it
assumed: the saving is in `reattach`, not in `connectCandidates`.

## Decision

**Retyping an edge is `reattach` with both ends `nil`, over a candidate list
computed on the graph minus that edge.**

```
retypeCandidates(edge:) = delete(edge:).connectCandidates(from:to:)
                          minus the current type
```

Dropping the current type follows the **node** sibling rather than
`reattachCandidates`, which drops nothing: "change it to what it already is" is
not an offer. Unknown types need no filter of their own — `connectCandidates`
reads `knownEdgeTypes`, which has already excluded them. With the current type
dropped, `edgeRetypeOptions` reuses the node's `count > 1` guard unchanged — a notation leaving exactly one alternative retypes on the menu
click, without a picker, as a node does today.

### It never flips

`reverseCandidates` is `knownEdgeTypes(from: targetType, to: sourceType)`; this
list is the same call the other way round. In a symmetric notation the two sets
overlap, so the same type name can appear under *Change direction* and *Change
type* on one edge meaning two different things.

0021 ruled that reattach must not express a flip. The same rule binds here, and
structurally rather than by policy: passing both ends as `nil` leaves no
parameter through which an endpoint could move. *Change direction* and *Change
type* stay separate menu entries, adjacent to each other, each doing one thing.

Considered and rejected: *one entry offering both lists*. It reads as a single
question — "what is this edge?" — and answers it by silently reorienting the
arrow, which is not what the user asked for.

### No [[Notation break]], and therefore `.notApplicable`

`changeDirection` needs ⌥ because the notation may offer **nothing** for the
flipped pair, leaving the break as the only route. Retype's list is empty only
when the notation permits exactly one type for a pair it already permits — and
minting `__UNKNOWN_EDGE_TYPE__` there de-types a legal edge into a bold red
quality warning. No author means that.

The availability then follows, and is forced rather than chosen:
`.forbiddenByNotation` enables the item under ⌥, which would open a conversation
with nothing to offer and dismiss it immediately — the "menu says enabled,
method refused" mismatch `MenuAgreesWithExecutionTest` exists to catch. So an
empty list is `.notApplicable`, for the reason 0020 already gives for a group:
there is no rule here for ⌥ to break.

Adding the break later is additive, if daily use argues for it.

### Two names, because two overloads would not compile

`changeType(of:to:)` already has a node form and a group form. A third taking
`EdgeType.Id?` makes `changeType(of: id, to: nil)` ambiguous against the group's
`GroupType?`. `retypeCandidates(for:)` is worse: an edge form differing only in
return type breaks existing call sites that use `.first` with no contextual
type.

Each layer takes its own layer's convention:

- **Port and session**: `changeType(of edgeId: String, using type: EdgeType.Id?)`.
  No `notationBreak`, following the *group* form rather than the node one: with
  no break to permit the parameter could only ever be `.forbidden`, and a dead
  argument on a port requirement is one every conformer has to explain.
  `using:` names an edge type everywhere else in this port —
  `connect(_:to:using:)`, `reattach(…using:)`, `addSuccessor(from:using:)`. The
  query is `retypeCandidates(edge:)`, after `reattachCandidates(edge:end:to:)`.
- **EditorCore**: `edgeRetypeOptions(for:in:)`, after `groupRetypeOptions(for:in:)`
  — the same file's precedent for the same idea on a different element kind. No
  `notationBreak` parameter, following `reversalOptions(for:in:)`.

`using:` takes `nil` only when there is nothing to choose, as `changeDirection`
does: `commandUnavailable` when the target is not an edge or the list is empty,
`commandAnswersMismatched` when the list holds two or more and nothing was
named, `commandOptionNotOffered` for a type outside the list.

### Through the conversation, not around it

The command goes through `begin`/`next` and lands as its own action case,
`.changeEdgeType(edge:using:notationBreak:)`, beside `.changeDirection` and
`.split`. It is a one-question command: no `Retype` loop, and no cascade —
retyping an edge leaves nothing ambiguous, because the endpoints and their node
types do not move.

Considered and rejected: *its own options function outside the conversation*,
the way group retype was built. `groupRetypeOptions` has no caller outside its
test, and the group form is unreachable from the editor as a result. That is the
shape not to copy.

Sharing the `.changeType` command id means three sites must branch on element
kind — `isDisabled`, `begin`, and the break-exclusion in `next(after option:)`,
which must not exclude an edge id from a list of node types.

## Consequences

- **`add(edge:)` does not enforce maxima** (0011, 0021), so retype is validated
  on the pairing only. The candidate query is the sole guard against exceeding a
  bound, which makes the minus-this-edge rule load-bearing rather than a
  convenience.

  The bound that pins it is a **node-level** one, `totalOutDegreeMax`, not
  `samePairMax`. The per-edge-type bounds — `samePairMax`, `outDegreeMax`,
  `inDegreeMax` — count only edges of the type being considered, so the only
  candidate they can exclude is the edge's current type, which is dropped from
  the list anyway. `totalOutDegreeMax` and `totalInDegreeMax` count every edge
  at the node regardless of type, so an edge that spends the last of its
  source's budget makes a naive `connectCandidates` answer *nothing at all* for
  its own pair.
  That is the case `ChangeEdgeTypeTest` fixes in place; a browser spec cannot,
  because it would assert only what the menu shows.
- **`MenuAgreesWithExecutionTest` was blind here.** Its `.changeType` arm drives
  the node overload and `continue`s on an empty list, so an edge would have
  passed unverified. The arm now branches on kind.
- **Group retype was unreachable from the editor** when this was written: the
  menu offered `changeType` on a group and nothing drove `groupRetypeOptions`.
  Fixed since (OLD-183).
- **No MCP tool.** VGL already expresses an edge's type by restating the line,
  so agents were never blocked — this gap was UI-only, and closing it serves the
  ambition that, in the long run, every feature is reachable in the editor.
- The edge's id is derived from its endpoints, so retyping never changes it and
  the VGL diff is one token.
