# 16. The canvas is the root group

Date: 2026-08-15

## Status

Accepted. Adds one command and one query to the diagram pane's port from
[0013](./0013-driving-ports-and-named-commands.md).

## Context

Every node is born attached: `addSuccessor` and `addPredecessor` hang one off an
existing node, `split` inserts one into an existing edge, and all three derive
the new node's type from a candidate *edge type* — so the notation decides the
relationship and the node follows from its far end. That leaves no way to create
a node that stands alone, and no way to create the first one.

The obvious shape — "right-click the blank canvas" — runs into the fact that
every other command is reached by *pointing at something*. `handleContextMenu`
walks `closest` up to a node, edge or group `<g>`; `EditorCore.menu(for:)` starts
from an element id. Blank canvas names nothing.

Four facts decided what "nothing" should name:

- **The model already says the graph is a group.** `rootGroup` is a real `Group`:
  the parser puts every top-level node and group under it, layout applies to it,
  and graph-level attributes are *stored* on it (`set(graphAttribute:)` is
  `setAttribute(target: rootGroup, …)`). The only place it is hidden is
  `VGraph.groups`, which filters it out of the public list.
- **It is already a legal command target.** `GroupStructure.init` seeds
  `groupSet` with the root, so `resolveCommandTarget(id:)` already returns
  `.group(root)`. It is unreachable only because the renderer draws no element
  carrying its id.
- **Which means the hole is already open.** `delete(root)` and
  `toggleFolding(root)` are callable on the port today and do something nobody
  has defined.
- **Pointing inside a boundary already resolves to that group**, since an
  unfolded group's rect encloses its interior. So "add a node in *this* boundary"
  costs nothing beyond letting the command take a group.

## Decision

**The background is not a fourth kind of thing. It is the root group.**

- **One command, always targeting a group.**
  `addNode(in groupId: String?, ofType type: NodeType) -> String?` joins
  `ForEditAGraphVisually`. `nil` means the root — how a caller with no pointer
  (the toolbar button) says "top level" without learning an internal id. The
  return is the created node's id, or `nil` for a node type that displays no text
  of its own, which is `addingRelated`'s contract, so the inline edit that follows
  needs no new machinery.
- **`rootGroupId()` joins the same port**, and `handleContextMenu` maps a miss to
  it. The mapping is *not* in `elementId(under:)`: three of that helper's four
  callers are gesture handlers, and for a drag, blank space genuinely means
  nothing — mapping in the helper would turn "drop on empty space" from a silent
  no-op into a thrown `commandUnavailable`.
- **The root group is an ordinary target with refusals.** `GraphSession` throws
  `commandUnavailable` for `toggleFolding`, `delete`, `setLabel`, `setURL` and
  `removeURL` on it, and `EditorCore` greys the same rows — the domain refuses and
  the adapter greys, the split [0013](./0013-driving-ports-and-named-commands.md)
  draws. Folding has no outside to collapse into; deleting the diagram is the
  document's business, not the graph's.
- **Adding into a folded group unfolds it, in one snapshot.** The alternative was
  to grey the command out there, but an invisible node with an inline edit
  attached to nothing is worse than a visible relayout. One command is one
  snapshot, so undo removes the node *and* re-folds the group — the honest report
  of what happened.

  **Reversed in OLD-201.** Once a view can fold a group the author did not fold in
  the document, "the group" is no longer one thing to unfold, and an unfold the
  author never asked for puts a layout change in history. Adding or moving into a
  folded group now leaves it folded: folding is the author's alone, in the
  document and in a view alike. The new node is not drawn until the group is
  unfolded, and the editor opens no inline edit on it.
- **It is never unavailable and ⌥ does nothing on it.** Every node type the
  notation declares is offered. An unattached node is an *incomplete* graph, not
  an illegal one: minimum bounds are diagnostics, and the candidate machinery
  consults only `totalMax`. A brand-new node is what every graph looks like
  mid-edit, so there is no notation break to reach for.

## Considered alternatives

- **A fourth `VElementKind` (`.canvas` or `.graph`)**, with the background
  resolving to the `vgraph` id. A new case rippling through every switch for one
  menu row — and the id is not safe: nothing stops a document declaring
  `vgraph foo` and `node foo`, which would make `resolveCommandTarget(id:)`
  ambiguous. The root group's id cannot collide.
- **A separate `EditorCore.canvasMenu(in:)`.** The smallest diff, and the one
  first recommended. Rejected because it denies what the model already says: the
  root group exists, holds the graph's attributes, and resolves as a target
  today. Every later graph-level command would have needed a second home.
- **A sentinel element id (`"__canvas__"`).** Reserved strings in adapters are
  exactly what `breakOption.isBreak` was introduced to avoid.
- **Rendering the root group as a real SVG `<g>`**, so `closest` finds it on a
  miss and the DOM supplies the id — costing zero new port members and stating the
  model most purely. Deferred, not dismissed: it touches `VSVGGroup`/`VSVGGraph`
  and the IR of [0015](./0015-svg-ir-and-elementary-upstreaming.md), and the hover
  CSS is safe only while the root emits no `<rect>` — a constraint the next
  renderer change can break silently. Reconsider the day the root group needs to
  be *drawn*.

## Consequences

- **A specified refusal where there was none.** The root group stops being a
  target that happens to work and becomes one whose behaviour is stated and
  tested.
- **The canvas menu has six greyed rows.** `commands(on: .group)` is shared, so
  the root shows all seven with one live entry. Accepted: filtering waits until
  the root group has a command list of its own worth writing — "rename the
  diagram", "change notation", "add group" are the obvious candidates, and the
  diagram's title *is* the root group's label.
- **Graphviz relayout is part of the deal.** Unfolding moves every node, and a
  node added from the toolbar can land off-screen. The editor calls
  `scrollIntoView()` before opening the inline edit; nothing can be done about the
  jump while layout is Graphviz's.
- **Two port members and a fixture.** `ArchitectureTest`'s table of the three
  actors grows by `addNode` and `rootGroupId` — the tax
  [0013](./0013-driving-ports-and-named-commands.md) set, and the point of it.
- **Keyboard shortcuts are deferred.** They may be a fourth actor rather than a
  second trigger — a question about the ADR-0013 table, not about this command.
- **Starting from nothing is still not possible.** There is no "New" in the file
  menu, so this command extends documents that already exist. New is a
  document-actor feature with its own notation-picker and title questions, and was
  deliberately left out rather than smuggled in.
