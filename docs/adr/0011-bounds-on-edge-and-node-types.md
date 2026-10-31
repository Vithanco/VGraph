# 11. Bounds on edge and node types

Date: 2026-08-02 (revised 2026-08-03; names 2026-09-26)

## Status

Accepted. [0012](./0012-drag-to-connect.md) depends on it. Absorbs 0026, which
renamed the bounds.

## Context

`EdgeType` is an id, a `from` node type and a `to` node type — a pure *adjacency
permission*: "a T1 may point at a T2 under the name N." The domain language
cannot count.

Two pressures arrive at that gap. **EvaporatingCloud is structurally fixed and
cannot say so**: an Objective has exactly two Needs, each Need exactly one Want,
and nothing catches a cloud with three Needs. **Direct manipulation needs a
duplicate rule**: dragging one node onto another must decide whether a pair
already joined by the only legal edge type is still a valid drop. Reaching for
"multiplicity" here is a trap worth naming — UML-style multiplicity bounds
*degree* and says nothing about whether two links go to the *same* target. The
duplicate question is **uniqueness**, which classical multiplicity cannot
express.

Three mechanical facts constrain where a bound can be enforced:

- **The parser builds edges through `add(edge:edgeType:group:)`**, so anything
  `add` throws on is a parse failure — in the editor, the last good preview is
  retained and the document is effectively unopenable.
- **Minima cannot be checked incrementally.** `add` sees a graph
  mid-construction; a cloud legitimately passes through zero and one Need.
- **Two tiers already exist.** `ensureEdgeTypeFits` throws (hard); `QualityCheck`
  returns severities (soft).

Measured over the corpus — 17 built-in documents plus the C4 example — there is
**not one repeated `(from, to)` pair**, so no shipped document is affected by
any choice made here.

## Decision

**Bounds are declared on the notation, checked by graph analysis, and read by
commands.**

- **[[Bound]] is the umbrella, with two kinds.** Each is a `min…max`.

  | Kind | Bound | Counts |
  |---|---|---|
  | [[Degree bound]] | `outDegree` | edges of this type leaving one node of its `from` type |
  | [[Degree bound]] | `inDegree` | edges of this type entering one node of its `to` type |
  | [[Pair multiplicity]] | `samePair` | edges of this type between the *same* ordered pair of nodes |
  | [[Degree bound]] | `totalOutDegree`, `totalInDegree` | edges of *any* type leaving or entering one node of this node type |

  "Degree" is the word anyone outside Vithanco would use for four of the six.
  `samePair` is the one place "multiplicity" is exact: the graph-theory count of
  parallel edges. `samePair` rather than `perPair` because an `edge type:` line
  already names a pair — of node *types* — and the bound is about pairs of node
  *instances*.

- **Declared on the edge type, not the node type**, which makes them
  per-(node type × edge type) for free, since an `EdgeType` pins both ends. An
  Objective's "exactly two Needs" is `objectiveToNeed.outDegreeMin/Max = 2`; a
  bound on the node type could not say it, because an Objective's other outgoing
  edges would count toward the same total. IBIS shows it from the minimum side:
  "a Question needs at least one Answer" is `outDegreeMin: 1` on
  `questionToAnswer`, and a follow-up question is a *different* edge type, so it
  does not count — where an aggregate would have counted it.

- **`total` marks the aggregate on `NodeType`** — the one thing edge-type bounds
  cannot express: "a Concept must have at least one edge of *any* type." The
  word is there so that `outDegreeMin: 1` on Question and on Question→Answer
  cannot be read as the same claim; they differ as soon as a Question has a
  follow-up question.

- **`-1` is the default and means "not stated".** For a maximum, no ceiling; for
  a minimum, the same effect as `0` but a different intent. This is what makes
  *unbounded everywhere* fall out with no per-notation work.

