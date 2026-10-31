# 19. Moving elements between groups

Date: 2026-08-16

## Status

Accepted. Adds one query and one command to the diagram pane's port from
[0013](./0013-driving-ports-and-named-commands.md). Narrows
[0012](./0012-drag-to-connect.md)'s cancel-on-empty-canvas, and takes the
[[Selection]] of [0018](./0018-selection-and-group-creation.md) as its cargo.
Amended by [0032](./0032-hierarchical-notations-via-detailing.md): containment
is a notation rule, so ⌥ now reaches past it.

## Context

[0018](./0018-selection-and-group-creation.md) made a group out of elements that
had none. It left the other half untouched: an element's group, once set, can only
be changed by editing the text.

The obvious shape is dragging — into a boundary to join it, out of one to leave.
It asks for four gestures (node in, node out, group in, group out) and runs
straight into the fact that **there is no pointer gesture left to spend**. Bare
drag from a node is `connect` (0012); bare drag from the canvas or a group's
interior is the [[Rubber band]] (0018); ⇧-drag extends it; ⌥ is the
[[Notation break]] key, read continuously mid-drag; ⌘ is unsafe, since URL badges
are real `<a>` elements and the undo chords live there; Ctrl-click is
`contextmenu` on macOS. Both earlier ADRs recorded spending the gesture, 0018 in
as many words: "the rubber band spends the last free pointer gesture".

Two facts made it buildable anyway.

- **The drop side is untouched.** A connect drag released on blank canvas returns
  silently, and an edge cannot end on a group at all (`edgeEndpointIsGroup`), so
  releasing on one does nothing. Two unclaimed outcomes on a gesture that already
  exists.
- **A group's label is already a stamped hit target** (`SVGElementId.groupLabelClass`),
  minted for 0009's [[Inline edit]].

## Decision

**One command, reached by one gesture, told apart by where it is dropped.**

### Four operations are one

```swift
func moveDestinations(for ids: [String]) -> [String]
func move(_ ids: [String], into groupId: String) throws(VError)
```

- **"Inside" and "outside" are the same move.** The canvas *is* the
  [[Root group]] ([0016](./0016-canvas-is-the-root-group.md)), so "drag it out" is
  "move it into the root", and at any depth the hit test already resolves the
  enclosing boundary. Out is not a direction; it is a different destination.
- **Nodes and groups are the same cargo.** The [[Effective selection]] already
  holds both and `addTo` has an overload for each.

Four commands would have meant four availability rules, four rows and four sets
of tests for one question — which group does this element sit in — and would have
re-created the root-as-special-case that cost 0018 three bugs.

### The drop target picks the command

> Dropped on a **node** → `connect`, unchanged. Dropped on a **group or blank
> canvas** → `move` into it.

No modifier is spent and nothing shipped is displaced, which matters because
there was nothing left to spend. The two outcomes this claims were both silent
no-ops.

- **Grab a node anywhere on it**, as `connect` already allows. **Grab a group by
  its label** — its interior belongs to the rubber band and must stay there, or
  band-selecting inside a boundary becomes impossible. The label is the only
  candidate the renderer already stamps.
- **The label is also the drop target for moving *into* a group.** A useful
  boundary is wall-to-wall children, and dropping on a child means `connect`, so
  without this the destination is unreachable in exactly the diagrams that need
  it. One piece of chrome, one meaning: *the group itself, as against its
  contents*. It carries three gestures now — click selects, double-click renames,
  drag moves — which is one more than anything else in the editor.
- **What moves** is the effective selection when the grabbed element is covered by
  it, and otherwise just what was grabbed — 0018's right-click rule, reused
  rather than restated.

### Feedback is a wash, and silence means no

- **The receiving group is tinted**, not outlined. `connect` is a line between two
  points and draws a line; move is about ending up inside a volume, and filling
  the volume says so. It also avoids a stroke palette with nothing left in it:
  green is a legal connect drop, red an illegal one, violet the selection, and the
  renderer owns blue for hover.
- **The ghost line stops** once the pointer is over a group. The two feedbacks are
  alternatives; drawing a green "you may connect" line over a boundary would lie.
- **The root group washes the canvas.** *(Added while building, after an
  ADR-0012 test failed.)* It draws no element of its own, so with the wash going
  only on rendered groups, hovering blank space showed nothing and move-out was
  invisible. The canvas carries it instead, which is what the canvas *is*
  ([0016](./0016-canvas-is-the-root-group.md)) — and since it appears only when
  the move would do something, it doubles as "releasing here takes this out of
  its boundary". Dragging an element that is already at the top level leaves the
  canvas plain, correctly promising nothing.
- **No red, and ⌥ does nothing.** `connect` shows red because it is teaching a
  notation rule the user cannot see. Move's refusals are structural and
  self-evident — a box cannot go inside itself, a thing is already where it is —
  so the legal destination highlights and everything else stays silent. There is
  no break to reach for, as with `addNode`.

### What it refuses

