# 18. Selecting several elements, and making a group of them

Date: 2026-08-16

## Status

Accepted. Adds one query and two commands to the diagram pane's port from
[0013](./0013-driving-ports-and-named-commands.md). Sharpens the chrome rule of
[0009](./0009-inline-label-editing.md) rather than excepting it, spends a gesture
[0012](./0012-drag-to-connect.md) left free, and relies throughout on
[0016](./0016-canvas-is-the-root-group.md)'s root group and
[0017](./0017-an-edges-group-is-derived.md)'s derived edge membership.

## Context

Every editing gesture so far names **one** element, or two in a fixed order. A
right-click resolves one id, a double-click resolves one id, a drag resolves a
source and a target. Nothing survives the release of the mouse button.

Grouping cannot be built that way. "Put these five things in a boundary" needs
the five to be nameable at once, which means the editor has to hold something it
has never held: state about what the user is attending to.

Two facts made the shape of that state the first question rather than a detail.

- **"Selection" already means something else here, and that one is document
  state.** A `view` section is planned for VGL, after the graph body, naming the
  elements a view shows and the fold state it shows them in. That selection is
  authored deliberately, belongs in [[History]], and is the natural driver of the
  `Select Subset` stage the display pipeline reserves.
- **A document change is loud.** `documentChanged()` re-exports the VGL, re-seeds
  the text pane, repaints the highlight and re-runs Graphviz. Anything held in
  the document is paid for at that price on every change.

## Decision

**What the user gathers with the pointer is not what a view stores. It is
adapter state, and the document never hears about it.**

### The selection lives in `EditorCore`

A `Selection` value type beside `menu(for:in:)`, held by the adapter and passed
into a command as an explicit `[String]`.

Not on `GraphSession`, and the deciding argument is [[History]]. Held in the
session, "a selection is never an undo step" would be a rule in a comment;
held outside it, the session cannot record what it is never told. And a
selection *in* the document would relay out the diagram on every click — the
`documentChanged` path above, paid per click.

Not loose in the WASM editor either. Every rule here — what a rubber band
catches, what promotes, what survives a reparse — is then observable only in a
browser, and `EditorCore` exists precisely so the diagram pane's decisions can be
unit-tested. Selection logic is the second thing to move in, after the menu.

### The effective selection is derived, and the domain computes it

A command never receives the raw selection. It receives the **effective
selection**: complete groups collapsed upward.

> A group with at least one direct child, every one of which is in the set, is
> replaced by itself; anything with an ancestor in the set is dropped; repeat to
> a fixpoint.

- **Derived, never stored.** ⇧-clicking a group's last member promotes to the
  group; ⇧-clicking that member again removes it from the selection and the group
  falls back to its parts. Written back into the selection instead, the second
  ⇧-click would have nothing to remove and the toggle would be a one-way door.
- **It is what the diagram highlights**, because it is what the command will act
  on and anything else misreports the outcome.
- **It earns geometry it cannot get otherwise.** A group's rect is its children's
  box plus padding and a label band, so a rubber band drawn round every node in a
  boundary need not enclose the boundary. The members promote it where
  containment would have missed.
- **The rule is "all direct children", not "the same leaves".** A group holding a
  node and an empty subgroup does *not* promote when only the node is selected —
  leaf-coverage would say it does, and would sweep the untouched subgroup into
  the next command. Empty groups then need no carve-out: having no children,
  they never promote.

**The domain computes it, as `outermostElements(of:)`.** Described without the
word "selection" it is a canonical form over the group tree, not a UI
convention — so it can live in the domain without the core acquiring a belief
about pointing devices. Costing one port member rather than the two that
`parentGroup(of:)` and `directContents(of:)` would have cost, it also keeps
[0013](./0013-driving-ports-and-named-commands.md)'s "precise questions in place
of the graph itself" intact: the pane still cannot walk the group tree.