- **Enforcement is soft.** `add(edge:)` is unchanged; a new `QualityCheck`
  reports violations. Chosen because the parser routes through `add`, and because
  minima are not incrementally checkable anyway — a hard rule could only ever
  have covered half the construct.

- **A maximum is an error; a minimum is a warning.** A maximum can only be
  exceeded deliberately. A minimum is unmet by every *unfinished* document: IBIS
  is question-first, so a Question with no Answer yet is the notation being
  followed, and `.error` there would paint a map in progress red for doing the
  right thing. A rule rather than a per-bound attribute, because it falls out of
  what the two kinds of bound mean.

- **A minimum faults the node.** A maximum has offending edges to point at; a
  minimum's fault is the *absence* of an edge, so it targets the node that is
  short.

- **Reporting is already built.** `MessageWithSeverity.target` drives editor
  highlighting and `buildHighlightHTML` wraps offending tokens with a tooltip, so
  a check emitting targeted messages gets the squiggle, the tooltip and the
  diagnostics row with no UI work.

- **Commands decline to create violations.** The candidate set a command offers
  reads the same bounds the check reads, so an affordance and an analysis can
  never disagree. Exceeding a bound stays reachable as a deliberate notation
  break, rendering as a quality error rather than an unknown edge type.

- **A bound is a claim about a type; a graph criterion is a claim about the
  graph.**

  | | says | lives |
  |---|---|---|
  | **Bound** | "an Objective has exactly two Needs" | attributes on an edge or node type |
  | **Criterion** | "this is a tree", "this is a simple digraph" | `QualityCheckRegistry`, named from `vnotation` |

  A Causal Loop Diagram's "at most one link between two stocks" reads like a
  per-pair bound and is not one: `samePairMax` counts *one* edge type, so `same`
  and `opposite` each bounded at one still permits one of each. It is a
  criterion, not a missing seventh bound. The previous bullet therefore holds
  **for bounds only** — a criterion is a closure that cannot be asked about an
  edge which does not exist yet.

- **Bounds are attributes**, exactly as colour and icon are, so both declaration
  sites work with **no new syntax**: `vnotation` already parses `[attrs]` into a
  free-form `rawAttrs`, and a compiled notation sets the same attributes in
  Swift. Nothing in the lexer, grammar or highlighter moves. What is *not*
  generic is either end — a hand-written `switch` in and a hand-written emit list
  out, which must agree exactly or a notation cannot survive a round trip. Both
  read one shared table (`Bound.edgeBounds` / `.nodeBounds`), matched
  case-insensitively because `vglKey` lowercases while a hand-written notation
  uses camelCase.

- **The first names still parse.** Before the rename the degree bounds were
  `perSource…`, `perTarget…`, `totalOut…` and `totalIn…`. They are aliases in
  the table; the exporter writes only the current names, so a document migrates
  the next time it is saved.

- **Giving one bound under both names is a parse error**, e.g.
  `[perSourceMin: 1, outDegreeMin: 2]` — even when the two values agree, since
  the old name is then noise to delete. It is the same kind of error as a bound
  that is not a whole number, and the only alternative that opens the document
  has to pick one value silently.

- **⌥ is how a bound is overridden.** Enforcement is soft, so there is nothing to
  override — ⌥ widens what the gesture *offers*, and the resulting graph is one
  the check then flags. That is why a bound can be exceeded deliberately but
  never by accident.

- **The mechanism lands before any adopter.** Every notation stays unbounded at
  first, so nothing observable changes. Each notation's actual numbers are a
  semantics judgement, not part of building this.

## Alternatives considered

- **Hard enforcement in `add(edge:)`.** Originally chosen, reversed once the
  min/max asymmetry surfaced. Strongest invariant — an in-memory `VGraph` is
  always notation-valid — at the price of a user's existing file becoming
  unopenable, and it cannot express a minimum at all.
