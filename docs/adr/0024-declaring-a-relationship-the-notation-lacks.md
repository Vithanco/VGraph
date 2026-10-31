# 24. Declaring a relationship the notation lacks

Date: 2026-09-23

## Status

Accepted. Amends [0012](./0012-drag-to-connect.md) and
[0021](./0021-reattaching-an-edge-end.md) — ⌥ still mints on both drags, but
what it mints can now be written down, and there is a way back out. Adds one
command to the port of [0013](./0013-driving-ports-and-named-commands.md), and
extends the edge retype of [0023](./0023-retyping-an-edge.md). Uses the
`vnotation` machinery of [0022](./0022-a-vnotation-carries-its-icons.md).

## Context

A [[Notation break]] on a [[Gesture]] mints an edge type named after the pair it
joins — `ensureUnknownEdgeType` — registers it in *this graph's* type registry,
and colours it red at penwidth 3. The notation still does not declare it, which
is why `QualityAnalysis.unknownEdgeTypes` reports every edge wearing one.

It exists because the model leaves no alternative. An `EdgeType` carries its
endpoint node types and `ensureEdgeTypeFits` enforces them, so
`concept_to_relation` cannot be put on a Concept→Concept edge. **An edge between
a pair no declared type joins cannot exist unless a type is invented for it.**

### The defect was a serialisation bug, not the break

The id read `__UNKNOWN_EDGE_TYPE__:Concept->Relation`. The lexer reads
alphanumerics plus `_`, `.` and `-` after an identifier's first character, so
`:` and `->` were never in that set — and the exporter names a type wherever it
cannot be inferred. Measured in the editor: the command succeeds, the diagram
renders, `saveDraft` autosaves the text, and the **next keystroke** in the text
pane fails with *"Syntax error: expected an identifier"*. Reopening such a
document gives no SVG and no nodes at all, and with the parse goes the render,
the export, the quality report, editing and undo.

Wider still on a `vnotation` document, where `reconstructVNotation` emits the
minted type into the block — there *every* minted type was unreadable, not only
one over a pair a declared type also joins.

`__UNKNOWN_NODE_TYPE__` and `__UNKNOWN_GROUP_TYPE__` never had this, because
they are bare identifiers. That is the whole difference.

### What was tried first, and why it was too much

The first attempt made ⌥ *ask for a name* at the drop, so nothing unwritable was
ever produced. It worked, and it was the wrong size: it taxed every ⌥ with a
keystroke to fix two characters in a generated id. Reverted.

## Decision

**Two changes, at very different altitudes.**

**1. A minted id must lex as a VGL identifier.**
`__UNKNOWN_EDGE_TYPE__Concept_to_Relation`. Every consumer tests
`hasPrefix(unknownPrefix)` and nothing splits the id, so its shape was free.
This alone ends the data loss, for every mint site at once —
`connect`, `reattach`, `addingRelated`, `splitting`,
`reversingWithUnknownType` and the ambiguous-edge fallback in `retyping`.

A break is therefore now **a state the document can hold, close and reopen**.
That is the promise everything else rests on.

**2. `declareEdgeType(for:named:)` — the way *out* of a break.**
On an edge wearing a minted type, **Change type** offers "New relationship…".
The answer is a name; the command declares that type, promotes the document's
notation to a `vnotation` extending the one it had, and moves the edge onto it
with `reattach` — both ends unmoved, so the label, the comments and `itemOrder`
survive.

```
vnotation ConceptMapExtended extends ConceptMap {
	edge type: concept_to_concept  from: Concept  to: Concept
}

vgraph demo: ConceptMapExtended "Demo" { … edge a -> b }
```

`reconstructVNotation` already rebuilt that block by diffing the graph's types
against the base, so the exporter needed nothing told to it.

Considered and rejected:

- ***⌥ asks for the name at the drop.*** Sketching off-notation stops being
  free, and the author is asked to name a relationship at the moment they are
  least sure what it is. Sketch now, name later is only possible because (1)
  makes the intermediate state durable.