**Promotion stops below the [[Root group]].** *(Reversed 2026-08-16, in the
browser — see below.)* A set of every top-level element collapses to those
elements, not to the root.

The original decision was the opposite, and it was the most attractive idea in
this ADR: the root is an ordinary group ([0016](./0016-canvas-is-the-root-group.md)),
so "you selected the whole diagram" is the honest answer, and the editor could
handle the root at its edges. It cost three bugs before the pattern was visible:

- **`addGroup` greyed itself** whenever everything was selected. Defensible — a
  diagram has no outside to be wrapped in — and useless: on a two-node diagram,
  selecting both nodes *is* selecting everything, so the button was dead in the
  commonest case there is.
- **The halo vanished**, since the renderer draws no element carrying the root's
  id, needing a display fallback that painted the literal selection instead.
- **A right-click on the only node in a diagram opened the canvas menu**, because
  that one node promoted to the root and the menu was built for the root group.
  Playwright caught this one; the first two were caught by hand.

Each was patched separately before the common cause was admitted. The rule that
dissolves all three: **the root is the one group that cannot be pointed at** — a
click on blank canvas clears the selection rather than selecting the diagram — so
it has no business in a set the user assembled by pointing. Every fallback,
including `groupMembers(for:)`'s and the highlight's, exists only for a selection
that names the root outright, which no gesture can produce.

Selecting everything and grouping it therefore works by ordinary means: the
members are the root's children, the new group is their parent's child, and
`group g "…" { everything }` is ordinary VGL rather than a special case.

### The gestures

| gesture | meaning |
|---|---|
| drag from blank canvas or a group's interior | rubber band, **replaces** the selection |
| ⇧-drag from anywhere, including over a node | rubber band, **adds** to the selection |
| click an element | select just it |
| ⇧-click an element | toggle it in or out |
| click blank canvas, or Escape | clear |

⇧ consistently means *extend*, never *enable*. A bare drag from a **node** stays
[0012](./0012-drag-to-connect.md)'s connect gesture, untouched; the rest of the
canvas was free because 0016 deliberately kept the miss-to-root mapping out of
`elementId(under:)` so that gesture handlers would still see a miss.

- **A click is a `mousedown`/`mouseup` pair that never crossed the 4px
  threshold** — 0012's existing jitter tolerance, reused. Pressing on a node,
  dragging to empty space and releasing is a cancelled connect drag, not a click
  on blank canvas, and leaves the selection alone. Double-click still reaches the
  [[Inline edit]]: the first click selects, the second opens it.
- **The band catches only what is drawn as a single box** — nodes and *folded*
  groups. An unfolded group is never caught geometrically; it arrives only by
  promotion. Overlap-testing a boundary would select the whole thing the moment a
  drag began inside it, which is where dragging is most needed. That this follows
  [[Fold state]] is 0003 doing its job: a folded group *is* one thing at this
  zoom.
- **Contained, not touched.** The usual argument for touch-selection is targets
  that cannot be enclosed — thin lines, huge shapes — and neither exists here.

### Right-click has one rule

> Ensure the pointed element is covered by the selection, then build the menu
> from the effective selection.

Already covered: nothing changes. Not covered: the selection is *replaced* by
that element — what a plain click does anyway — and the menu is the one-element
case, which is today's menu plus the group row. Blank canvas clears and shows the
root menu, unchanged.

**"Covered" means "this element or any of its ancestors is in the effective
selection", not "is in it".** Right-clicking a node inside a fully promoted group
must not clear the promotion and reselect the bare node.

### The highlight lives inside the SVG

A class stamped on the selected `<g>`, re-applied after each render — which
sharpens [0009](./0009-inline-label-editing.md) rather than excepting it. That
ADR is cited for "interaction chrome lives outside the SVG"; what it argues is
narrower:

> Chrome holding **uncommitted state** lives outside the SVG, because a render
> destroys it and the user loses something unrecoverable. Chrome that is a **pure
> function of adapter state** may live inside, because a render only means
> deriving it again.

