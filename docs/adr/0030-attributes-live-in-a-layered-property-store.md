# 30. Attributes live in a layered property store

Date: 2026-09-27

## Status

Accepted. Supersedes the *two cascades* and *look* parts of
[0029](./0029-one-model-many-views.md). Takes the group type into the attribute
chain, which [0004](./0004-groupstyle-folded-unfolded.md) kept out of it, and
supersedes where [0004](./0004-groupstyle-folded-unfolded.md),
[0020](./0020-a-graph-carries-its-group-type-registry.md) and
[0022](./0022-a-vnotation-carries-its-icons.md) keep the group type, the
group-type registry and declared icons, and the group-to-edge attribute
inheritance [0017](./0017-an-edges-group-is-derived.md) kept.
Requirements: OLD-192. Selector rules build on it: OLD-193.

Note: "Display graph" in this record is now the **view graph**, and the "display" attribute category is **computed**. Rules that set attributes are parked; selectors always run on the origin graph, so their layers need no pipeline step.

A detailed node resolves group → its node type; detailings accumulate on the
notation definition, not in a layer — see
[0032](./0032-hierarchical-notations-via-detailing.md).

## Context

Views (0029) need to override what the model says without changing it. The
attribute store could not support that:

- **The store is flat.** Installing a notation writes its values into the same
  `AttributeStore` that the `vgraph` block later overwrites, so nothing records
  who set a value. The exporter recovers what the author wrote by rebuilding the
  base notation and diffing against it.
- **Groups resolve like Graphviz subgraphs**, which is what they were until
  `1d1be16`:
  - A group inherits *every* attribute from its parents. That includes `label`,
    `groupType` and `isFolded`, so an untyped group inside a `SystemBoundary`
    resolves as one.
  - Nodes and edges inherit from their groups too, and rank them above their
    type. VGL cannot express this and no production code relies on it.
  - The group type was added later as a style tag (0004) and never joined the
    chain, so a type cannot start folded.
- **Two resolution paths disagree.** `get(node:attribute:)` ranks the type
  above the root. `getAttributes(node:)`, which both exporters use, lets the
  root override the type. Only the absence of such values hides the difference.
- **Different kinds of element share one string keyspace**, so a node and a
  group type cannot share an id (0016, 0020).

## Decision

**Layers.** A value is set in exactly one layer. From least to most specific:

1. the engine: the display types every notation has;
2. the built-in notation;
3. the document's `vnotation`: one layer, which suffices while a `vnotation` can
   extend only a built-in notation;
4. the model: the `vgraph` block and its elements;
5. a view.

An attribute's default sits below them all but is not a layer: it is one value
for every element, where a layer holds values on particular keys. The engine is
a layer of its own rather than part of the built-in notation, because a
`vnotation` that extends nothing has no built-in layer and still needs the
display types.

The most specific value set wins. **The layer comes first**: a view that sets a
value only on a *type* still beats the model's value on the element.

**The chain within a layer is element → its type.**
- A group resolves as group → group type.
- Nothing is inherited from an enclosing group. A group says what belongs
  together, not what its members look like; setting a property on many elements
  at once is the job of selector rules.
- The graph is its own element, the root group. Its values go through the
  layers like any other element's, but it is in no other element's chain.
- An attribute that means something only for the whole diagram
  (`layoutDirection`, `notation`) is rejected on any other group.

**Who may set what.**
- The notation layers hold values on types.
- The model holds values on elements and on the root group, never on types. A
  change meant for every element of a kind is a change to the notation, and it
  is written back into the document's `vnotation`.
- Every attribute is a **content** or a **presentation** attribute; an
  undeclared one is content. A view layer admits presentation attributes only.
  Anything judged, or anything that says what the diagram claims, is content,
  because judging reads the model without a view.

**A notation is data.** It states its types and the values on them as a
`NotationContent` and never writes to a graph. Whoever installs it places it in
a layer: the parser puts a built-in notation and its extensions in the built-in
layer and a `vnotation` block in the `vnotation` layer; the engine puts the
display and unknown types in the engine layer. The layer is chosen where the
content is placed, not by a mode the graph carries while a notation runs.

**The layers form a tree, and a query reads one path of it.** Here the tree is
engine → built-in → vnotation → model, with every view branching off the model;
with one view it is a single stack. The path a query reads is its stack:
- Judging (quality checks, bounds, loops) reads engine → … → model, and so
  cannot see a view.
- Rendering a view reads the same stack with that view on top.

Layers are held once and shared, and switching views swaps the stack. The model
is the default view: every host shows it when no view is named, even in a
document that declares views, and with none active it takes presentation
changes too. Folding is presentation, so it belongs to a view where one is
active and to the model where none is.

