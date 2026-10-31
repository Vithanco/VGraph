# VGraph — Context & Glossary

This is a glossary of the domain language, not a spec. It captures what terms
*mean* so that code, docs, and conversation stay aligned. No implementation
details belong here.

[`docs/mcp-vocabulary.concept-map.svg`](docs/mcp-vocabulary.concept-map.svg) maps
how [[Notation]], [[Method]], [[Tool]] and their neighbours relate — drawn in
VGraph, source beside it.

## Terms

### Notation
A visual language: a fixed set of node types, edge types, and the rules for which
may connect to which. A notation says what a diagram *may contain* — it constrains
rather than describes. A set is built in; a [[Dynamic notation]] adds more at
parse time.

A notation is not a diagram and not a procedure. It is the grammar both rely on.
Guidance is its job, which is why deviating from it is a [[Notation break]] and
must be deliberate.

### Method
A repeatable procedure for reaching an outcome, expressed as an ordered sequence
of steps and producing one or more diagrams. Where a [[Notation]] says what a
diagram may contain, a method says what you *do*, and in what order.

Methods and notations are **many-to-many**: several methods may use one notation
(three separate methods use Concept Maps), one method may span several (the Eight
Categories of Legitimate Reservation covers six), and a method may name none.

A method's value is in the doing, not the artifact. Aligning on terminology is the
point of mapping it; the map is what is left over afterwards. This is why a method
is inherently multi-turn, and why it is delivered as a skill or prompt rather than
as a single [[Tool]] call.

### Tool
A single request/response capability offered to a client: input in, result out, no
conversation. One tool per [[Notation]] renders VGL to an image and a quality
report.

A tool is chosen by the [[Assistant]]. A *skill* or *prompt* — the form a
[[Method]] takes — is chosen by the person, and holds a procedure across several
turns. The distinction is who decides and how many turns it spans, and it is why
methods are not tools.

### Assistant
The language model at the other end of a connection — the thing that picks a
[[Tool]] and reads the quality report back.

Never call it *the model* here. **C4 Model** is a registered [[Notation]], so
"the model" in a VGraph sentence reads as C4 at least as readily as it reads as
the LLM. MCP's own specification says "model-controlled"; when quoting that,
say so explicitly rather than adopting the word.

### Quality check
A rule belonging to a [[Notation]]: given a graph, it returns zero or more
messages. It exists whether or not anything is ever drawn — `Ibis.qualityChecks`
is a list of rules, not a list of findings.

A check states what *good* means for its notation. It never rejects a diagram: a
[[Notation break]] is the user overriding guidance on purpose, so a check reports
and leaves the decision alone.

### Quality report
What one diagram got back: the messages every applicable [[Quality check]]
emitted, plus the notation they were run for. It exists only after a render.

The distinction from a [[Quality check]] is rule versus result, and it is easy to
collapse by accident. A report does not contain checks; it contains what checks
said about one graph. Every render returns one alongside the image — the report
is half of what the MCP server hands back, not a diagnostic afterthought.

It has two parts. **Model findings** are what the checks said about the
[[OriginGraph]], the same in every [[View]]. **View findings** describe the one
view rendered — how much of the model it shows, how many [[Derived edge]]s it
drew, how many findings concern elements it hides, which of its rules name
nothing — and judge nothing.

### Dynamic notation
A [[Notation]] declared in VGL with `vnotation` rather than built in, optionally
extending one that exists. It carries its own types and icons, so a domain can
name its own concepts without the registry changing.

### Example graph
A complete, ready-made VGL document in `exampleGraphs`, showing what a
[[Notation]] or feature can do. Any front end can offer them (the editor's
Examples menu does), and one test runs every example through parse, render and
save, so an example that stops working fails the build. Every registered
notation and extension must have one (a test fails otherwise); add one for any
other user-visible feature too. Its quality report must stay clean: an example
that trips a check is either wrong or teaching the wrong thing.

### Engine
The core: the pure VGL→SVG transformation exposed by `VGraphWasm` as string-in/string-out
functions (`renderGraph`, `renderGraphDark`, …). Graphviz layout is compiled
*into* the module (in-process, Embedded Swift) — there is no separate JS layout
step and rendering is a single synchronous call. The engine has no knowledge of
the DOM, UI, or user interaction. All consumers — website, Obsidian plugin,
VSCode plugin — depend on this same engine.

### Editor
The interactive UI for a VGL document. It lives *inside* WASM (built with
ElementaryUI) and owns its own DOM, state and events; the host page only boots
it ([[Bootstrap]]). It is an **additive driving adapter** — it sits beside the
untouched [[Engine]] functions, never replaces them. The engine's pure functions
remain the contract the plugins depend on.

It started text-centric: VGL with live preview, the rendered graph only a
*projection* of the text. It is becoming a direct-manipulation editor, where the
diagram is a thing the reader edits rather than a picture of the text —
[[VCommand]]s were the first step, [[Gesture]]s the second, and [[Selection]],
[[Move]], [[Reattach]] and [[Decompose]] followed. The text interface stays:
direct manipulation is added beside it, never in place of it. Arbitrary
interactive editing remains a larger, later initiative.

The ambition is that, in the long run, every feature is reachable in the editor,
not only by writing VGL.

**Which one is the truth.** Under manipulation the [[OriginGraph]] in a
[[GraphSession]] is the working copy: a gesture mutates it, and the VGL is
re-derived from the result. That derived text is the document — what [[History]]
is built on, what is persisted, and the version that wins if graph and text ever
disagree. So the graph leads within an interaction and the text is authoritative
across them; the two are not rivals for the same job.