A selection highlight holds nothing — the state is the `Selection` value. And
outside is the *worse* place for it, for the reason 0009 gives when rejecting a
re-anchored overlay: a long-lived overlay must chase scroll, resize and relayout,
which is the stale-overlay bug class 0009 eliminated by making overlays
short-lived. A class inside the SVG moves with the diagram because it is the
diagram.

**A halo (`filter: drop-shadow`), never a stroke override.** Strokes are spoken
for: 0012 spends red on notation breaks and green on legal drop targets, and the
renderer's own colours carry notation meaning.

**Violet, and `!important`.** *(Amended 2026-08-16, in the browser.)* Checking
the notation colours was not enough — the renderer's hover styles already own
both channels this needs. `SVGBuilder` dims every non-hovered node to
`opacity: 0.15` and glows the hovered one in `rgba(59,130,246)`, so with the
pointer anywhere over the diagram the halo was both faded out and near-identical
in colour to a hover cue on an element that was *not* selected. Selection is
standing state and hover is transient, so selection wins the cascade outright,
and says so in a colour hover does not speak.

### Lifetime

Held by id, so it survives a render, a text edit and an undo, pruned of ids that
no longer resolve; cleared on document load. Pruning is lazy — at paint time and
at command time — which is safe because a parse failure is non-destructive, so
the session always answers `kind(of:)` against a valid graph even mid-edit.

**A selection does not survive its own undo.** Group five nodes and press ⌘Z: the
group goes, the selection prunes to empty, and the five are not restored to
selected. Restoring them would mean the selection had been in [[History]].

**After `addGroup`, the new group is selected and its label opens in an
[[Inline edit]]** — 0016's `addNode` path unchanged, including 0009's ordering
rule that the editor opens *after* the render.

### Two group commands, and a title that states the cost

```swift
func groupingTarget(for ids: [String]) -> VGroupingTarget?
func addGroup(containing ids: [String]) throws(VError) -> String?
func addGroup(moving ids: [String]) throws(VError) -> String?
```

A node has exactly one parent group and Graphviz clusters are strictly nested, so
a new group cannot overlap an existing one — members of another group must
*leave* it. `containing` refuses that and throws; `moving` permits it. The pair
follows `split(_:with:)`/`split(_:ofType:)` and
`addSuccessor(from:using:)`/`addSuccessor(from:ofType:)`.

`groupingTarget` answers the greying, the destination and the title from one
call, so the row and the command cannot disagree — the invariant
`MenuAgreesWithExecutionTest` exists for. It carries the parent id and how many
elements would be detached, and the menu row says so: **"Group"**, or
**"Group (moves 2 out of their boundaries)"**.

**It does *not* report emptied groups, because grouping cannot empty one.** That
was decided the other way and reversed while writing the tests. A group is
emptied only if every direct child moves; every child moving means every child
was chosen; and every child chosen is exactly the promotion condition — so the
group itself becomes the member and its children drop out of the set. The
promotion always arrives one level ahead of the damage. `AddingGroupTests`
asserts both halves, and asserts the graph-level statement too: after any
grouping, every surviving group still holds something.

**No dialog, and no ⌥.** The codebase has no confirmation dialogs and needs none
here: one command is one [[Snapshot]], so ⌘Z restores everything. And no notation
forbids this, so reaching for the [[Notation break]] key would be a category
error.

**Edges need no handling at all.** [0017](./0017-an-edges-group-is-derived.md)
made an edge's group the innermost one holding both its ends, computed on demand,
so an edge between two moved nodes is already inside the new group and one
crossing it already resolves to the ancestor.

**The group is created untyped.** No `groupTypes()` query exists anywhere — a
notation registers group types into the attribute store with no way to enumerate
them back — so offering a boundary kind is a larger job than this feature.

