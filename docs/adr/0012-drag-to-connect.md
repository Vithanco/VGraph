# 12. Direct manipulation: dragging one node onto another

Date: 2026-08-02 (revised 2026-08-03)

## Status

Accepted; the gesture ships, but the machinery it introduced does not. The
arity-generic `VGestureCommand` family and `step(gestureId:targets:answers:)`
were removed by the named commands of
[0013](./0013-driving-ports-and-named-commands.md) — a drag now calls
`connect(_:to:using:notationBreak:)` by name, with `connectSources()` and
`connectTargets(from:notationBreak:)` as the feedback queries on the port. This
ADR's own observation is why: a gesture never had a single id to be asked about,
so `connect` was known by name in the adapter regardless.

Depends on [0011](./0011-bounds-on-edge-and-node-types.md)'s decision that a
candidate set reads the declared bounds. Sequenced before
[0013](./0013-driving-ports-and-named-commands.md).

## Context

Drag a node onto another node to create the edge between them — the second step
into direct manipulation, after VCommands. The diagram already answers
right-click (command menu, ADR-0013) and double-click (inline edit, ADR-0009);
press-and-drag is unused.

Facts that shape what is buildable:

- **Every render replaces the entire SVG.** ADR-0009 answered this by putting
  interaction chrome *outside* the SVG and closing it on render. Transient drag
  feedback has the same problem.
- **The editor cannot use a JavaScriptKit `JSClosure`** — a dependency's
  `@_expose` exports are dead-stripped, so a Swift-authored `addEventListener`
  never fires. All events ride ElementaryUI's `_DOMEventHandlerConfig` seam.
- **An edge cannot end on a group.** `add(edge:edgeType:group:)` throws
  `edgeEndpointIsGroup`. A folded group renders as a node but resolves to
  `.group`, so the same throw excludes it.
- **Moving an edge end is already possible in the domain**
  (`reattach(edge:from:to:edgeType:)`), but is blocked on *addressing*: "the head
  of this edge" is a position on an element, not an element.

## Decision

**A gesture is a command that names several elements in order.**

- **Bare drag, from anywhere on the node.** Graphviz owns layout, so
  drag-to-move has no meaning to compete with.

- **Armed only while the button is held.** `mousedown` (button 0) arms,
  `mouseup` disarms, a drag is movement while armed. A double-click is then
  arm/disarm/arm/disarm with no movement between, so `dblclick` and the inline
  edit are untouched, with no state machine to get wrong. The ~4px threshold is
  jitter tolerance, not a rule about what a drag is.

- **Connect is gesture-only**, so every adapter must implement it by name.
  Stated as a decision in [0013](./0013-driving-ports-and-named-commands.md)
  rather than left here as a surprise.

- **Direction is the direction dragged.** A drop is legal when an edge type
  joins `grabbed.nodeType → dropped.nodeType`. A type running the other way does
  *not* make the drop legal: direct manipulation's promise is that the gesture is
  the result, and an arrow that flips round after the drop breaks it even when the
  resulting graph is the one the notation wanted. `AddSuccessor` and
  `AddPredecessor` already exist as a pair for the same reason.

- **Nodes only.** Groups are excluded by the throw above. Dropping on the node
  just grabbed is excluded too — a self-loop is representable (CLD declares both
  `Stock → Stock`), but landing back where the drag started is a slip far more
  often than an intention.

- **The command owns legality, the adapter owns the gesture.** The candidate
  query reads the same bounds from [0011](./0011-bounds-on-edge-and-node-types.md)
  that the quality check reads, so the diagram cannot offer a drop the
  diagnostics box would flag. Only **maxima** can forbid an addition; a minimum
  is a shortfall and blocks nothing. A node is legal when *any* applicable edge
  type is still under `samePairMax`, `outDegreeMax`, `inDegreeMax`,
  `totalOutDegreeMax` and `totalInDegreeMax` — refusing a connection the
  notation permits because one of several types is exhausted would be the worse
  error.

- **The feedback is the ghost line, coloured by what is under the cursor.**
  Green over a node the drop would connect, red over one it would not.
  Hover-driven rather than set-driven: nothing is computed or painted until the
  pointer is over something, and red already means "unknown edge type", so the
  colour before the drop and after it say the same thing. The line lives in a
  `pointer-events:none` overlay *outside* the SVG — the overlay must not
  intercept the hit test that finds the drop target. Nothing inside the SVG
  changes, so ADR-0009's rule needs no exception.

- **⌥ is read continuously.** Holding it mid-drag turns a red line green and
  releasing it turns it back; the drop reads the key at release. `altKey` rides
  every `mousemove` and is treated as authoritative; a `keyup` seam covers a
  stationary pointer, so a missed key event self-heals on the next movement. More
  informative than the menu's latched behaviour, and it teaches the notation
  during the gesture rather than after it.

- **What the drop produces.** One applicable edge type: create it, no prompt.
  Several: a choice at the mouseup position, rendered by the existing menu. None,
  or ⌥ held: an unknown edge type — a notation break, bold red, one undo step. ⌥
  adds no "Other type…" entry, because here the modifier *is* the escape hatch.

- **A graph change cancels the drag**, exactly as it closes an inline edit:
  `cancelDrag()` goes beside `endInlineEdit()` in `performRender`. The realistic
  trigger is the debounced live preview landing mid-drag from typing just before
  it started. Escape, `mouseup` on empty canvas, and the pointer leaving the
  window all cancel.