That only holds while an export is faithful enough to hand straight back, which
is a rule with a name: after a command applies, the text the adapter puts on
screen is *already* the document, so feeding it back changes nothing and every id
the adapter holds stays valid (`ReparseIdentityTest`). It is also why export
fidelity — comments, declaration order, formatting — is load-bearing rather than
cosmetic: a gesture that silently reformats hand-written VGL has broken the
tie-breaker, not just tidied it.

### Bootstrap
The small piece of host JavaScript that instantiates the WASM module and calls
the [[Editor]]'s `mountEditor` entry point. It stays *outside* WASM by
necessity — it is the caller that boots the module — and keeps what needs a JS
callback: fetching a `?src=` document, the draft store, and the exports the
editor's timers call back into. The editor reads `?vgl=` and `#vgl=` itself, so
every host honours them; a host hands it a document through `setEditorVGL` or
`openEditorDocument`. Everything else (UI, state, render, the [[File menu]])
lives *inside* the editor.

### File menu
The [[Editor]] toolbar's document commands: open a file, save the VGL, save the
rendered SVG. There is no file *handle* behind it — the browser gives none that a
page may write back through — so "save" is always a download and "open" is always
a new document (fresh [[History]]). What an opened file leaves behind is just its
name, which the two saves then reuse.

### Diagram as document
Every render carries its VGL inside the SVG's `<metadata>`, so a saved diagram is
a *document* and not merely a picture: the [[File menu]] opens one straight back
up. Saved as `.vithanco.svg` to say so, while staying an ordinary SVG to every
other tool. The VGL it carries is the *exported* text (see [[GraphSession]]), so
a round trip through SVG preserves the graph and its [[Comment]]s but not the
user's own formatting — preserving that verbatim is what "Save VGL" is for.

### Driving adapter
An entry point that exposes the engine to the outside world (e.g. the `@JS`
functions in `VGraphWasm/Sources/Main.swift`). The [[Editor]] is a new driving
adapter (`mountEditor`); the existing pure render functions (`renderGraph`, …)
are another. Adding the editor never changes the pure functions — that is what
keeps the plugins working unchanged.

### Driving port
What a [[Driving adapter]] is allowed to ask for: the interface the application
*offers* outward, as against the ports it *needs* inward (parsing, layout,
storage). One port per **actor**, and the [[Editor]] is not one actor — the text
view, the diagram view and the [[File menu]] are three, each able to appear
without the others, so each has its own. A component holding one port cannot
reach what another's actor may do.

Changes flow back the other way, as an announcement the application makes and an
adapter listens for — an **Observer**, carrying no payload, because the three
listeners each want something different and would be told two thirds of nothing
useful. That is not a cycle: both interfaces belong to the application, so what
travels outward is control, never a dependency. See
[[0013-driving-ports-and-named-commands]].

### Zoom
How large the diagram is *drawn* in the Preview pane ([[Editor panes]]): fitted to the pane (the
default, and it keeps following the pane) or a fixed percentage. View state of
the browser session only — never in the document, [[History]] or a view.

Not C4's "zoom": that is the notation's word for a [[Fold state]] — which level
of detail the model shows, not how large it is drawn (ADR-0003).

### Editor panes
The **Source pane** holds the VGL text and the status line; the **Preview pane**
holds the rendered diagram; the **Diagnostics pane** lists the messages of the
[[Quality report]]. The Preview pane is not the canvas — that word is the root
group (ADR-0016) — and "live preview" is the behaviour, not the pane
([[Live preview]]).

*Hide source* takes the Source pane away, and the Preview pane the space. The
Diagnostics pane stays, shrunk to one line that carries the status line; a click
opens the full list over the diagram. The **Display panel** holds [[Zoom]] and
the theme, behind one toolbar button that shows the zoom. All of it is session
state, never document state.

An editor embedded in a page is only as big as its iframe. *Full window* takes
the whole screen where the browser allows it, and otherwise opens the editor on
a page of its own, carrying the document in the link.

### Live preview
The editor re-renders as the user types, debounced, *and* on an explicit render
command. Because VGL is usually mid-edit-invalid, a parse failure is
*non-destructive*: the last successfully rendered graph stays on screen and the
error is shown only in the status line. The preview advances only on a
successful parse.

### OriginGraph
The rawest `VGraph`, built directly from parsed VGL and held in memory by a
[[GraphSession]] — the source of truth *among graphs*: every [[View graph]] is
derived from it, and nothing derived is ever written back. Across interactions
the document is the VGL it exports, not the graph (see [[Editor]]).

Its round-trip invariant: exporting it to VGL and reparsing yields a
*semantically identical* OriginGraph (the text may be reformatted by the
exporter, but nothing is lost or added). A [[VCommand]]
mutates the OriginGraph in place; editing the VGL text reparses into a fresh one.
It is deliberately the *pre-transform* graph — folding, layout and rendering are
all derived from it and never fold back into it (see [[Display pipeline]]).

### Display pipeline
The derived path from [[OriginGraph]] to a rendered diagram, re-run whenever the
editor shows something. Never a source of truth. Its stages: **Select Subset**
(a [[View]]'s `include` / `exclude` / `expand` rules choose which elements of the [[OriginGraph]] participate), **Transform Graph** (visual-only
rewrites such as folding), **Layout Graph** (Graphviz positions), **Render Graph**
(SVG). Each rendered element is stamped with the OriginGraph id of the element it
represents, so a right-click can resolve back to a [[VCommand]] target by id.

### View graph
The `VGraph` the [[Display pipeline]] transforms the [[OriginGraph]] into, and the
one that gets laid out and drawn — a folded group reduced to a single stand-in
node, its crossing edges attached to that box. It is for **presenting**, never for
**judging**: quality checks, [[Bound]]s, [[Graph criterion]]s and loop detection
all read the OriginGraph, so a fold can hide a problem from view but never from
the diagnostics, and can never invent a loop the model does not have.