> Since resolved by [0020](./0020-a-graph-carries-its-group-type-registry.md): a
> graph remembers its registered group types, and `changeType` gives a group its
> boundary kind. `addGroup` still creates an untyped group — the type is set as a
> second step, not at birth.

### Emptying a group deletes it — a rule about commands, not about graphs

A command that removes a group's last child removes that group too, cascading
upward, stopping at the root, in the same snapshot. This changes shipped
behaviour: `delete` leaves empty groups standing today.

**`delete` is the only command this reaches.** It was written expecting to cover
grouping as well; grouping turned out to be unable to empty anything (above), so
what survives is a rule for deletion — which is where the case is real, since
deleting a boundary's last node is an ordinary thing to do.

**Deliberately not an invariant on `VGraph`.** Were it one, parsing
`group foo "Foo" { }` would have to drop it, the document would change on load,
and export→reparse would lose a group its author wrote on purpose — breaking the
round-trip rule everything else rests on. A hand-written empty group is left
alone; one a command empties is removed by that command.

### A toolbar button, for its disabled state

"Group" joins the toolbar beside "＋ Node", greyed until the effective selection
can be grouped. The button matters less than the greying: a control that lights
up when you select two things is the only thing in this design that tells a user
selection exists. It means the toolbar holds the diagram pane's port, which 0013
anticipates in the other direction ("a pane that wants ⌘Z holds that port too").

## Considered alternatives

- **Selection as a transient part of the grouping gesture**, evaporating after
  the command. Rejected: once it is visible on screen it *is* standing state to
  the user, whatever the code says, and a highlight that survives one command but
  not another reads as a bug.
- **Selection on `GraphSession`.** Every adapter gets it free. Rejected on the
  History argument above.
- **Selection in the document, as the view's own.** The two are genuinely
  related — a selection is how one would *author* a view's contents, exactly as
  an [[Inline edit]] authors a label — but conflating them makes every click a
  document change: an undo step, a textarea rewrite, and a full relayout under
  the pointer. A "selection run" coalescing rule after
  [[Text-edit run]] would make it survivable, and would be machinery invented to
  rescue a conflation.
- **`parentGroup(of:)` + `directContents(of:)`, with the promotion rule in
  `EditorCore`.** Argued for on the grounds that promotion is a UI convention.
  Reversed once the operation was named without the word "selection": it is a
  canonical form over the group tree, so it is the domain's, and it costs one
  port member instead of two.
- **Refusing to return the root group from `outermostElements`.** Rejected as
  reintroducing root-as-exception in the one layer 0016 made it ordinary in — and
  it hides the answer where the adapter cannot explain it.
- **A selection overlay outside the SVG.** Literal compliance with 0009's usual
  paraphrase, and the worse engineering: it must chase scroll, resize, splitter
  drags and every relayout.
- **A stroke override rather than a halo.** Simpler CSS, and it clobbers colours
  that carry notation meaning.
- **Touched rather than contained** for the band. Forgiving, and it selects
  whatever a band brushes past on its way somewhere — the commoner event in a
  dense diagram. A one-line predicate, so cheap to revisit in the browser.
- **A single `addGroup` that reparents freely.** Not a richer version of the
  strict one but a different command: it restructures boundaries the user never
  touched, and the result cannot be drawn as the rectangle they dragged, because
  the new box would have to cross an existing cluster.
- **A confirmation dialog for the reparenting case.** A new interaction primitive
  for a fully undoable operation.
- **⌘A and a Delete binding.** ⌘A must fight the textarea for the same chord, and
  the keydown handler catches events bubbling from it. "Delete the selection" is
  a command rather than a binding, and is the obvious next one.

## Consequences

- **`delete`'s behaviour changes.** Deleting the last node of a boundary now
  removes the boundary. Small, shipped, and worth a test of its own.
- **`EditorCore` starts answering about sets, not only elements.**
  `menu(for:in:)` gains a selection-aware sibling and `GoldenMenuTest`'s table
  gains a dimension. The one-element case must reproduce today's rows exactly,
  plus the group row — an assertion, not a hope.