- ***A new VGL spelling for unknown types*** (`edge a -> r: ?`), uniformly for
  node, edge and group. It buys an explicit marker in the source; it costs the
  lexer, the parser, the exporter, the highlighter and the guide. The
  highlighter already colours an unrecognised type word through its
  `unknownType` role, so the marker is the one thing that was not missing.
- ***A singleton unknown edge type***, matching `NodeType.unknown` and
  `GroupType.unknown`. It needs a carve-out in `ensureEdgeTypeFits` *and* in
  `TypedGraph.add(edge:type:)`, and its `from`/`to` would hold two node types it
  does not mean. Node and group types can be singletons precisely because they
  carry no relational information; an edge type is nothing but relational
  information, so per-pair is the model being honest rather than a wart.

### Offered only where there is a break to leave

"New relationship…" appears on an edge whose type is minted, and nowhere else.
The availability rule reads: an edge's **Change type** is available when the
notation offers an alternative **or the edge's type is unknown**.

Offering it on every edge would tax properly-typed edges with a question they
will almost never want, and would retire 0023's rule that one alternative is not
a choice. Hiding it behind ⌥ would put the repair behind a modifier on the one
occasion the author most needs to find it — and ⌥ means nothing on an edge's
Change type otherwise.

It is a plain `VCommandOption`, not `isBreak`. A break goes *past* the guidance
and leaves a mark saying so; this **widens** the notation and leaves a
declaration saying so.

### Promotion takes the orphan with it

The minted type is deleted when the last edge wearing it is promoted. Without
that, the now-`vnotation` document emits a dead
`edge type: __UNKNOWN_EDGE_TYPE__…` line on every export. Two broken edges over
one pair share a single minted type, so only the last one clears it.

This needed `TypedGraph.delete(edgeType:)` fixed: `getMany` answers nil for a
type nothing references — exactly the type that may be deleted — and reading
nil as "not found" made it refuse every unused type, which is the only kind it
would ever be asked about.

### One question, not two

The derived notation is named `\(base)Extended` rather than asked about. The
author is naming a *relationship*; what to call the notation is bookkeeping. The
field is seeded with `concept_to_concept` — the notation's own convention — so
Return accepts it. A name that is not a VGL identifier, is a keyword, or is a
type the graph already has is refused with `edgeTypeNameRefused`, which re-opens
the field on what was typed, the path `setURL` already walks.

## Consequences

- **⌥ still costs nothing**, on both drags. `connect` and `reattach` keep their
  `notationBreak`, and `connectTargets`/`reattachTargets` still widen under it.
- **Minting is visible at its call site.** `connecting` and `reattaching` take a
  non-optional `EdgeType`; the session calls `ensureUnknownEdgeType` itself. The
  signature says whether a path can mint, instead of a `nil` that also serves
  the ordinary path.
- **A guard-rail test holds the property that broke.** One loop over every
  command that can mint, running it, exporting, and parsing the export back. It
  fails on all five menu paths with the old id. Nothing held this before, which
  is how it survived: the two browser specs that touched it asserted the broken
  string as *expected output*.
- **Declaring is wired to `connect`'s leftovers only in the sense that any
  minted edge can be promoted** — a reattach's break, a split's, a reversal's
  and a node retype's all leave the same red edge and take the same way out.
- A diagram that declares a relationship is no longer on a registered notation:
  `vgraph demo: ConceptMapExtended`. Rendering follows the `extends` chain, so
  it draws as a Concept Map — but `describe_notation` and the website pages know
  only the base.
- **Unknown node and group types are untouched**, and deliberately: they are not
  breaks. Only the parser produces them, from a document naming a type the
  notation lacks, and `CONTEXT.md` already separates them from a deliberate
  deviation. They round-trip today, losing the authored word — a separate
  question, and not this one.
