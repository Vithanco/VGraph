# 21. Reattaching an edge end

Date: 2026-08-20

## Status

Accepted. Answers the addressing question [0012](./0012-drag-to-connect.md)
deferred, and adds two queries and one command to the diagram pane's port from
[0013](./0013-driving-ports-and-named-commands.md). Reads the bounds of
[0011](./0011-bounds-on-edge-and-node-types.md), and follows
[0019](./0019-moving-elements-between-groups.md)'s pattern of a third meaning on
one drag decided by what is under the pointer.

Moving an edge's second end onto a detail retypes it to the declared type for
the new pair — see [0032](./0032-hierarchical-notations-via-detailing.md).

## Context

`VGraph.reattach(edge:from:to:edgeType:)` has existed since edges did. It moves
an end and carries the label, the comments and `itemOrder` across, which is the
whole reason it is not `delete` plus `connect` — those reach the same shape and
lose what the user wrote. Nothing has ever called it from the UI.

0012 said why: *"an edge end is a **position on** an element, so it cannot ride
the existing id keyspace at all"*. `originId(fromDomId:)` strips one of
`node-`/`edge-`/`group-`, so `edge-foo-head` yields the origin id `foo-head`,
indistinguishable from a node genuinely called that.

Three facts found while designing this, each of which moved the answer:

- **The drawn mark does not name an end.** Concept Map's `conceptToRelation` sets
  `dir=back`, `arrowHead=none`, `arrowTail=dot` — a dot at the tail and nothing at
  the head. "Drag the arrowhead" names no end reliably, and a notation may draw
  nothing at either.
- **The bounds must be read against a smaller graph.** `connectCandidates`
  counts the graph as it stands, including the edge in the user's hand. Under
  `samePairMax: 1`, moving `A→B`'s head would be refused because `A→B` still
  occupies the budget it is about to vacate. Since maxima are advisory —
  `add(edge:)` does not enforce them, only the candidate queries read them — the
  query is the only place this can be got right.
- **A class inside the SVG is already permitted.** 0012 said the whole gesture
  lives in the overlay; 0019's `paintDropTarget` then stamped `vg-drop-target` on
  a group's `<g>`. It is safe because a render cancels the drag and rebuilds the
  SVG, so the class cannot outlive what it points at. The rule as practised is
  *no persistent state inside the SVG*, not *nothing changes*.

## Decision

**An edge end is chrome that names a pair, and dragging it is a gesture.**

### The handle, and what it is not

```
<g id="edge-e1" class="vgraph-edge">
  <path d="…"/>
  <polygon points="…"/>                          the notation's own mark
  <circle class="vgraph-edge-end" data-edge="e1" data-end="to" r="7"/>
</g>
```

- **No id, and no place in the origin-id keyspace.** The handle carries its edge
  and its side as data, so `originId(fromDomId:)` keeps its promise that a stamped
  id names a graph element — which an edge end is not. Same shape as the URL
  badge, which `handleDoubleClick` already tests for with `closest` before the
  normal hit walk. 0012's blocker is not solved; it is declined.
- **Both ends carry one**, independent of what the notation draws there, because
  the mark is decoration and the end is the thing. `reattach`'s two optional
  parameters were already built for this.
- **The handle sits inside the edge's `<g>`**, so a right-click on it walks up to
  the edge and opens the edge's menu with no extra code.

### It appears on hover, which spends nothing

One static rule, shipped inside the SVG:

```css
.vgraph-edge-end { opacity: 0; pointer-events: none; }
.vgraph-edge:hover .vgraph-edge-end { opacity: 1; pointer-events: auto; }
```

- **The node rim is not stolen.** Graphviz clips the spline to the node's
  boundary, so a handle overlaps node pixels — and a drag from there is `connect`.
  Inert-until-hovered means the rim behaves exactly as today except while the
  pointer is on that edge, which is not when anyone is starting a node drag.
- **It is self-sustaining.** The handle is a descendant of the edge, so hovering
  the handle keeps the edge hovered. No `svg:has()`, no per-graph generation, no
  adapter state.
- **A hollow ring** — canvas fill, stroked in the edge's own colour, one circle
  serving as both the ring and the hit target. The grab-handle idiom everywhere
  else, and it borrows the edge's colour so it can never contradict the notation.
  The stroke palette is spent (0019): green is a legal drop, red an illegal one,
  violet the [[Selection]], blue the [[Rubber band]] and the renderer's hover.

### Nothing here is reachable by finger

A finger has no hover, so reattach is mouse and pen only, and there is no menu
row to fall back to — it is gesture-only, as `connect` and `move` are. Stated
plainly rather than discovered: this is the same wall as OLD-118, a
missing **affordance** and not a missing event, and it wants the same answer.

### The queries, asked of a smaller graph

