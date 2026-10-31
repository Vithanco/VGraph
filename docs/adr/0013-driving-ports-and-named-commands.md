# 13. Driving ports and named commands

Date: 2026-08-03 (amended 2026-08-06 and 2026-08-09; commands named 2026-08-08)

## Status

Accepted. Absorbs 0008, whose replay machinery the named commands removed, and
0014, which named them. Sequenced after [0012](./0012-drag-to-connect.md);
inverts the port pattern established by
[0007](./0007-document-versions-port.md).

## Context

Every other port points inward: the domain declares what it needs and App names
it. **Nothing declared what the outside may do.** `GraphSession` was the driving
port in effect — eighteen public members over five concerns (graph, text,
commands, history, rendering) — but a concrete generic class, so an adapter
naming its type had to spell every parameter, everywhere.

The editor made this invisible. The session is a module global read directly by
every handler, and one function moved both views at once: apply a command and it
re-exports the VGL, re-seeds the textarea, repaints the highlight, re-renders and
refreshes the history flags. Nothing had to be *told* anything, because nothing
was separate. The pressure is a second adapter — a native SwiftUI editor — and a
wish the current shape cannot express: showing one view without the other.

Editing operations were values in a registry: a `VCommand` bundled an id, the
kinds it applied to, a title, an availability guard and a `change` closure. An
adapter asked `availableCommands(forTargetId:)` for a menu and called `attempt`
to run one. The property that bought was real — **an adapter could invoke a
command it did not understand**, so ten of twelve commands cost the WASM editor
no code at all.

`AddSuccessor` broke the one-shot shape: it needs two answers between the menu
click and the graph change — which relationship, and what the new node should
say. A command **cannot ask the user itself**. There is no `async`/`await` in
the engine; it is Embedded Swift on `wasm32-wasip1` with neither JSPI nor
asyncify, so a port called inside a command could not block while the user
clicks a menu. The only synchronous browser prompts cannot render a type picker,
and a UI port would sit inside `Sources/VGraph/Domain/`. The engine also runs
headless in the CLI, the MCP server and two plugins.

The first answer kept the registry: `change` returned `.done(VGraph)` or
`.needs(request)`, and the adapter re-ran the command from the start with each
answer added. The price was paid everywhere. One `change` signature served a
command needing nothing and one needing two answers, so answers were positional
and untyped with a `"__other__"` sentinel. A command could not be asked what it
wanted without running it, so `attempt` returned a four-case enum and the adapter
drove the replay loop. Command titles were English literals inside `VGraph`, in
an engine that also runs where nothing shows them. And the generality was drawn
on once: gestures never had a single id, so `connect` was known by name
regardless ([0012](./0012-drag-to-connect.md)), and the CLI, MCP server and
plugins never touch commands.

## Decision

**The editor is three actors, each with its own driving port, and every command
on them is a named method with typed arguments.**

### One port per actor

| Port | Actor | Surface |
|---|---|---|
| `ForEditVGL` | text pane | `textEdited(vgl:)`, `textEditingEnded()`, highlighting |
| `ForEditAGraphVisually` | diagram pane | `label(of:)`, `render(darkMode:)`, the named commands, and the candidate queries a menu is built from |
| `ForManageADocument` | toolbar | `replaceDocument(vgl:)`, `exportVGL()`, `undo()`, `redo()`, `canUndo`, `canRedo` |

One port per actor is the whole rule. The toolbar is an actor and not plumbing:
the file menu and the undo buttons are neither pane, and giving them a port is
what stops history being declared twice.

- **They are declared in the core** as `VForEditVGL`, `VForEditAGraphVisually`
  and `VForManageADocument`, with `Ports/Inbound/` re-exporting each under its
  plain name — the same two names every driven port has. *(Reversed 2026-08-09;
  they were originally exempted and declared only in `Inbound/`, on the argument
  that the core does not know `GraphSession` exists. A protocol does not know
  its conformers either way, and the exemption cost the per-hexagon port
  declaration that the typealias is.)*

- **`GraphSession` conforms to all three, and no port has an associated type.**
  Every type they name is concrete, so a pane is
  `struct DiagramPane<Session: ForEditAGraphVisually>` and never names
  `AppPorts` or a version store. Always a generic parameter, never `any`.

- **`origin` is not on the visual port.** The editor reads it once, to seed an
  inline edit, so the port carries `label(of:)` and nothing else. `origin`
  stays public on the concrete `GraphSession` for tests and
  diffing. *(Reversed 2026-08-06; `origin` was originally on the port.)*

