# 32. Hierarchical notations: a node type is detailed by others

Date: 2026-10-10

## Status

Accepted. Absorbs 0005, which deferred node-type categories: detailing widens
edge types, and C4 no longer needs categories or its enumeration. Amends:

- [0003](./0003-c4-zoom-as-group-fold-state.md): [[Decompose]] is the model act
  that makes a node zoomable, and fold state stays view state.
- [0004](./0004-groupstyle-folded-unfolded.md): a [[Detailed node]] folds into
  its node type's look; `GroupStyle` remains for plain groups.
- [0019](./0019-moving-elements-between-groups.md): a move can now be a
  [[Notation break]], so ⌥ reaches past containment; refusals stay silent.
- [0020](./0020-a-graph-carries-its-group-type-registry.md): group types are for
  plain groups only.
- [0021](./0021-reattaching-an-edge-end.md) and
  [0023](./0023-retyping-an-edge.md): moving an edge's second end onto a detail
  retypes it.
- [0030](./0030-attributes-live-in-a-layered-property-store.md): a detailed
  node's chain is group → its node type.

## Context

A review of the C4 example against c4model.com found that the hierarchy C4 is
built on was not in the model:

- Whether an element could be zoomed into depended on whether it had been
  written as a node or a group. IBS was a group and ATM a node, so giving ATM
  containers meant replacing it with a different kind of object.
- The code level sat *beside* its component, tied to it by an `Implements`
  edge. It was not reached by unfolding, which 0003 promised.
- Only a C4-specific check stopped a Container from sitting at the top level,
  and nothing stopped one sitting inside another Container.
- Edge types are exact `(from, to)` pairs, so C4 enumerated 72 of them
  rather than change core matching for one notation. An edge that a
  decomposition moves to a level nobody listed still turns red.

## Decision

**A node type may name the types its nodes are detailed by.**
`node type: SoftwareSystem [detailedBy: (Container, Database)]`. Other rules:

- A type may be a detail type of several types.
- Detailings never form a cycle, except a type detailed by itself (a
  sub-process, a work package). A longer cycle would give every relationship
  pairs at every level, and no type could stand at the top level.
- A `vnotation` may add detailings to the types it inherits, never remove them.
- Violations are notation errors, reported when the notation installs.

**A [[Detailed node]] is a group that carries a node type.**
`group ibs: SoftwareSystem "Internet Banking System" { … }`. It is the node it
was: the same id, type and attributes, in every layer including views.

- Folded, it is drawn with its node type's current look, not a copy taken when
  it was decomposed.
- It starts folded, so decomposing changes no other view.
- With its last detail gone, it is a plain node again.
- Group types remain for plain groups such as "Big Bank", and no name is both a
  node type and a group type.
- C4's Organisation is such a plain group type, not a node type: it can be
  folded, and folded it shows an «Organisation» face, but it is not an element —
  nothing is detailed by it and no edge ends at it.

**Decompose is a model command, never a side effect of unfolding.** Folding
changes what is shown, not what is true (0029). Decompose:

1. makes the node a detailed node;
2. creates one detail per edge: two for a self-loop, one for a node with no
   edges, each of any detail type that fits;
3. moves each edge to its own detail;
4. rewrites view rules naming `node x` to `group x`;
5. unfolds the node in the active view.

It is a single undo step.

**Detailing widens edge types, one end at a time.**

- A declared edge type keeps exactly one declared pair. It also holds with
  *one* end replaced by a detail type, at any depth: `uses: Person →
  SoftwareSystem` also covers Person → Container and Person → Component.
- These gained pairs are computed when the notation installs and never written
  down.
- A relationship whose ends are both details needs a declared type of its own.
  An edge whose second end moves onto a detail is retyped to that type, keeping
  its label. If none fits, it gets the unknown type and a warning, so Decompose
  never fails.
- A pair that is declared explicitly is not also gained.
- Bounds count every pair of a type.
- A file names the declared type, and only when the pair is ambiguous.

**One rule for placement.** Without ⌥, adding, moving and retyping a node offer
only what the containment check accepts. With ⌥ anything goes, and the check
warns. The check:

- a detailed node holds only its type's detail types; plain groups inside it are
  transparent;
- a type that is only ever a detail stands at the top level only if it details
  itself.

**Storage.**

- Detailings accumulate on the graph's `NotationDefinition`. They add up as
  layers install, where attributes override, so they are not attributes (0030).
- An edge type holds a set of pairs: the declared one and those gained.
- `GroupStructure` records a group as either plain (optionally with a group type)
  or detailed (with a node type), never both.

## Considered options

- **Edges may end at groups**, as Structurizr does with an explicit
  system-level relationship beside the container-level ones. Rejected: edges
  stay between nodes, so folding, bundles and derived edges keep their meaning.
  The cost is listed under Consequences.
- **The original node kept inside the group as its anchor.** Rejected: that is
  two objects for one element, and every check, count and selector would have to
  skip anchors.
- **One detail taking all edges**, split later with Reattach. Rejected: it lumps
  unrelated relationships into one node that then has to be taken apart.
- **Creating details on first unfold.** Rejected: a view action would change the
  model, and the result would depend on which view was open.
- **Gaining pairs at both ends**, so that an edge never changes type. Rejected:
  an edge's type would then depend on how it got where it is, and pairs would
  carry two types at once.
- **Generated variant types**, each linked to its declared type. Rejected:
  every reader of a type (file, bounds, look, menu) would have to translate
  variant to declared type. One type with several pairs needs no translation.
- **One C4 relationship type declaring every same-level pair**, so that C4
  edges never retype. Rejected: a declared type keeps one declared pair, and C4
  accepts the retype.
- **External element types** (ExternalContainer and the like). Rejected: C4 has
  no such kind, because being external is about ownership. External elements
  are coloured per node until an `external` attribute is wanted.
- **Node-type categories**: an abstract node type its members declare, matched
  only when no exact pair does. Deferred earlier as a core change for one
  caller; not needed now: detailing replaces the enumeration, and Database stays
  a type of its own.

## Consequences

- C4 declares about eight relationships instead of 72.
  - `SystemBoundary`, `ContainerBoundary` and `EnterpriseBoundary` go, so files
    using them no longer parse.
  - The External types go, and with them the "external inside the enterprise"
    check.
  - The generic containment check replaces `containerOutsideSystem`.
  - The example's code moves into its component.
- A folded system fed by three edges shows `×3`. The reference context
  diagram's system-level label ("Views account balances and makes payments
  using") has no place in the model.
- Exact-pair edge lookup changes in the core, the change categories were
  deferred to avoid. Every
  existing type becomes a one-pair set, so behaviour is unchanged.
- Groups must accept node attributes. Today attributes target a node, an edge
  or the graph.
- Folding draws a detailed node as its node type, so code that recognises a fold
  proxy by its `FoldedGroup` type has to recognise this one too.
- The editor marks a folded detailed node as having details; exported SVGs do
  not.
- Still open: diagram kinds derived as views, description and technology on
  elements and edges, an `external` attribute, and summary labels on bundles.