What the view graph needs to draw a thing is not what the thing is. The
stand-in is a node here, yet the box on screen is stamped as its group, because
that is the element it represents. See
[[0027-judge-the-origin-graph-present-the-display-graph]].
*Avoid*: "folded view", "intermediate graph", "transformed graph", "display graph" (its old name).

### Layer
One of the places a value can be set, from least to most specific: the engine
(the display types every notation has), the built-in [[Notation]], the
document's own `vnotation`, the model (the `vgraph` block and its elements), and
a [[View]]. Asking for a value returns the most specific one set, so a view
overrides the model, the model overrides its types, and a `vnotation` overrides
what it extends. An attribute's default is not a layer: it applies to every
element alike, where a layer sets values on particular elements or types.

The layers a lookup reads are its **stack**. With one view the layers form a
single stack; a second view branches off the model beside the first, and views
never see or override one another.

The notation layers hold values for *types*; the model holds values for
*elements* and for the diagram itself, never for types. A change meant for every
node of a kind is a change to the notation, and once written back it lives in the
document's `vnotation`, not in the model. Nothing is inherited from an enclosing
[[Group]]: a group says what belongs together, not what its members look like.

The [[View graph]] resolves through the same layers with its view applied; the
[[OriginGraph]] has no view layer, which is why nothing judged can depend on one.
*Avoid*: "level" for this.

### Presentation attribute
An attribute a [[View]] may override: how something is laid out or drawn —
colour, fold state, layout direction, edge weight, alignment, which loops are
marked. Two readers of one diagram could rightly want it different, and nothing
judges it.

### Content attribute
An attribute that says what the diagram claims: a label, a link, a comment, a
type, a [[Bound]]. Only the notation and the model set it; a view cannot, because
anything judged reads the model without a view, and a view that changed it would
show one thing while the diagnostics checked another. An attribute not declared
otherwise is content.

### Computed attribute
An attribute the [[Display pipeline]] works out while rendering — a position, a
size, wrapped text, a fold count — as against one an author writes. No document
holds one: the parser refuses it, the exporter skips it, and only the
[[View graph]] receives it. Never pruned, so "computed as empty" stays distinct
from "not computed".

### View
A named choice of **what** of the [[OriginGraph]] is shown and how it is
arranged — which elements appear, which groups are folded, which annotations
such as [[Loop marker]]s are drawn, and the layout direction — declared in VGL as
a `vview` beside the `vgraph` it looks at. A document holds one model and any
number of views; a render names the view it wants. A view is the recipe the
[[Display pipeline]] follows, the [[View graph]] is what it produces, and
neither is ever judged.

A model says what is true; a view says what of it is shown and how.

A view states only what it changes. The rest it takes from the `vgraph` block,
and what that leaves open from the notation — the same way a node overrides its
type. The **default view** is the model itself: the `vgraph` block's own
settings, everything shown. It is what every host shows when no view is named,
whether or not the document declares any `vview`.

A view overrides [[Presentation attribute]]s only, never [[Content attribute]]s.
The test for which is which: **if anything judges it, or it says what the diagram
claims, it is content** — quality checks, [[Bound]]s, [[Graph criterion]]s, loop
detection, labels. Where that is unclear, ask whether two readers of the same
diagram could rightly want it different.

Colour is presentation. A type's colour is how a reader recognises the type, so
it usually stays the same across views; a view may still emphasise, and marking
what is new or changed is exactly such an emphasis.

A view is not the [[Selection]]: selecting is what one reader is doing now, and
never written into the document. A view can be *made from* a selection.
*Avoid*: "vdisplay", "display" for the declaration — the view graph is the
result, not the recipe.

### Selector
The one language that picks elements: `node`, `group`, `node type:`,
`group type:`, lists, `*`, and a reach along edges (`+n`, `downstream n`,
`upstream n`). It is always evaluated on the [[OriginGraph]], never on a graph
earlier rules have thinned out, so `downstream 1` means what the model says
whatever else the view hides. Edges are never selected: one shows when both its
ends do.

### Subset rule
A view's `include`, `exclude` or `expand n`, applied in order to the set left by
the rules before. A view whose first rule is `include` starts empty; any other
starts with everything. The result is a set of nodes **and groups**: including a
node adds its enclosing groups implicitly, but `include group g` adds the group
itself, so it stays as a box even if all its members are excluded afterwards.
That is how a C4 System Context shows the system as one box. It chooses elements
and sets nothing; a rule that selects *and* sets attributes is not part of the
language yet.

### Active view
The [[View]] the [[Editor]] is showing and writes into, if the reader picked
one. With none picked, the default view — the model — is shown, and it takes the
presentation changes too. Folding, hiding, showing and changing
direction change the active view; adding, renaming, retyping or connecting
change the model, whichever view is active. Folding is the author's alone, so adding or
moving into a folded group leaves it folded.

### Derived edge
A dotted line from A to C standing for a chain A → … → C whose middle a [[View]]
hides. Without it, hiding the middle of a chain would say A and C are unrelated,
which is false. One is drawn per pair and direction however many hidden paths
there are. A real edge from A to C in the same
direction makes it redundant, so none is drawn then. A chain from A back to A
is drawn as a self-loop.

It is not an edge of the model: nothing judges it, and its type is one every
notation's display has but no model can use, so it is never offered for editing
or retyping. It carries no polarity, label or count in any notation: it says
"related through something hidden", and nothing more — to see what, show the
hidden nodes. Only what a view's
selection hides makes one; a [[Fold state]] has its own [[Edge bundle]]. A view
draws derived edges unless it sets `derivedEdges: false`. The term is ArchiMate's.
*Avoid*: "implied edge", "shortcut".