- **Edge-end addressing is deferred with the `reattach` gesture.** Making
  `edge-<id>-head` addressable is not the additive stamp it looks like:
  `originId(fromDomId:)` strips one of three prefixes, so `edge-foo-head` yields
  the origin id `foo-head` — indistinguishable from a node genuinely called that.
  An edge end is a *position on* an element, so it cannot ride the existing id
  keyspace at all. *(Discharged 2026-08-20 by
  [0021](./0021-reattaching-an-edge-end.md), which declines the premise rather
  than solving it: an end stays unaddressable and the handle is chrome naming the
  pair (edge, end).)*

- **The relayout jump is accepted.** After the drop, Graphviz re-lays out the
  whole diagram and the node just dropped on moves somewhere else.

## Alternatives considered

- **Widening `VCommandTarget` into a pair**, so every target carries an empty
  second half. The original decision here, reversed before implementation:
  eleven of twelve commands would carry a field they never read, `appliesTo`
  goes ambiguous between grabbed and dropped kinds, and what keeps `connect` out
  of the menu becomes the accident that `availableCommands` resolves a single id.
  A `.pair` case on the existing enum is strictly worse — `elementId` and `kind`
  become undefined and every exhaustive switch must invent a meaning.
- **The destination as `answers[0]`.** Zero API surgery. Rejected because a
  gesture *picks elements out* before any question is asked, whereas answers
  carry replies — and because `soleCandidate` auto-answers a one-option choice,
  so "never auto-pick a destination" would hold only by the accident that a
  destination list carries no escape hatch.
- **A `VCommandRequest.element` case**, preserving a menu path via a picking
  mode ("now click the other end"). Genuinely attractive, and what ADR-0009 left
  the enum open for. Rejected as a consequence of making connect gesture-only:
  once no menu renders the request, the case has no reader.
- **Highlighting the whole set of legal drop targets.** The original decision,
  and better discoverability — it answers "where *can* I go?" rather than only
  "may I go here?". Rejected because it requires stamping a class *inside* the
  SVG, needing an explicit exception to ADR-0009's rule, and because it computes
  the full set on every mousedown when a single membership test is what the line
  needs. The candidate query returns a set regardless, so this is not blocked.
- **Offering the reversal when only the reverse edge type is legal**, named in a
  confirmation prompt. Costs no new machinery. Rejected under "the gesture is
  the result": drag the other way.
- **Legality as "adding this edge introduces no new error"** — add the edge
  speculatively, run the notation's quality checks, compare. One rule subsuming
  bounds *and* graph criteria, and it can never diverge from the diagnostics
  because it *is* the diagnostics. Rejected on cost: a full quality pass per
  hovered node on every `mousemove`. The diagrams are probably small enough, and
  "probably" is the kind of claim that only fails on somebody else's document.
- **Hover handles on the node rim.** Would keep bare drag unspent and give edge
  ends a matching affordance. Rejected while layout stays engine-owned; revisit
  if node positions ever become editable.
- **A single-target `connect` registered alongside the gesture one**, so the
  menu keeps a path. Rejected: the same operation twice, with two `isEnabled`
  guards to keep in agreement.
- **HTML5 drag-and-drop.** The browser draws its own ghost image, `dataTransfer`
  buys nothing when both ends are in one document, and the events would still
  have to ride the same seam.
- **Menu-first phasing** — ship "Connect to…" as a list before the gesture.
  Rejected as a fiction: on a real document that list is every legal
  destination, unsearchable, and labelled with sentences.

## Consequences

- **The press-and-drag gesture is spent.** If node positions ever become
  user-editable, drag-to-move must displace this or take a modifier. That is the
  bet: that layout stays the engine's job.
- **The registry stops being the whole extension point.** Every earlier command
  is discoverable through `availableCommands(forTargetId:)`, so an adapter
  renders the menu without knowing what any command *is*. A gesture has no single
  id, so every adapter must know `connect` by name. From here, "add a command"
  can mean "add a command and teach each adapter" — promoted to a decision in
  [0013](./0013-driving-ports-and-named-commands.md).
- **The renderer is untouched.** The whole gesture lives in the overlay and the
  App layer.
- **The gesture reads bounds, not criteria.** A bound is an attribute the
  candidate query can read; a `QualityCheck` is an opaque
  `(VGraph) -> [MessageWithSeverity]` that cannot be asked about a proposed edge.
  So [0011](./0011-bounds-on-edge-and-node-types.md)'s guarantee — that an
  affordance and an analysis can never disagree — holds for bounds only.
  *Revised 2026-09-26 ([0011](./0011-bounds-on-edge-and-node-types.md)):* one
  criterion, `noParallelEdges`, is read by name, so CLD's "at most one link
  between two stocks" no longer turns the line green over a second
  `Stock → Stock` link.
  The gesture does not consult any other check.
- **The diagram jumps after a spatial gesture.** The user acts on position and
  position rearranges. The first thing to revisit if direct manipulation goes
  further; anchoring the source node under the viewport is the cheap mitigation.
- **A drag has states a click does not** — armed, dragging, cancelled — and
  every exit path must clear them.
- **Browser tests carry more of the risk than usual.** The threshold, the hit
  test, the cancel paths and the modifier timing are only observable in a real
  browser.
- **The event model changed under this gesture** (2026-08-18): it is built on
  Pointer Events now, so a finger and a pen perform the same drag. The 4px
  threshold, the states and the hit test are unchanged — but the threshold gained
  a second job, deciding a press-and-hold from a drag. See
  [0018](./0018-selection-and-group-creation.md).