All structural, none a [[Notation break]]:

- **A group into itself or its own descendant.** `GroupStructure.addTo(group:childGroup:)`
  has no cycle check today and `isParent` recurses, so this is a new guard and a
  test that the recursion is gone. Grouping never met it, a new group having no
  descendants; moving meets it immediately.
- **Into the group it already occupies** — unavailable rather than a no-op, so it
  cannot burn an undo step doing nothing.
- **The root group itself**, which has no outside, exactly as it cannot be folded
  or deleted.
- **Edges**, which are neither dragged nor moved: an edge's group is derived from
  its endpoints ([0017](./0017-an-edges-group-is-derived.md)).

**Emptying a group deletes it**, cascading, the same rule `delete` follows
(0018) — chosen over exempting `move` so that one rule stays one rule. The cost
is real and accepted: drag the last node out of a boundary and the boundary goes,
so it cannot be dragged back in without an undo.

**Dropping into a folded group leaves it folded.** *Reversed in OLD-201, with
`addNode` (0016):* folding is the author's alone, so a move does not unfold. One
command is one [[Snapshot]] whatever the size of the set.

**The moved elements stay selected**, and no inline edit opens — nothing was
created, so there is nothing to name.

### Gesture only

No menu row and no toolbar button, so — like `connect` — nothing announces it and
every adapter must implement it by name (0013's stated tax).

This was decided against a `Move into…` row, and the argument for one is better
than it was for `connect`: 0012 rejected `Connect to…` because its destinations
are **nodes** and a real document has hundreds, whereas move's destinations are
**groups** and a real document has a handful. `moveDestinations(for:)` survives
regardless, driving the drag's highlighting, so the row would have cost little.
It is deferred rather than refused.

### Blank canvas stops meaning "cancel"

0012 decided that "Escape, `mouseup` on empty canvas, and the pointer leaving the
window all cancel". The middle one now moves the dragged elements to the top
level. **Narrowed deliberately**, and stated here so it is not discovered as a
regression:

- Escape and the pointer leaving the window still cancel, untouched.
- For a top-level element the release is a no-op anyway, since it is already in
  the root and moving into your current group is unavailable — so on a flat
  diagram nothing changes at all.
- Cancelling a move is dropping it back where it came from, which is the same
  refusal and therefore does nothing. That only holds on the group's chrome: drop
  back onto a *sibling node* and it is a connect attempt, because the drop target
  always picks the command.

## Considered alternatives

- **A modifier for move**, leaving bare drag to `connect`. There is no safe one
  left; that is the whole context above.
- **Displacing `connect` to a modifier** so bare drag becomes move. Honest, and it
  breaks a shipped gesture to solve a problem the drop target solves for free.
- **Dragging only a *selected* element moves it**, an unselected one connects.
  Disambiguates without a modifier and was rejected outright: since a click
  selects, elements are selected most of the time, so `connect` would break
  constantly and the same pixel would mean two things depending on invisible
  state.
- **Falling back from an illegal `connect` to a move into that node's group.**
  Makes the gesture's meaning depend on the notation — drag Concept onto Concept
  and it moves, onto Relation and it connects — and fires the fallback exactly
  when the user attempted something illegal, silently turning a mistake into a
  different edit. The mirror of what 0012 refused under "the gesture is the
  result".
- **A group's border as the drag handle.** A few pixels wide, fighting the
  interior for the hit test.
- **Any interior point when the group is already selected.** Costs no new handle
  and makes one pixel mean two things depending on state — and would remove
  band-selection inside a boundary precisely after clicking that boundary.
- **Exempting `move` from the empty-group cleanup**, so a boundary survives having
  its last child dragged out. Attractive because the label is a drop target, which
  makes an empty group a usable destination rather than litter — you could drag
  the node straight back. Rejected to keep one rule; revisit if the deletion
  proves annoying in practice.
- **Four separate commands**, one per operation as originally framed.

## Consequences

- **`connect` gains a way to fail that is not a no-op.** Releasing over a group
  used to do nothing and now edits the graph. The abort is Escape.
- **One ADR-0012 test changed meaning.** "Leaving the diagram leaves the line red
  rather than ending the drag" asserted that blank canvas is an illegal drop. It
  is now a legal one, so the red would have been a lie; the test asserts instead
  that the line gives way, the drag stays armed, and coming back over a node
  restores it.
- **The label is overloaded threefold.** Click, double-click and drag all live on
  the same small strip, and the drag threshold is the only thing separating the
  last two.
- **A cycle guard arrives late.** The model has allowed a cyclic group tree since
  it was written; nothing could reach it until now. The guard belongs in the
  domain, not the adapter, since the adapter is not the only caller.
- **Browser tests carry it, again.** Which of two commands a drop runs, the label
  hit target, and the wash are only observable in a real browser — and 0018's
  two worst defects were both found there.
- **Layout still jumps.** Graphviz re-lays out after the move, so the element
  lands where the engine puts it inside its new group. 0012's note, unchanged.