**An override exists only while it differs.** No layer holds a value that its
ancestors already resolve along the same chain, and a value equal to the
default counts as provided. Judging along the chain, not per key, is what lets
a group's `false` beat its folded type while a `false` under an unfolded type
disappears, and what lets an element that repeated its type's value follow a
later change to the type. Writing such a value deletes it. When an ancestor changes,
every descendant value that has become equal is deleted too. So nothing is
pinned: if the notation later changes the colour, an element that only
repeated the old colour follows. A view follows the model the same way: a
`vview` value equal to the model's is pruned and leaves the file, and the view
then shows whatever the model says. Sibling views never prune each other.

**The display graph** is derived at runtime and resolves through the same
layers. What the Display pipeline computes (positions, sizes, stamped styles)
goes into the model layer of that copy, which nothing stores. That includes what the pipeline
stamps into the origin graph's attributes today (`fixedsize`, boundary chrome,
bundle labels, loop markers). Display-only elements (fold proxies, bundles,
derived edges) have **engine-provided display types**. Every notation has them,
no model can use them, and a notation may restyle them in its own layer. A
folded edge's display type has the original type next in its chain, rather than
a copy of its values. The unknown types are engine types too, but a model may
use them, since a document can name a type its notation lacks.

**What is not an attribute.** The store resolves by override, so something
belongs in it only if it is a value about an element, a type or the root, and a
more specific layer may meaningfully replace it. Some of today's flat store
fails that and leaves it:
- **Type links.** A group's type is the second step of its chain, like a node's
  or an edge's, not a `groupType` value. The graph's group structure holds it,
  and it is optional: most groups are plain.
- **Notation definitions:** the registry of group types, declared icons,
  quality checks and transforms. They accumulate across `extends` steps rather
  than override, and nothing more specific may change them. The graph carries
  them as a **notation definition**, built once from the built-in entry and the
  `vnotation` steps, so the renderer and the checks, which see only a graph,
  can still answer.
- **What selects the layers:** `notation`, `extensions` and `extendsNotation`
  decide which notation layers exist, so they cannot be values inside them.
  They are part of the notation definition. The graph's id and label stay, as
  content on the model's root.
- **Findings and bookkeeping:** quality messages belong to the quality report
  (the per-node `messages` attribute is unused and goes), declaration order to
  the graph's structure. A notation's markdown description is rendered from the
  notation when asked for; it never belonged to a graph.

**Which values are written to VGL follows from their layer**, not from a flag on
the attribute. The exporter writes the `vnotation` and model layers; the engine
and built-in layers come back at every parse and are never written. So
`AttributeKind` goes. Its only use was to keep the exporter off values nobody
wrote, and it could not say that one attribute is written when a `vnotation`
sets it and not when a built-in notation does: `isJunctor` had to be marked
*transient* although it is part of what a notation says. In its place, besides
content and presentation, a third category, **computed** (first called "display"), holds what the Display
pipeline computes. The parser refuses it and the exporter skips it, so a layout
result never reaches a document; the model layer takes it like any other value, but
only the view graph, which nothing stores, ever receives one. It is never pruned: "computed as empty" is not "not
computed".

0020 and 0022 stored the registry and icons as computed root attributes because
0004 had made a group type a tag and the flat store was the only per-graph
place to hold them. Both reasons are gone: the type is now a link, and the
definition travels with the graph. Everything else those ADRs decided stands.

The choice of which loops get a marker is a presentation value on the root; the
markers themselves exist only in the display graph.

**Rules get a layer of their own**, the parent of the layer they are
written in: model-rules → model, view-rules → view. A value set directly on an
element then beats every rule because its layer is more specific, a direct value
equal to its rule's is pruned, and removing it brings the rule's value back.
Recompiling rules replaces only the rules layer. Within it, the later rule wins.
Provenance names the layer, so it already says whether a rule set a value; the
`AttributeSource.rule` and `ruleSources` that OLD-196 added for this go.

**The store is VGraph's `AttributeStore`, grown in place.**

- **What it knows:**
  - attribute definitions: id, declared type, default, and a category read
    from VGraph's own table. They are registered explicitly and shared by
    every layer. Writing an unknown attribute, or one declaring another type,
    is an error. Nothing is defined on first use. Values stay strings, so a
    write is checked against the declared type's name only; a typed definition
    parses its value before it gets there;
  - named layers arranged as a tree, each admitting by kind of key and
    category;
  - keys of (kind, id);
  - values and their provenance.
- **What it asks:** an element's type, and a type's elements. The graph's
  structure is the only record of them, so lookups and pruning ask it rather
  than keeping a copy that could drift.