- **The port grows by three**, so `ArchitectureTest`'s table of the three actors
  grows too. The tax 0013 set.
- **The rubber band spends the last free pointer gesture.** With bare drag on a
  node taken by connect and bare drag elsewhere taken here, a future
  drag-to-move has nothing left but a modifier.
- **A one-member group cannot be told apart from its member** through the
  selection. Harmless for grouping, where both readings are a degenerate
  single-child nesting; it will matter for deleting, where node and group are
  different outcomes. The menu still resolves the pointed element, so the member
  stays directly reachable.
- **Browser tests carry the usual disproportionate share**, and this feature
  proved it twice over. The threshold, the hit test, the promotion feedback and
  the halo are only observable in a real browser — 0012's warning, unchanged. But
  the two worst defects here were in the *existing* suite rather than a missing
  one: a right-click on the only node opened the canvas menu, and a right-click
  on an edge opened nothing at all, both caught by `commands.spec.js` and neither
  by 1300 Swift tests. `selection.spec.js` now covers the new gestures, with a
  regression test for each.
- **An edge cannot be selected**, so it takes the single-element menu path, as
  blank canvas does. Its group is derived from its endpoints
  ([0017](./0017-an-edges-group-is-derived.md)), leaving a set command nothing to
  do with one.
- **Touch is partly addressed** (amended 2026-08-18). The editor's input is now
  Pointer Events rather than mouse events, so a finger and a pen drive the same
  handlers a mouse does. Safari's compatibility mouse events were never going to
  work: they report `buttons: 0`, which the "released somewhere we never saw"
  guards in `handleDragMove` and `moveBand` read as a lost drag and cancel on the
  spot. Three things had to follow from the swap:
  - **No `setPointerCapture`.** Capture retargets later events to the capturing
    element, and `event.target` *is* the hit test (`elementId(under:)`). For the
    same reason `handleDragArm` *releases* the implicit capture a touch pointer
    gets automatically, which otherwise pins every drag to where it started.
  - **`mouseleave`-cancels became `pointercancel`-cancels.** Leave-cancels existed
    for a drag ending outside the window; `pointercancel` is what actually means
    the browser has taken the gesture, which is how a drag is lost on touch.
  - **Press-and-hold opens the context menu**, since right-click was the only
    route to a command. The timer borrows the host's clock through a named `@JS`
    export (`__vgraphLongPress`), because a Swift `JSClosure` cannot fire in this
    embedded build; a host that does not bind it simply has no long press. The
    element is re-hit-tested when the timer fires rather than captured at
    `pointerdown` — the 400 ms render debounce can swap the preview out from
    under a 500 ms hold.
- **What touch gave up, and what it still cannot reach.** A finger drag on blank
  canvas pans the preview instead of banding: `touch-action` is the only thing
  that can stop touch scrolling, and it is set per-surface — the preview pans, and
  `.vgraph-node` / `.vgraph-group-label` opt out so a press on one drags it. The
  [[Rubber band]] is armed by exactly the gesture now spent on panning, so **on
  touch** it has none left; tap still selects, and the band's ⇧-additive mode
  needed a keyboard regardless. **The mouse band is untouched** — `touch-action`
  governs touch input only and is inert for a mouse, so the desktop gesture is
  bit-for-bit what it was, which `selection.spec.js` still proves. Reaching a band
  by finger wants a mode, not another gesture: the pointer vocabulary was spent
  before touch arrived. Still mouse-or-keyboard only: **⇧** (extend a selection, force a
  band), **⌥** (permit a notation break, force the type choice), **hover** (the
  renderer's spotlight, the diagnostics tooltip), and **double-click** to inline-
  edit, where a double-tap would fight Safari's zoom. Undo/redo are toolbar
  buttons already, so Cmd-Z is a convenience rather than a gap.
