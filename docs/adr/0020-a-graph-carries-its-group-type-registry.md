# 20. A graph carries its group-type registry

Date: 2026-08-17

## Status

Accepted. Completes [0004](./0004-groupstyle-folded-unfolded.md), which
introduced [[GroupType]] without a way to enumerate one. Retires the "the group
is created untyped" aside in [0018](./0018-selection-and-group-creation.md), and
adds `changeType` on a group to the port of
[0013](./0013-driving-ports-and-named-commands.md).

Since [0030](./0030-attributes-live-in-a-layered-property-store.md) the registry
lives in the notation definition the graph carries, not in a computed root
attribute, and the reason for rejecting a stored property (a group type is not
structural) no longer holds. The unknown group type and `changeType` stand.

Group types now serve plain groups only; a detailed node is typed by a node type
— see [0032](./0032-hierarchical-notations-via-detailing.md).

## Context

A `NodeType` is structural: it lives in the `TypedGraph`, so `graph.nodeTypes`
can answer and every menu, check and highlighter reads from that one list. A
`GroupType` is not. [0004](./0004-groupstyle-folded-unfolded.md) made it an
attribute tag, registered by `add(groupType:)` — which only reserved the type's
slot in the attribute keyspace and remembered nothing.

Two things were impossible as a result, and neither was about styling:

- **Nothing could offer a boundary kind.** 0018 created every group untyped and
  said why: no `groupTypes()` query exists anywhere. So a C4 boundary could be
  typed in VGL and never drawn.
- **Nothing could reject one.** `GroupType.fromString` cannot fail, so
  `group x: SystemBoundry { … }` parsed, resolved no style, and rendered as an
  ordinary cluster. The typo was invisible in the diagram, in the quality report
  and in the source.

The attribute store could not be asked, either: it is one flat string keyspace
shared by nodes, groups, node types and group types, so "which of these ids is a
group type" has no answer in it.

## Decision

**The registry is a computed graph attribute**, `graph.groupTypes`, held on the
[[Root group]] and appended to by `add(groupType:)`.

Considered and rejected:

- *A stored property on `VGraph`*, symmetric with `graph.nodeTypes`. It types
  better and reads cheaper, but it makes a `GroupType` structural — reversing
  0004's central claim — for a tag that still only selects a style.
- *A static list on the notation declaration only.* It cannot answer for a
  `vnotation`, and the parser needs to ask the **graph** in front of it whether a
  name is registered.

Being `.computed` decides its lifecycle: never exported, and rebuilt every time
the notation installs — which is every parse. The registry is therefore derived
data that happens to live in the store, not a second source of truth about a
document.

The static list exists too, as `entry.groupTypeDefinitions`, and serves the
opposite need: `metadescription` and the `describe_notation` MCP tool render
from a `NotationEntry` and never see a graph. Node types have had both forms all
along, for exactly this reason.

### An unrecognised type is the third unknown type

`__UNKNOWN_GROUP_TYPE__` joins `__UNKNOWN_NODE_TYPE__` and
`__UNKNOWN_EDGE_TYPE__`, with the same shape: the parser stamps it, a
`GenericQualityChecks` entry reports it, and the source view colours the word
that caused it. It follows the **edge** precedent rather than the node one in
being visible in the drawing — a red boundary — because a boundary is a large
visual claim and a mistyped one that renders as an ordinary cluster hides the
mistake in the place the author is looking.

### `changeType`, not a second verb

A group's boundary kind is the same idea as a node's type one level up, so it
takes the same command. It holds no conversation, unlike the node form: an
edge's group is derived ([0017](./0017-an-edges-group-is-derived.md)), so
retyping a boundary leaves no edge ambiguous.

It offers **"Plain group"** alongside the registered kinds, and that entry
deletes the attribute rather than writing an empty one. Untyped is a real state
that most groups in most notations are in, so typing a group must not be a
one-way door.

There is no [[Notation break]] here. ⌥ reaches an unknown node or edge type
because a user may legitimately mean a shape the notation lacks; an unknown
*group* type only ever means a broken document, so the command is
`.notApplicable` where a notation registered no boundaries, not
`.forbiddenByNotation`.

## Consequences

- C4 is still the only notation with boundaries, so `changeType` on a group is
  greyed everywhere else. The feature is real but narrow until a second notation
  wants them.
- `vnotation` declares a group type by name with `group type: X`,
  so tests need not borrow C4's. It cannot give one a `GroupStyle` yet.
- Boundary *nesting* remains unvalidated: nothing says a ContainerBoundary
  belongs inside a SystemBoundary, and the menu now makes that easy to get
  wrong.