### Edge bundle
Several edges running the same way between the same two things on screen, drawn
as one line with a count ("×3") — which happens only where a [[Fold state]] has
collapsed their ends into one box. Its members are listed on hover, and it takes
their edge type's look only if they share one. A bundle is not an edge: it has no
label, type or ends of its own to edit, so what it offers is to unfold the group.
A single edge into a folded box is not a bundle.
*Avoid*: "implied relationship" — nothing is inferred; they are real edges drawn
together.

### GraphSession
The stateful coordinator that owns one [[OriginGraph]] and composes the pure
[[Engine]] functions: it applies a [[VCommand]]'s [[graph change]], re-runs the
[[Display pipeline]] to SVG, and exports the OriginGraph back to VGL. It holds the
mutable state the pure Engine deliberately does not; adapter-agnostic (the
[[Editor]] drives it today). It also owns the undo/redo [[History]]. Loading and
typing are separate by intent: **`replaceDocument(vgl:)`** loads a new document
(resetting history) and **`textEdited(vgl:)`** records a user text edit
(coalesced into the current [[Text-edit run]]). They belong to different
actors — the toolbar's port and the text pane's: `replaceDocument` is something
the toolbar *asks for*, `textEdited` is something the pane *reports*.

### History
GraphSession's undo/redo stack: a bounded list of settled [[Snapshot]]s with a
cursor. `undo()`/`redo()` move the cursor and reparse the snapshot back into the
[[OriginGraph]], returning its VGL for the [[Editor]] to show; `canUndo`/`canRedo`
drive the toolbar buttons. One unified stack covers both [[VCommand]]s and text
edits. A new change after an undo drops the forward (redo) history. See
ADR-0006.

### Snapshot
One entry in the [[History]]: the VGL text of a settled state (**a state is a VGL
string**). The OriginGraph is always semantically `parse(history[cursor])`.
Command entries hold re-exported VGL; text-edit entries hold the user's verbatim
text (comments and formatting preserved).

### Comment
A `//` line in VGL, held on the element it stands above (or after, on the same
line) as an attribute of the [[OriginGraph]] and re-emitted in `//` syntax on
export. An element's **leading run** is the whole contiguous block of comment and
blank lines above it, back to the previous statement, with blank lines trimmed at
the run's edges — so a `// ====` section banner keeps its place, and the blank
line the exporter itself writes before a group never accumulates. Comments are
*data*, not formatting: they ride through undo, survive [[VCommand]]s, and are
deleted with their element. Comments with no element to hold them — before a
closing brace, inside a `vnotation` block, after the final `}` — are dropped. See
[[0010-vgl-comment-round-trip]].

### Text-edit run
A continuous burst of typing recorded as a *single* undo step: while a run is open
the top [[Snapshot]] is updated in place instead of cutting a new one. The run is
**sealed** — so the next edit starts a fresh step — by a [[VCommand]], a document
load, an undo/redo, or textarea blur (`textEditingEnded()`).

The run is the *session's* concept and deliberately not the text pane's: the pane
reports that its text changed and that a burst ended, and knows nothing about
undo steps coalescing. That is why its [[Driving port]] says `textEdited` and
`textEditingEnded` rather than naming the run.

### VCommand
A declared graph operation offered to the user (today via the [[Editor]]'s
right-click menu): which element kinds it targets, a display label, its
**availability**, and a [[graph change]].

Availability is not a yes/no. A command can be unavailable because it does not
apply here at all — nothing leaves a terminal node type — or because the
notation forbids it *unless the user insists*, which is a [[Notation break]] and
reachable with ⌥. Both grey the item out; only the second is worth offering, and
conflating them is how the break became unreachable on the node types that
needed it most.

Every command is a **named method with typed
arguments** on the [[Editor]]'s driving port — `toggleFolding(of:)`,
`split(_:with:)` and the rest. There is no registry and no catalogue: an adapter
can no longer invoke a command it does not understand, and what it gains is
arguments the compiler checks and a refusal it cannot ignore. Only `changeType`
still holds a conversation, because how many edges its new type leaves ambiguous
depends on the type just chosen. See [[0013-driving-ports-and-named-commands]].

Commands are reached in **two ways**. A *menu command* names one element, so the
menu lists it under that element. A [[Gesture]] command names several elements
in order and has no menu entry — the menu resolves a single clicked element and
has nothing to offer as the rest — so an adapter reaches it only through an
interaction it implements itself. Either way the adapter calls the command by
name, so every new command costs every adapter some work. See
[[0013-driving-ports-and-named-commands]] and [[0012-drag-to-connect]].

### graph change
A [[VCommand]]'s effect: it maps the [[OriginGraph]] to a new OriginGraph. Named
distinctly from "transform" on purpose — *transform* is the [[Display pipeline]]
stage that produces derived, visual-only output, whereas a graph change edits the
[[OriginGraph]].

### Conversation
Everything between the user choosing a [[VCommand]] and the graph changing: the
turns needed to gather arguments the command cannot get from the graph and the
target alone. It starts from a menu click, the toolbar, or a [[Gesture]]'s drop
— a gesture carries two elements and no menu target, which is why it is opened
differently — and it ends in exactly one named call, or in nothing.

**Most conversations have no questions at all.** `toggleFolding` is one; so is
adding a successor where the notation leaves a single [[Candidate]]. Only
`changeType` can have a length the domain cannot state in advance, because how
many edges its new type leaves ambiguous depends on the type just chosen. That
narrower property is what "*only* `changeType` still holds a conversation" means
where it appears under [[VCommand]] — the span is the general thing, the
unpredictable length is the rare one.