```swift
public enum VEdgeEnd { case from, to }

func reattachTargets(edge: String, end: VEdgeEnd,
                     notationBreak: VNotationBreak) -> [String]
func reattachCandidates(edge: String, end: VEdgeEnd, to nodeId: String) -> [EdgeType]
func reattach(_ edgeId: String, end: VEdgeEnd, to nodeId: String,
              using edge: EdgeType.Id?, notationBreak: VNotationBreak) throws(VError)

/// The node at one end of an edge — added during implementation. A choice
/// prompt reads "source → destination" (`connect`'s convention), and the pane
/// holds only the edge, the side grabbed, and the node dropped on — never the
/// side left untouched. The alternative was hit-testing the drag's own anchor
/// point back to an id, which is what `longPressFired` does for a *stale*
/// element and is not a reason to reach for it where a direct question works.
func node(atEdge edgeId: String, end: VEdgeEnd) -> String?
```

- **The plan's "reuses `connectTargets` wholesale" (OLD-103) was wrong twice**, and both
  corrections are why these are new methods rather than a reuse. `connectTargets`
  answers only *from a fixed source, where may I land* — moving a `from` end asks
  the mirror question, which nothing answers, `connectSources()` returning every
  node unconditionally. And the counts must ignore the edge in hand.
- **The subject is the edge and the end**, not a pair of nodes: that is what lets
  "minus this edge" live in the domain, so the pane still derives no notation rule
  (0013).
- **They cannot disagree with the command**, because `reattach` deletes before it
  adds — the command validates against the same reduced graph the query counted.
  0011's guarantee holding, for bounds as ever and, of the
  [[Graph criterion]]s, for `noParallelEdges` only.
- **One end at a time.** The domain's form takes two optionals and can express a
  flip; the gesture never moves two, and `changeDirection` already owns flipping.
  Two named commands would have been two availability rules and two sets of tests
  for one question — what 0019 refused when it collapsed four move operations into
  one.

### The drag, and what a drop means

- **The ghost line is anchored at the *fixed* end's node**, drawn to the pointer,
  green or red by membership of `reattachTargets` — computed once per drag and
  recomputed when ⌥ changes, exactly as `connect` caches it. The line is a preview
  of the edge that would result, which is why it starts where the edge stays.
- **The edge in hand is dimmed**, by a transient class on `#edge-<id>` cleared by
  `cancelDrag`. Without it the user sees the old edge and the ghost at once, which
  reads as drawing a second edge — the opposite of what the gesture does.
- **⌥ is the [[Notation break]], exactly as in a connect drag**: read
  continuously, it opens every node and asks nothing, minting an unknown edge
  type even over a pair the notation would have joined. The stakes differ — here
  it discards a type the edge already carried — and the symmetry is still worth
  more than the protection, an undo step away. It could not have worked otherwise:
  `add(edge:type:)` throws `edgeTypeNodeTypeMismatch` when a type's declared ends
  do not match the actual node types, so an old type cannot survive an
  unsanctioned pair. The graph refuses to hold it.
- **A drop resolves as `connect`'s does.** No candidate: nothing happens. One:
  silently applied. Several: the existing chooser at the release position.
- **A self-loop is allowed where the notation declares one.** This diverges from
  `connect`, which excludes dropping on the node just grabbed because "landing
  back where the drag started is a slip far more often than an intention". That
  reasoning does not carry: the drag began at a handle on the *far* node's rim.
  CLD declares `Stock → Stock`, and the candidate query already says so.
- **Group, canvas, another edge, or the node the end already occupies: all
  cancel silently.** The reattach branch is taken *before* `moveDestination` in
  `handleDragEnd`, or a drop on a boundary would try to reparent an edge end —
  which an edge does not have, its group being derived
  ([0017](./0017-an-edges-group-is-derived.md)).

### An end drawn on a folded group gets no handle

Folding redirects an edge onto the folded group's box and **keeps its id**
(`FoldingLayoutStep`), so `#edge-e1`'s visible end may be a stand-in for a node
inside. Dragging it off is well defined and does the useful thing — you get
`A→X`, and the box did stand for the hidden node. But a folded group is not a
legal drop target (`edgeEndpointIsGroup`, the rule `connect` already has), so the
end can never be put back by the same gesture. **An end you cannot drop back on
is an end you cannot drag off**, and one type comparison in the renderer against
FoldGroups' synthesized `FoldedGroup` closes the trapdoor. The edge's other
handle is unaffected.

Merging (`MergeRelationsStep`) redirects incoming edges onto a survivor and keeps
each edge's id, so every drawn edge stays 1:1 with an origin edge and the drawn
end is where the reattach lands. Nothing to suppress there.

### Handles are emitted for the editor only