- **Degree bounds only (UML-style).** Serves EvaporatingCloud, leaves the
  duplicate question unanswered: two `idea → link` edges both count toward
  out-degree, so unless the bound is 1 the duplicate survives.
- **`samePair` only** — the one bound direct manipulation needs. Rejected because
  the second would arrive within one notation's work, and a construct designed
  for one of two cases tends not to fit the other.
- **Set semantics per edge type**, so uniqueness falls out with nothing to
  declare. Rejected: VGraph edges have identity, labels, attributes and item
  order, so two `idea → link` edges with different labels are different things.
- **Demote a violating edge to an unknown edge type on parse.** That demotion
  means "no legal type exists for this pair", whereas a bound violation has a
  perfectly good type and too many instances of it.
- **A hard `samePair` with soft degree bounds.** Defensible — uniqueness *is*
  incrementally checkable — but rejected for one enforcement story rather than
  two.
- **Names for what each bound counts per** (`perSource`, `perTarget`), the first
  naming. Exact, but it hid that four of the six bound degree, which is the word
  a reader already has.
- **One name per direction on both type kinds** (`outDegreeMax` everywhere,
  meaning decided by where it is declared). Shorter, and rejected for the
  Question case above: the two claims would read the same.
- **"Degree" for everything, `samePair` included.** Two edges A→B and two edges
  A→C give A the same out-degree, which is exactly the difference `samePair`
  exists to see.
- **"Uniqueness" for `samePair`.** Describes a maximum of one, not
  `samePairMin` or a maximum above one.
- **Let the new name win when both are given.** Deterministic, and it keeps the
  document opening. Rejected because the user wrote two values for one bound,
  and one would vanish without a word.

## Consequences

- **The asymmetry is hidden, not removed.** Maxima are incrementally checkable
  and minima are not; reporting both through graph analysis papers over that. Any
  future move toward hard enforcement can only take the maxima.
- **A violating document always opens** — the tool marks up a bad diagram rather
  than refusing it. The cost: the violation is visible only to something that
  reads the quality report, and the Obsidian and VSCode plugins call
  `renderGraph` for an SVG string and never see one.
- **Two readers of one declaration.** The check and the candidate sets both
  interpret the bounds, so the pairing needs a test running both against the same
  graph rather than each alone.
- **Affordances are blind to criteria**, with one exception. A notation whose
  rule is a criterion gets no help from the gesture: the drop is offered and the
  diagnostics object afterwards. `noParallelEdges` is the exception: a notation
  declares criteria by name (`criteria`, or a `vnotation`'s `qualityCheck:`
  lines), and `connectCandidates` reads that list, so a pair already joined is
  not offered again — through connect, reattach and retype alike. Most built-in
  notations declare it; Arithmetic (`x + x`) and C4 (several real relationships
  per pair) do not.
- **`disconnectedNodes` stays.** It looked like "min 0 of any type" said twice;
  the bound/criterion split answers it — it speaks about the graph, not a type.
- **`default: break` hides a typo.** An unrecognised attribute name is silently
  discarded, so `[outDegreeMax: 2]` misspelt does nothing and says nothing.
  Pre-existing for every attribute. Worth its own change: the parser knows the
  full vocabulary and could reject an unknown name rather than drop it.
- **The alias table is permanent** unless every stored document is known to have
  been re-saved; dropping it turns an old bound into an unknown attribute, which
  the previous point says is silently discarded.
- **Two exporter early-returns had to move.** `reconstructNodeTypeSpec` and
  `reconstructEdgeTypeSpec` both bailed out on `attrs.isEmpty` *before* the
  bounds were considered. Any future attribute appended after that point
  inherits the same trap.
- **A bound counts every pair of its type**, including the pairs detailing adds
  ([0032](./0032-hierarchical-notations-via-detailing.md)).
- **Adoption is a semantics judgement, not a mechanical pass.** C4 stays
  unbounded on purpose: real Structurizr permits several relationships between
  the same pair. Most other notations are undecided.