Nothing reaches the graph until the last turn, so abandoning is just closing the
menu: no [[Snapshot]], nothing to undo. There is no going back a step, only
answering or abandoning. The state lives with the adapter and never on the
[[GraphSession]] — a pending command there collides with text edits, undo and
re-targeting ([[0013-driving-ports-and-named-commands]]).

### Inline edit
Editing an element's label in the diagram itself: double-click a node, edge or
group label and type where the text is drawn. The surface is an HTML input laid
*over* the rendered element rather than part of the SVG, because every render
replaces the whole SVG; anything inside it would be destroyed mid-edit. Return or
clicking away commits, Escape cancels, and a re-render closes the editor and
discards — so a stale editor can never outlive the element it points at.
Committing is an ordinary [[VCommand]] (`setLabel`), so it lands in [[History]]
like any other change. See [[0009-inline-label-editing]].

### Gesture
Editing the graph by acting on the diagram directly rather than by choosing from
a menu: dragging one node onto another creates the edge between them. A gesture
names elements **in order** — what was grabbed, then what it was dropped on — and
the [[VCommand]] it runs declares how many it expects, so "what may be grabbed"
and "where may I drop" are one question asked at different points.

**The direction is the direction dragged.** An edge type running the other way
between the two node types does not make the drop legal: the gesture's promise is
that what you did is what you get, and an arrow that flips round after the drop
breaks it even when the resulting graph is the one the notation wanted.

The gesture supplies elements; it never supplies judgement. Which drops are legal
comes from the command, which reads the notation, its [[Bound]]s and the
[[Graph criterion]] `noParallelEdges`; the notation's other quality checks are
not consulted, so a legal drop can still draw a warning. Feedback while dragging
lives *outside* the SVG for the reason an [[Inline edit]] does — every render
replaces it — and a render cancels the drag outright.

A gesture was the first thing the command catalogue could not deliver, and one
of the reasons it went: a gesture has no single element to be asked about, so
every adapter that wanted one had to know it by name regardless. Now that every
command is named, that is simply what all of them cost. See
[[0012-drag-to-connect]] and [[0013-driving-ports-and-named-commands]].

### Selection
The elements the user has gathered in the diagram so that a coming action has its
arguments — a [[Rubber band]] pulled round some nodes, or ⇧-click on one at a
time. It is *visual gathering and nothing else*: it says what the user is
attending to, never what the document contains.

So it is **not in the document**. It is not exported to VGL, it is not a
[[Snapshot]], and changing it is not an undo step. That is a structural claim,
not a discipline: the graph cannot record what it never hears about, and a
[[GraphSession]] is never told. The cost of the alternative decides it — a
document change re-exports the VGL, re-seeds the text pane and re-runs Graphviz,
so a selection held in the document would relay out the diagram on every click.

Distinct from a **view's** contents, which is the other thing "selection" could
mean and is document state: a view names the elements it shows. The two meet only
at the moment a command runs — a selection is how you *author* a view's contents,
exactly as an [[Inline edit]] is how you author a label. See
[[0018-selection-and-group-creation]].

What it is drawn as is a halo stamped *inside* the SVG and re-applied after each
render — the one piece of interaction chrome that belongs there, because it holds
no state of its own and a render only means deriving it again.

### Effective selection
What a command actually receives: the [[Selection]] with complete groups
collapsed upward. A non-empty [[Group]] whose every direct child is selected
*is* selected, and anything inside a selected group drops out — applied to a
fixpoint, so it cascades through nesting.

It is **derived, never stored**, and that is the whole of it. ⇧-clicking a
group's last member promotes to the group; ⇧-clicking that member again removes
it from the selection and the group falls back to its parts. Were the promotion
written back into the selection instead, the second ⇧-click would have nothing to
remove and the toggle would be a one-way door.

It is what the diagram highlights, because it is what the command will act on and
anything else would misreport the outcome. It also earns the geometry it saves: a
group's rect is its children's box plus padding and a label band, so a rubber
band drawn round every node in a group need not enclose the group — the
members promote it where containment would have missed.

A group with exactly one member cannot be told apart from that member. Accepted;
the [[VCommand]] menu still resolves the element under the pointer, so the member
stays directly reachable.

The **domain** computes it, as `outermostElements(of:)`. Said without the word
"selection" it is a canonical form over the group tree rather than a convention
about pointing devices, so it belongs there — and the diagram pane still cannot
walk the group structure, which is what
[[0013-driving-ports-and-named-commands]] is protecting.

Promotion **stops below the [[Root group]]**. The root is the one group that
cannot be pointed at — a click on blank canvas clears — so it never belongs in a
set the user assembled by pointing, however honest an answer it would be. An
edge cannot be in one either: its group is derived from its endpoints, so a set
command has nothing to do with it.

### Rubber band
The rectangle dragged out to select what falls inside it. Bare drag from blank
canvas or a group's interior *replaces* the [[Selection]]; ⇧-drag from anywhere
*adds* to it — so ⇧ consistently means "extend" and never "enable".
*Avoid*: marquee, lasso (a lasso is the freehand variant, which this is not).

Bare drag from a *node* stays what [[0012-drag-to-connect]] made it. The gesture
is free everywhere else because [[0016-canvas-is-the-root-group]] deliberately
left a miss as a miss for gesture handlers, mapping blank canvas to the
[[Root group]] only for the menu.