- **`undo`/`redo` belong to `ForManageADocument`, and a pane that wants ⌘Z holds
  that port too.** History is one unified stack over commands and text edits
  ([0006](./0006-undo-redo-history.md)), so ⌘Z in the text pane can undo a
  gesture made in the diagram; a pane-local undo would misdescribe the stack.

- **The shell holds nothing.** It is layout. Each component obtains the session
  itself, so no type needs the union of the three ports. A shell that passed the
  session down would have to satisfy every constraint its children do.

- **One driven port announces changes: `documentChanged()`, with no payload.**
  The three readers want different things — `exportVGL()`, `render(darkMode:)`,
  `canUndo`/`canRedo` — so anything carried would serve one of three. Each pulls
  what it needs from the port it holds; nothing caches, so nothing goes stale.
  Fanning the announcement out to several components is the adapter's job, since
  knowing the panes is what makes it an adapter.

- **Not every public member belongs to a port.** `currentVersion`, `diff` and
  the diff helpers are an inspection surface, not an editing one, and stay on
  the concrete class. A port is a contract, not a summary of a class.

### Named commands

- **The port names each command.** `toggleFolding(of:)`,
  `addSuccessor(from:using:)`, `split(_:with:)` and the rest; no catalogue
  remains. An adapter can no longer invoke a command it does not understand, and
  that is the point: what it gains is arguments the compiler checks and a
  refusal it cannot ignore.
- **A named call refuses; a menu may shrug.** A menu answering "unavailable" for
  a stale click is right. A caller that named both its command and its target
  has said something wrong, so the named methods throw.