- **Queries:**
  - `resolve(attribute, key, through: layer)` returns a value and its
    provenance. The most specific layer holding the key or any later step of
    its chain wins, and within it the earliest step. If no layer holds one,
    the definition's default is returned with provenance *default*;
  - `resolveAll(key, through: layer)` returns every attribute set on the chain;
  - `values(in: layer, for: key)` returns what one layer holds;
  - `set` and `remove` go through the layer's admission, and `set` prunes a
    redundant value as it writes;
  - `removeKey` removes a key from every layer, `replaceLayer` swaps a layer,
    and `repruning` judges a retyped element's values again.
- **It is functional, but need not be persistent.** Every operation is pure
  and returns a new store, yet no old version outlives the edit that replaced
  it. History is VGL text (0006), and a view is declared in VGL, so an edit to
  a view is an edit to the text and is captured there. Views share the layers
  beneath them because they are layers of the same store, not copies. A plain
  dictionary per layer and kind is enough.
- It builds under Embedded Swift 6.4 in the wasm graph.

## Considered options

- **Keep a value that repeats its ancestors** (pinning it). An override
  that states nothing new is noise in the file, and it would silently stop the
  element following later changes to the notation.
- **Layers as one linear order.** Sibling views have no order between them, so
  a linear order would make one view prune against another.
- **Define a property on first write**, as `set` does today. An attribute
  created that way has no category, and admission depends on the category.
- **Rules and direct values in one layer, each value tagged with its source.**
  Both share one slot per key, so recompiling a rule overwrote a direct value,
  and removing a direct value could not bring its rule's value back.
- **One store with a layer tag on each value.** It would record provenance but
  not share layers between stacks, so every view would copy the model.
- **Element-first resolution** (every layer at the node, then every layer at
  its type). A view could not override a model value on an element by naming
  only its type.
- **Two cascades** (0029): views over layout, the look over appearance. This
  was simplified to one stack. The rule 0029 wanted, that a view must not change
  what is judged, is kept by the content/presentation split instead.
- **A generic store in its own target** (`LayeredProperties`). It was built and
  tried against every fixture. Pruning along the chain needs the graph's
  chains either way, and growing `AttributeStore` kept VGraph's API, let
  VGraph move over step by step, and cost no wasm.
- **A persistent store with structural sharing** (swift-collections'
  `TreeDictionary`). It makes a kept version cheap, but nothing keeps one: the
  history of a document, views included, is its VGL. It cost about 60 KB of
  wasm and made lookups roughly three times slower than dictionaries.
- **A separate look layer.** It may come back, but it is not needed now.
  Styling is part of the type definitions in layers 1–2.
- **A layer mode on the graph while a notation installs** (`installing(into:)`).
  It left every notation's install code as it was, but the same write landed in
  a different layer depending on where it ran, and every rebuild of the graph
  had to carry the mode along.
- **A runtime layer above the view** for computed values. It is unnecessary
  because the display graph is already a derived copy.
- **Keep group inheritance and add the type between a group and its parents.**
  That keeps the subgraph model, and its only effects today are bugs.

## Consequences

- The exporter writes the model layer and the `vnotation` layers directly. It
  stops rebuilding the notation to diff against.
- `unfolded` becomes meaningful: a model `false` beats a type's `true`. Where
  the type is not folded anyway, `unfolded` is redundant and disappears on
  export.
- Round trips are no longer byte-identical for a file that repeats its
  notation, e.g. `[rankdir: TB]` where the notation already lays out top to
  bottom. The export drops the repetition.
- The tests that exercise member inheritance (`AppTests/VGraphTest.swift`,
  `VGraphTests/AttributeTests.swift`) are rewritten. `QualityAnalysis`'s local
  workaround for group inheritance goes away.
- With (kind, id) keys a node may share its id with a type; `idCollision`
  remains only between nodes, edges and groups.
- The unused `AttributeLevel` enum is replaced by the layers.
- A `vnotation` can then declare junctor types, written back with its block.
- An absent node label means the node's id to the parser, so the label's
  default is empty and a node the editor creates gets a placeholder instead;
  the old default was pruned as redundant.
- Nodes, edges and groups still share one id space because edges, the editor
  and folding look elements up by bare id.
- Whether a value was set is not information anyone may use: pruning removes
  a value whose resolution would be the same. So a default must be what VGraph
  means, and an adapter translates resolved values. The DOT exporter writes
  every translated value Graphviz would not assume; defaults that were only
  placeholders for Graphviz (`fixedsize`, `width`, `height`, `arrowhead`,
  `arrowtail`, `constraint`) became Graphviz's own, which is what an unset
  value already meant.