It catches only what is drawn as a **single box** — nodes and *folded* groups —
and only when fully contained. An unfolded group holds targets but is not one: it
arrives by promotion instead, since testing overlap against its frame would
select the whole thing the moment a drag started inside it. Which is
[[Fold state]] behaving as [[0003-c4-zoom-as-group-fold-state]] says it should —
a folded group is one thing at this level, so it is picked like one thing.

### Move
Changing which [[Group]] an element belongs to, by dragging it onto the group it
should join. "Into" and "out of" are one operation, not two: the canvas is the
[[Root group]], so leaving a group is joining the one outside it, and at any
depth the enclosing group is simply a different destination.

**Where it is dropped decides which command runs.** Onto a node it is still a
[[Gesture]] connect; onto a group or the canvas it is a move. That is what let it
exist at all — every pointer gesture was spent, but both of those drops were
silent no-ops. A node is grabbed anywhere; a group is grabbed by its **label**,
its interior belonging to the [[Rubber band]]. The label is the drop target too,
being the one part of a group its children never cover, so it means *the group
itself, as against its contents*.

Most refusals are structural — a group into its own descendant, or into the group
it already occupies. One is a [[Notation break]]: a node into a [[Detailed node]]
that does not list its type, or a detail-only type to the top level; ⌥ goes past
it, and the containment check then warns. Either way the legal destination is
tinted and everything else stays silent; `connect`'s red has no counterpart. See
[[0019-moving-elements-between-groups]] and [[0032-hierarchical-notations-via-detailing]].

### Edge end
One of an edge's two attachments — its `from` or its `to`. **Not an
[[Element]]**: it has no id of its own, because it is a *position on* an edge
rather than a thing in the graph, so it is named by the pair (edge, end) and
never by a single id. That is why the renderer stamps it as chrome carrying its
edge and its side, and why `originId(fromDomId:)` keeps its promise that a
stamped id names a graph element.

The end is not the mark drawn there. A notation decides what a head or a tail
*looks* like — Concept Map draws a dot at the tail and nothing at the head — so
"the arrowhead" names no end reliably and both ends carry a handle regardless.
*Avoid*: arrowhead, endpoint-as-element, edge handle-as-element.

### Reattach
Moving one [[Edge end]] to a different node, keeping the edge's identity and
everything written on it — its label, its comments, its `itemOrder`. That
preservation is the whole point: deleting and redrawing reaches the same shape
and loses what the user wrote.

A [[Gesture]], grabbed at the end's handle, which the notation's own
[[Bound]]s answer as they answer [[Candidate]]s anywhere — but asked of the
graph **minus the edge in hand**, since an edge about to move must not count
against the budget it is about to vacate. ⌥ is the [[Notation break]], exactly as
in a connect drag; the edge's old type cannot survive an unsanctioned pair
because the graph refuses to hold a type whose ends do not match, so a break
mints an unknown type rather than carrying the old one across.
*Avoid*: reconnect, re-route, move an edge (that is [[Move]], about [[Group]]s).

### Successor / Predecessor
The node at the far end of an edge leaving a given node (its **successor**) or
arriving at it (its **predecessor**). Already the vocabulary of the diagram
logics — "each predecessor is enough to achieve the successor". The `AddSuccessor`
/ `AddPredecessor` [[VCommand]] pair creates one together with the edge that
connects it.
*Avoid*: "outgoing node", "ingoing node" — direction is a property of the edge,
not of the node.

Not every node is born attached. `AddNode` puts one in a [[Group]] — the
[[Root group]] when the user pointed at blank canvas — with no edge at all, and
so with no [[Candidate]] to choose between. Such a node is *incomplete*, never
illegal: a notation's lower bounds are reported by graph analysis and have never
withheld an offer, so this is not a [[Notation break]] and there is nothing for
⌥ to reach.

### Candidate
One option offered when adding a [[Successor / Predecessor]]. A candidate is an
**edge type**, not a node type: the notation decides which relationships may leave
or arrive at the source's node type, and the new node's type follows from the
edge type's far end. It is *displayed* as that node type, disambiguated by the
edge type's own name only when two candidates share the same pair — so a Causal
Loop Diagram offers "Stock (same)" and "Stock (opposite)" where the node type
alone could not tell them apart.

When the far end is an *existing* node rather than a new one — connecting two
nodes by [[Gesture]] — the candidate is the **destination node**, and the edge
type is chosen afterwards only if more than one joins that pair. The rule is the
same underneath: the notation decides, and the offered set is what it permits.

Creating a node with no edge has no candidate at all — there is no relationship
for the notation to decide, so the choice is a plain node type. See
[[Successor / Predecessor]].

### Bound
A notation's claim about how many edges a **type** allows: a `min…max` range,
stated as attributes on a node type or an edge type, the same way a colour is. It
comes in two kinds that are not interchangeable — a [[Degree bound]] counts the
edges at one node, a [[Pair multiplicity]] counts the edges between two.
*Avoid*: "multiplicity" or "cardinality" for the whole construct — each fits only
one of the two kinds.

A bound is **advisory**: a document that breaks it still opens, and graph
analysis marks the offending edges. It is how a notation could say that an
Evaporating Cloud's Objective has exactly two Needs — few notations declare
bounds yet — and what tells a [[Gesture]] whether a second
edge between two nodes is something to offer. Exceeding a bound is a
[[Notation break]], reached the way every other break is. Unbounded is the
default; a notation opts in. See [[0011-bounds-on-edge-and-node-types]].

A bound is a claim about a **type**. A claim about the whole graph's shape is a
[[Graph criterion]] instead — the two look alike and behave differently.

An edge type's bound counts its edges on every pair it holds, gained ones
included. An end that sits on a detail counts for the [[Detailed node]] of the
declared type around it, so [[Decompose]] never takes an edge out of a count:
two people using two containers of one system still enter that system twice.