- **The adapter asks before it calls.** A command never calls the UI. The
  adapter asks the domain's candidate queries what a command would need, holds
  the conversation itself (`EditorCore`'s `Conversation`), and makes one call
  with every argument resolved. `GraphSession` holds no pending command.
- **The adapter composes the menu.** `EditorCore.commands(on:)` lists what each
  element kind offers and in what order; `title(of:on:availability:in:)` names
  them. Menu composition and menu text are presentation.
- **The domain still decides what may run.** `availability(of:on:in:)` derives
  every answer from a candidate query the port already offers, and every list an
  adapter shows is built by the domain, titles included. The adapter *displays* a
  notation fact and *invokes* a domain operation; it never computes one.
- **The graph edits belong to the graph.** `reversing`, `splitting`,
  `addingRelated`, `connecting` and `retyping` are `VGraph` methods. A session
  decides whether an operation may run and records the result; it has no business
  knowing about `itemOrder` or minting unknown edge types.
- **`changeType` keeps a conversation, and only it.** Retyping asks once per edge
  the new type leaves ambiguous, and how many that is depends on the type just
  chosen. `ambiguousEdges(ifRetyping:to:)` reports them in the order the answers
  are consumed, so the order is part of the contract.
- **The typed values are what a command is made of.** `VCommandOption`,
  `VCommandID` and `VAvailability`: an option list the domain fills, an id that
  is a type, and an availability that says *why* not.

### What a command that adds a node offers and creates

- **Candidates are edge types**, not node types: a successor's offered set is the
  edge types leaving the source's type, and the new node's type is the edge
  type's far end (`VCandidate`).
- **Breaking the notation is a second step**, routed through
  `ensureUnknownEdgeType(from:to:)`, which registers the type, renders it bold red
  and raises a quality warning. `add(edge:)` hard-validates endpoint types, so
  this is the only way to break a notation, and a break is never silent.
- **Whether a new node opens for its label is derived, not declared**:
  `hasUserText(nodeType:)` reads attributes already on the OriginGraph, so it
  needs no display-pipeline run. The label is typed in an inline edit
  ([0009](./0009-inline-label-editing.md)).
- **New node ids are a type-prefixed counter** (`concept_1`), first free index
  across the shared keyspace; the new node inherits `group(of: source)`; the edge
  is created unlabelled.

## Alternatives considered

- **One port, `ForEditAGraph`.** Rejected once the panes were seen to be
  independently mountable: a single port lets the diagram pane call
  `textEdited(vgl:)`, the precise thing the split exists to forbid.
- **Four ports, with undo/redo in a cross-cutting `ForUndoChanges`.** Honest —
  undo genuinely is cross-cutting — but rejected for one fewer file, and because
  a pane holding `ForManageADocument` already carries the right admission.
- **A port per pane, each declaring its own undo/redo.** Two declarations of one
  stack, and the first place they would drift.
- **A port per command**, the way the Clean Architecture literature reads
  interface segregation. *(Added 2026-08-15.)* It counts ports by operation
  where this codebase counts them by actor. The candidate queries are not use
  cases and would have to be parcelled out among the commands they inform, while
  `EditorCore.menu(for:in:notationBreak:)` builds one menu from most of them and
  would need the union back — and since a port is a generic parameter, that
  union is either a dozen composed constraints or an `AppPorts`-shaped bundle:
  the port again, under a longer name. See `docs/hexagonal-architecture.md`.
- **`documentChanged(vgl:)`.** Bakes "VGL is the currency" into a notification a
  graphical editor does not care about. Rejected for privileging one reader.
- **A reason enum on the notification** (`.textEdited`, `.commandApplied`,
  `.historyMoved`). Deferred, not rejected: the optimisation to reach for when a
  wasted Graphviz relayout starts to hurt.
- **A list of observers on the session.** Not buildable —
  `[any ForObserveDocumentChanges]` is the existential this codebase is built
  around not having.
- **Folding the session's state into `VGraphApplication`.** It is a struct
  composing pure functions, and the Obsidian and VSCode plugins depend on that
  path staying stateless.
- **Extracting the ports before building `connect`.** It would design three
  protocols against one imagined consumer. Extraction from a concrete class is
  mechanical, and the design gets better with a second real caller.
- **An inbound "ask the user" port called from inside a command.** The natural
  expression of "the command owns the conversation", and not buildable
  synchronously (see Context).
- **The catalogue with stateless replay** — what was built first. Nothing held
  partial state and history was recorded once, on `.done`. Removed because every
  question was answerable only by running the command.
- **Keeping the catalogue and typing its payload**, leaving `attempt`. Genuinely
  good, and shipped first. Rejected as an end state for the same reason: it
  forces the replay loop and the four-case enum.
- **A `menu(at:)` the domain still describes.** Keeps titles and ordering in
  `VGraph` and a thirteenth command free. Rejected because `VAction` plus a
  per-kind registry *is* the catalogue under another name, and because UI text in
  a headless engine cannot be localised.
- **An enum of commands with typed payloads.** Embedded-legal and typed, but a
  closed set: adding a case breaks every exhaustive switch, and a generic menu
  still could not construct one from an id it never read.
- **Per-command `can…` queries instead of `availability(of:on:in:)`.** ~11
  near-identical members; all three notation-breakable commands reduce to "the
  notation left no candidate", which is why they read alike.
- **Flat declared parameters** — every input listed up front, one form. The label
  prompt *depends* on the type chosen: junctors and `EvaporatingCloud.conflict`
  display no label, so a flat form would show a text box that does nothing.
- **Candidates as node types** (the intuitive framing). Causal Loop Diagram has
  one node type and two edge types between it, so a node-type picker cannot
  express "add a stock this one reduces".
- **Candidates as raw edge types.** Correct everywhere, but edge type ids are not
  written for people.
- **`isJunctor` as the label signal.** `EvaporatingCloud.conflict` is icon-only
  but not a junctor, so it would be prompted for a label it can never display.
- **Slugging the label into the node id.** CRT and ConceptMap labels are
  sentences, and the id goes stale the moment the label is edited.
- **`GraphSession` holding the pending command.** The natural home for state, but
  it adds a lifecycle that collides with text edits, undo and re-targeting.

## Consequences

- **The ports constrain nothing in the WASM editor yet.** It still reads a
  module global, so the value is banked against a second adapter that does not
  exist. That is the bet, and the reason this is sequenced after a feature.
- **Every future `GraphSession` method needs a port decision** — one of the
  three, or none. A small tax, and the point: a member that fits no port is a
  member no adapter should have been calling.
- **A command costs work in every adapter** — a domain method, an availability
  case, a menu entry, and whatever UI it needs. With one adapter this is the
  trade we wanted; with three it would not be.
- **`EditorCore.commands(on:)` looks like something that should be data-driven,
  and must not be.** That switch *is* the decision. Making the domain own the
  list again rebuilds the catalogue.
- **A payload-free announcement re-does work.** A history-flag change re-renders
  the diagram, and Graphviz layout is the expensive step. The measured fix is
  the deferred reason enum.
- **Two bugs the migration exposed were in the old shape, not the new one.**
  `addSuccessor` conflated "this type leads nowhere" with "the notation forbids
  it", so ⌥ could not reach "Other type…" on a terminal node type — a `Bool`
  guard could not tell the two apart. And a command that changed nothing still
  cut an undo step, so opening a rename and pressing Escape left one behind.
- **The menu is testable.** `GoldenMenuTest` pins every title, order and greyed
  state; `MenuAgreesWithExecutionTest` pins that a command the menu offers will
  actually run.