`RenderContext` already exists as *per-render parameters not carried on the
graph*; it gains `interactive: Bool = false`, threaded down from
`renderGraph(graph:sourceVGL:darkMode:)` through `ForRenderAGraph.render` and
`VSVGRenderer`. Every non-editor caller — the CLI, the MCP tool, the Wasm engine
export — reaches the renderer through the *string* form `renderGraph(_:darkMode:)`
and is defaulted to today's behaviour, so **no existing call site changes**, and
`ForEditAGraphVisually.render(darkMode:)` does not change at all.

## Considered alternatives

- **A fourth id prefix**, `edgeend-head-<id>`, parsed by a widened
  `SVGElementId`. Mechanically fine — the string matches none of the three
  existing prefixes, so `originId` already returns `nil` for it. Rejected because
  it puts a non-element into the origin-id keyspace: `SVGElementId`'s promise that
  a stamped id names a graph element stops being true, and every reader has to
  learn which of two parsers to reach for.
- **Geometry with no stamp** — decide from the hit point which end is nearer.
  No renderer change at all, and it puts layout arithmetic in the layer forbidden
  from deriving things, with no affordance and no dependable target size.
- **Grabbing the edge's near half**, no chrome. Costs the [[Rubber band]] its
  start-on-an-edge case, which 0018 explicitly claimed, and shows the user
  nothing.
- **A menu path** — `Reconnect head to…`, or a picking mode ("now click the other
  end") reviving the `VCommandRequest.element` case 0009 left open and 0012
  closed. Both would make this reachable by finger today. Rejected on 0012's
  grounds: on a real document that list is every legal destination, unsearchable
  and labelled with sentences — and here it is one such list per end. Deferred
  with OLD-118's affordance strip rather than refused.
- **Handles only where the notation draws a mark.** The literal reading of the
  plan in OLD-103, and Concept Map alone breaks it: half its edge types would have an
  unreachable head, with no rule a user could infer.
- **Only the `to` end.** Halves the chrome and the rim overlap, and leaves moving
  a source as delete-and-redraw — losing exactly the label and comments `reattach`
  exists to preserve. An asymmetry discovered by failing.
- **Always-live handles, visible or not.** Reachable by finger. Rejected because
  it steals a ring of every node's rim from `connect` permanently, and an
  invisible control is not an affordance.
- **Always-visible handles**, like the URL badge. Discoverable and touch-friendly;
  a forty-edge concept map gains eighty rings.
- **⌥ meaning "break only where a break is needed"**, so a drop on a legal pair
  keeps its type. Protects against a slip. Rejected because ⌥ would then mean two
  things depending on where the pointer was released, which 0012 refused for
  `connect`.
- **Widening the connect queries** with `ignoring: Edge.Id?` and a
  `connectSources(to:)`. Two fewer names on the port; every existing caller gains
  a parameter it passes `nil` to, and `connect` starts meaning two operations.
- **Unfolding a folded group on hover** so it becomes a legal target again.
  Symmetric and trapdoor-free, and it changes the graph mid-drag — which cancels
  the drag by 0012's own rule, so it needs that rule amended first.
- **A second `render` parameter on the pane's port**, `render(darkMode:interactive:)`.
  Rejected once `RenderContext` turned out to be the seam already: the renderer has
  deliberately never known who was asking, and this way it still does not — only
  *what kind of output* was asked for.

## Consequences

- **0012's deferral is discharged by declining its premise.** Edge ends never
  become addressable; they become chrome that names a pair. Anything else wanting
  to point at an edge end — a menu, a [[Selection]] — still has no id to use.
- **The pane now has three hit-test mechanisms**: the origin-id walk, the URL
  badge's class test, and the edge-end handle's. The handle must be tested before
  the walk, since it lives inside an element the walk would otherwise claim.
- **An edge is hovered by a ~1px stroke**, which is fiddly, and a handle that only
  appears on hover inherits that. The fix is a transparent fat hit-path beneath
  each visible one — which would improve the existing hover glow too, so it is
  worth doing for its own sake and not only for this.
- **Two handles on a short spline can overlap**, making the wrong end easier to
  grab than the right one. Wants a clamp; the browser specs are where it will
  show.
- **Reattach is unreachable on an iPad**, and unlike the gestures in
  OLD-118 there is no mouse-only modifier to blame — hover itself is what is missing.
- **The drag threshold now separates three things on an edge**: a click, a press-
  and-hold, and a reattach. It already separated the first two everywhere else.
- **`reattach` is the first command whose subject is not an element.** Its target
  is an edge *and a side*, so `VCommandTarget` cannot express it — which is the
  same shape of problem 0012 hit with `connect` naming two elements, answered the
  same way: gesture-only, known by name in every adapter (0013's stated tax).
- **The relayout jump applies here too**, as 0012 accepted for `connect`: the
  whole diagram re-lays out after the drop, and the end just moved lands somewhere
  else.