### Degree bound
A [[Bound]] on how many edges leave (`outDegree`) or enter (`inDegree`) one node.
Declared on an **edge type**, it counts only edges of that type, at that type's
source or target node. Declared on a **node type** as `totalOutDegree` /
`totalInDegree`, it counts edges of every type together.

The two are named apart because they diverge exactly where it matters. "A Question
needs an Answer" is `outDegreeMin: 1` on the Question→Answer edge type; as
`totalOutDegreeMin: 1` on Question, a follow-up question would satisfy it.

### Pair multiplicity
A [[Bound]] on how many edges of one type join the **same two nodes**, in the same
direction. `samePairMax: 1` says a relationship cannot be drawn twice between the
same two things; it says nothing about how many *other* things either connects
to — which is what a [[Degree bound]] is for. Only pairs already joined are
counted, so a minimum never demands that two nodes be connected.
*Avoid*: "uniqueness" — true only of a maximum of one.

### Loop marker
The R, B or ? drawn inside a feedback loop of a Causal Loop Diagram: reinforcing,
balancing, or unknown because a link on it is drawn with both polarities. Which
loops get one is the author's choice (`loopMarkers`): **all** of them, shortest
first, up to a cap; an **independent** set that together covers every feedback
link; or **none**. An independent set is not "the important loops" — it can leave
a loop the author drew unmarked. See [[0028-loops-are-found-over-nodes-shortest-first-and-capped]].
The markers exist only in the [[View graph]]; the choice is a presentation
setting of the diagram, so a [[View]] may make its own.
*Avoid*: "loop indicator" in conversation (the code's name), "SILS" for the
option — ours covers every link but does not claim Oliva's full set.

### Graph criterion
A rule about the **shape of the whole graph** rather than about any one type:
"this is a tree", "no node stands alone", "at most one edge between any two
nodes". Named in a notation and reported by graph analysis, exactly as a
[[Bound]] violation is.

The two are easy to confuse and the test is what the rule is *about*. "An
Objective has exactly two Needs" names a type and is a bound. A Causal
Loop Diagram's "at most one link between two stocks" names no type — it is a
statement that the diagram is a simple digraph, and it cannot be expressed as a
bound on either edge type involved, because neither can speak for the other.

The practical difference: a bound is a value a [[Gesture]] reads before it
offers a drop, while a criterion is a check over a whole graph, which it would
have to run on the graph with the edge added. Today it does not, so a notation
whose rule is a criterion gets no help from the diagram: the drop is offered and
the diagnostics object afterwards. `noParallelEdges` is the exception: a
notation names it, and the candidate queries behind connect, reattach and retype
read that list, so a pair already joined is not offered again — which is how the
Causal Loop Diagram rule above reaches the diagram after all. See
[[0011-bounds-on-edge-and-node-types]].

### Notation break
A deliberate deviation from the notation's rules. The user must reach for it
explicitly — it is never among the offered [[Candidate]]s — because the
notation's job is to guide, and a break is the user overriding that guidance on
purpose.

It takes two forms. Connecting node types the notation does not join is
represented by an *unknown edge type*, which renders bold red and raises a
quality warning. Exceeding a declared [[Bound]] is the other: the edge is
ordinary and its type entirely legal, so nothing renders differently and only
graph analysis objects. Both are visible; only the first is visible in the
diagram itself.

An *unknown group type* is a third thing that looks like this and is not a break
at all. A [[GroupType]] the notation never registered can only come from a
mistyped document — never from a user meaning something the notation lacks — so
it is never on offer, ⌥ does not reach it, and its red frame reports a
mistake rather than a deliberate deviation. An *unknown node type* is the same
kind of thing: only the parser makes one.

A break is **a state the document can hold**. It survives an export, a close and
a reopen, and it stays a break across all three — it is not a transient the
editor tolerates until the next save. A break the document could not express
would be a break the user loses, which is worse than one they cannot make.

A break is also not a dead end: [[Declare]] is the way out of one.

### Declare
Adding a type the [[Notation]] lacks to *this document's* notation, so that an
edge which was off-notation becomes one the notation names. The document's
notation becomes a [[Dynamic notation]] extending the one it had, and the new
type is written into its `vnotation` block.

The opposite of a [[Notation break]], and its exit: a break goes **past** the
guidance and leaves a mark saying so, while declaring **moves** the guidance and
leaves a declaration saying so. Sketch with the break, which costs nothing and
answers nothing; declare when you know what the relationship is.

Declaring is never something the tool does on the user's behalf. The name is the
author's, because the name is the point — an unnamed relationship is exactly
what a break already gives you.

### Element
Umbrella term for the C4 node kinds — Person, Software System, Container,
Component, Code Element, Database. When we say "an element" in a C4 context we
mean one of these boxes, regardless of which kind. Being external is not a kind:
an external Container is a Container someone else owns.

### Container (C4)
In C4, a **Container** is a separately deployable/runnable unit — an application,
service, or datastore (a Database is a container). It is *not* the box drawn around
a set of elements. **Do not** use "container" for that surrounding box; that is a
[[Group]]. "Container-as-box" is banned vocabulary precisely because
C4 gives "container" a specific, different meaning.

### Group
The box drawn *around* a set of nodes (and nested groups). A plain group may
carry a [[GroupType]] (C4's Organisation); a [[Detailed node]] is a group that
carries a node type. See [[GroupStyle]]. The diagram as a whole is a group too —
the [[Root group]].
*Avoid*: boundary, container.

### Root group
The whole diagram, seen as a [[Group]]: the one every top-level node and group
belongs to, and where the graph's own attributes are held. It is what a
right-click on blank canvas addresses — the background is not a fourth kind of
element but the outermost group, which is why "add a node here" and "add a node
inside this group" are one operation with a different target.

It is a group with two things missing. It cannot be folded, having no outside to
collapse into, and it cannot be deleted, because discarding a diagram is
something the document does and not something the graph does. That it cannot yet
be renamed or given a link is scope rather than principle: a diagram's title
*is* the root group's label. See [[0016-canvas-is-the-root-group]].

### Fold state
Whether a [[Group]] is folded (collapsed to a single box) or unfolded (showing its
contents inside its frame). In C4 the fold state **is** the zoom level: unfolding a
Software System is zooming from Context to Container. See
[[0003-c4-zoom-as-group-fold-state]].

Fold state belongs to a [[View]], so two views can show one group at two levels.
It is declared, not performed: VGL writes `folded`, never an action. The model
or a view folds a group, and a view has the last word.

Folding changes what is **shown**, never what is **true**: a folded group is still
a group with all its members, and everything that judges the diagram sees them.
A loop that runs wholly inside a folded group goes unmarked; one that passes
through it is marked through the box. See [[View graph]].

### GroupType
The type of a plain group (e.g. C4's `Organisation`), the group-level counterpart of
`NodeType`. Unlike a node's type it is optional. A group's values resolve through
it the way a node's resolve through its type, which is how it selects the
group's [[GroupStyle]] and how a type can start its groups folded. The notation
declares which group types exist and the graph remembers them, which is what
lets a menu offer a group type and the parser refuse one the notation never
declared. See [[0020-a-graph-carries-its-group-type-registry]] and
[[0030-attributes-live-in-a-layered-property-store]].

A group with no type is not a lesser group: most groups in most notations are
plain, so "untyped" is a state to return to and not the absence of one.

### GroupStyle
A group's two appearances: `folded` (the collapsed box, a node layout) and
`unfolded` (the frame drawn round its contents: border, dash, fill). The
group-level counterpart of a node's
style; a [[GroupType]] carries a default one. See
[[0004-groupstyle-folded-unfolded]].

### Detailing
A node type's statement of which node types its nodes may be detailed by — a
Software System by Containers and Databases, say. It is what makes a notation
hierarchical; a notation with none is flat. Detailings never form a cycle, except
a type detailed by itself (a sub-process, a work package).

It widens the edge types too: a relationship declared between two types also
holds with **one** end replaced by a detail type, at any depth — a Person who uses
a Software System may use its Containers. A relationship between details at both
ends needs a declaration of its own, and an edge whose ends both become details
takes that type instead.
*Avoid*: part-of, decomposition rule; refined edge type, variant.

### Nested
How a [[Detailing]] refines: the details live inside the element, in the same
model, and an edge may join a detail to a node outside it, at any depth. The
element's own edges are summaries of its details'. Every detailing here is
nested (ArchiMate's word). See [[0033-detailing-is-nesting-edges-cross-levels]].

### Assigned
The other way a notation may refine an element, **not built**: the detail is a
separate model the element points to (ARIS's word), edges never cross its
boundary, and the element keeps its own. Named so that a notation which needs it
is a recorded choice, not a surprise.
*Avoid*: sealed (not a term of anyone's); gained (that is the widened edge pairs
of [[Detailing]]).

### Detail type
A node type named in another type's [[Detailing]]. One type may be a detail type
of several.

### Detailed node
A node that has been detailed: it has turned into a [[Group]] that carries its
node type, holding nodes of its [[Detail type]]s as members, and it is still the
node it was — same id, type and label. Folded it looks like any node of its type;
unfolded it is the frame around its details.
Only its type's detail types belong in it; anything else takes a [[Notation break]].
With its last detail gone it is a plain node again.
*Avoid*: element group, anchor, composite.

### Decompose
Making a node a [[Detailed node]] and giving it its first details: one per edge,
so that no edge loses its end — two for a self-loop, one for a node with no edges.
The details are ordinary nodes of a detail type. It changes the model; unfolding
only changes what a view shows.
*Avoid*: placeholder, dummy (for the details); zoom in (that is unfolding).

### Icon
A named drawing: one outline, one colour, chosen where it is drawn. Two things
share the word and are worth keeping apart: the **icon name** is all a node type
holds and all that travels with it, and the **artwork** — one path and a viewBox —
is what that name resolves to. A notation may supply artwork of its own, and a
name resolves against the notation's first and the built-in icons second, so a
notation's `flame` *is* `flame`. See [[0022-a-vnotation-carries-its-icons]].

VGraph ships some icons itself; the style guide's Icons section holds every
master and `BuiltinIcons` is the copy the renderer reads. Several names may share
one drawing.

An icon is drawn in one of two ways. Most sit on the **icon background** — the
coloured circle — of a [[Node type badge]]. A junctor's icon (AND, OR, the
Evaporating Cloud's conflict) and the `default` icon carry their own background
and are drawn as the whole node; what they cut out shows the page or group
behind. A node type whose style needs an icon but names none draws the `default`.

A name that resolves to neither is not an error and not nothing: it draws a
**missing-icon placeholder** and is reported, the way an unknown node type is. It is
deliberately not a question mark: that is the `default` icon, which stands for
an icon the author has yet to choose.
*Avoid*: mark, seal, glyph (older words for the same thing); symbol (the SVG
element), SF Symbol.

### Node type badge
The group at the top-left of a content node: an icon on a coloured icon background,
followed by the type name. The background takes the type's border colour; the icon
says what the type is.
*Avoid*: badge on its own (the link badge and the count pill are different things);
type icon.
