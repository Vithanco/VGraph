# 6. Undo/redo history in GraphSession

Date: 2026-07-24

## Status

Accepted. Extends [ADR-0002](0002-origingraph-graphsession-vcommands.md).
Renamed since — `edit(vgl:)` is now `textEdited(vgl:)` and `sealTextRun()` is
`textEditingEnded()` — but history itself is unchanged: one stack, one cursor,
VGL snapshots.

## Context

ADR-0002 gave the GraphSession a single mutable OriginGraph with no memory: once
a command ran, or the user edited the text, the previous state was gone.

The naive framing — "each VCommand pushes a new state onto a stack" — misses
three things:

1. **Commands are not the only mutation.** Editing the VGL text also replaces the
   OriginGraph, so a command-only history would skip everything typed between
   commands.
2. **There are two representations of one document.** Within an interaction the
   OriginGraph leads and the VGL text is derived from it. They must never
   disagree after an undo.
3. **The textarea already owns Cmd-Z.** A second, graph-level Cmd-Z would fight
   the native one depending on focus.

## Decision

- **A state is a VGL text string.** History is a stack of settled VGL snapshots
  with a cursor, and the OriginGraph is always semantically
  `parse(history[cursor])`, so restoring is a reparse. Storing text keeps the
  user's *literal* typed text — comments and formatting included — for text-edit
  entries, and reuses ADR-0002's export→reparse invariant for command entries.

- **One unified stack over commands *and* text edits.** Undo reverts whatever
  most recently changed the document, structural or textual.

- **Text edits coalesce into one step per typing burst.** A continuous run of
  debounced edits updates the top entry in place. A run is **sealed** — the next
  edit starts a fresh entry — by a command, a document load, an undo/redo, or
  textarea blur. Otherwise undo granularity is one entry per 400 ms keystroke
  batch.

- **The history layer owns Cmd-Z / Cmd-⇧-Z / Cmd-Y globally.** The keydown
  handler `preventDefault()`s, so this stack is the single undo model in both
  panes and the textarea's finer-grained native text undo is replaced. A
  deliberate trade: consistency over character-level text undo.

- **A document load resets history.** Host push, the Examples dropdown and the
  `?vgl=` seed each start a new baseline; undo cannot cross into a previous
  document. This split the overloaded `load(vgl:)` into `replaceDocument(vgl:)`
  (new document, history reset) and `textEdited(vgl:)` (typing, coalesced).

- **Bounded depth.** `maxHistory = 100`. VGL snapshots are small, so this is
  ample while bounding a long session.

`undo()`/`redo()` return the restored VGL so the driving adapter can update its
text surface; `apply(...)` pushes a snapshot and seals the run.

## Alternatives considered

- **Snapshot the `VGraph` value instead of text.** Cheap, and no reparse on undo.
  Rejected because text-edit entries would then re-derive their text via
  `exportVGL()` and lose the user's comments and formatting. The reparse cost is
  negligible at editor scale.
- **Command-only history; leave text to native undo.** Undo would skip over
  typing, and two undo models would coexist by focus.
- **One entry per debounced reparse (no coalescing).** A long edit becomes dozens
  of tiny undo steps.
- **Keep native textarea undo inside the textarea.** Rejected for v1 in favour of
  one consistent model; revisit if character-level text undo is missed.

## Consequences

- **`load(vgl:)` is gone.** Every call site had to pick an intent, which is a
  strictly clearer API even apart from undo.
- **The keydown binding cannot be a `JSClosure`** (ADR-0001's constraint), so it
  rides ElementaryUI's `_onEvent` seam with a custom `KeyDownConfig` — the
  built-in `KeyboardEvent` exposes only `.key`, with no modifiers and no
  `preventDefault`.
- **Focus is moved into the editor after a context-menu command**, so the
  root-bound handler receives the next Cmd-Z; a right-click otherwise leaves
  focus on `body`, whose keydown does not bubble into the editor subtree.
- **Comment/format fidelity is unchanged from ADR-0002.** Command-generated
  entries are re-exported VGL; text-edit entries are stored verbatim.
- **The pure engine is untouched**, so the plugins inherit undo/redo on their
  next WASM rebuild with no host JS.
