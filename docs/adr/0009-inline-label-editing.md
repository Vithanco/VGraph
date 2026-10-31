# 9. Inline label editing

Date: 2026-07-26

## Status

Accepted. Removed the `text` interaction request of the first multi-step
commands, and the label-as-command-step it existed for (see
[0013](./0013-driving-ports-and-named-commands.md)). Amended 2026-08-16 (see
Consequences) — this ADR is widely cited for a rule broader than the one it
made.

## Context

`AddSuccessor` had a two-step conversation: choose the relationship,
then type the new node's label into a text field on the context menu. That second
step is a substitute for editing the text where it actually lives — the diagram
already draws the label, so the user should be able to double-click and type.

Three facts about the rendering path constrain how:

- **Every render replaces the entire SVG**, and renders are debounced 400 ms
  after each keystroke, so anything anchored *inside* the SVG is destroyed
  mid-edit.
- **A label is N separate `<text>` elements**, one per wrapped line. There is no
  single text node to make `contenteditable`.
- **Changing a label changes its wrap, hence the node's size, hence the layout.**
  The element being edited wants to move and resize underneath the cursor.

## Decision

**An HTML input overlaid on the element**, positioned from the rendered
element's `getBoundingClientRect()` and living in the preview container *outside*
the SVG. It survives `innerHTML` replacement because it is not in the replaced
subtree, and it needs no layout-data plumbing — the display pipeline already
stamps `#node-<id>` / `#edge-<id>` / `#group-<id>`.

- **Trigger:** double-click, through the existing `_DOMEventHandlerConfig` seam.
- **Scope:** nodes, edges and groups. A group is editable **only via its label**,
  not its boundary area — a boundary covers other elements, so treating the whole
  cluster as a hit target would be wrong. This requires the renderer to stamp the
  group label with `class="vgraph-group-label"`.
- **Edge anchor:** an unlabelled edge has no `<text>` at all, and unlabelled is
  the normal state, so the anchor is the rendered path's midpoint via
  `getPointAtLength(getTotalLength()/2)` — browser-side, so the engine emits
  nothing extra.
- **Gestures:** Return commits, clicking away commits, Escape cancels, and **any
  re-render closes the editor and discards**. Escape and a render both clear the
  target *before* removing the field, so the blur they cause is a no-op rather
  than a commit.
- **A single candidate skips the menu.** The command always offers the full list;
  the adapter creates directly when only one real candidate is on it. Holding ⌥
  forces the list, which is how the notation break stays reachable — the node-type
  list *behind* "Other type…" is never auto-picked, so a deliberate break is
  always seen.
- **Committing is a `setLabel` command**, so it inherits history, undo and
  text-run sealing, and yields a right-click "Rename" on the same targets for
  free.
- **New nodes carry an explicit `"Change Me"` label**, and an empty commit
  restores it.

## Alternatives considered

- **`<foreignObject>` with `contenteditable`.** The only option genuinely
  *inside* the diagram, panning and zooming for free. Rejected: the engine would
  have to emit it, and every re-render wipes it mid-edit.
- **DOM surgery on the rendered `<text>` elements.** Same re-render problem, and
  line wrapping becomes hand-managed.
- **Re-anchoring the overlay after each render** instead of closing it. Keeps an
  edit alive across renders, but every failure mode of a stale overlay — element
  moved, resized or deleted; commit silently no-oping on a vanished id; the same
  label editable in two places at once — has to be handled. Closing on render
  deletes that entire class of bug for the cost of a discarded edit in a case the
  user has already left.
- **Coalescing create-then-name into one undo step.** Rejected so `setLabel`
  behaves identically regardless of what triggered it.
- **Genuinely empty labels.** The exporter omits an empty label and the parser
  turns an absent label into the element's id, so "empty" becomes `relation_1` on
  the next reparse. Making empty mean empty would change VGL semantics for every
  document.

## Consequences

- **Creating a node and naming it are two undo steps.** One Cmd-Z after adding
  leaves the node with its placeholder; a second removes it. Deliberate — the
  alternative was contextual behaviour in `setLabel`.
- **Fixes a round-trip defect in the first `AddSuccessor`.** A node created
  with no label read `"Change Me"` in memory but `relation_1` after any
  export→reparse, so its visible text changed on the next keystroke. Setting the
  label explicitly at creation restores the round-trip invariant.
- **First time a command feature reaches the renderer.** The
  `vgraph-group-label` stamp is a `VGraphSVG` change. Additive — a new class
  cannot break the plugins — but ADR-0001's "engine untouched, editor additive"
  split bends here, and the next such request should be weighed rather than waved
  through.
- **`displaysLabel` answers only for node types.** Extending `setLabel` to edges
  and groups needs an equivalent for both. Both always accept a label, so the
  answer is trivially yes today; the asymmetry is worth removing rather than
  leaving as a special case.
- **Ordering matters.** A render closes any open editor, so a command that hands
  off to the inline editor must open it *after* its render, not before.
- **The rule here is narrower than the one it gets quoted for.** *(Added
  2026-08-16.)* This ADR is cited — by [0012](./0012-drag-to-connect.md) and by
  `CONTEXT.md` — as "interaction chrome lives outside the SVG". What it actually
  argues is that chrome holding **uncommitted state** must, because a render
  destroys it and the user loses something they cannot get back: typed text, a
  half-made drag. Chrome that is a *pure function* of adapter state loses nothing,
  since a render only means deriving it again — and for that kind, outside is the
  worse place, for the reason this ADR gives when rejecting a re-anchored overlay.
  A long-lived overlay must chase scroll, resize and relayout; a class stamped
  inside the SVG moves with the diagram because it *is* the diagram. Selection
  highlighting is the first case to take the second path.
