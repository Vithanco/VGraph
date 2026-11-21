# 39. Copy and paste as VGL fragments

Date: 2026-11-21

## Status

Accepted. Amends [0006](./0006-undo-redo-history.md) and
[0018](./0018-selection-and-group-creation.md).

## Context

A [[Selection]] gave the diagram something to copy. The graph is derived from
text, so the text is the obvious thing to put on the clipboard: it is already the
document's format, and anything that pastes text can carry it.

## Decision

**A copy is a [[Fragment]]**: the body statements of the [[Excerpt]], with no
header and no `vnotation`. Pasting parses it into the document's context:

- a node or group type the notation lacks refuses the whole paste and names the
  types. Nothing is declared on the user's behalf (GLOSSARY *Declare*), so type
  definitions are not carried at all;
- edge types are inferred per pair, as in a document;
- a colliding id gets a suffix; ids that are free are kept;
- a statement at the fragment's top level that sets an attribute is refused, since
  the document's own values are not the paste's to set;
- the containment check (0032) judges everything pasted, at every depth, in
  the group it lands in. There is no ⌥ path.

The paste lands in the one selected group, or at the top level. It is one
[[Snapshot]], and what it pasted becomes the selection.

**Focus decides who answers ⌘C and ⌘V.** Diagram gestures and commands focus the
preview pane, not the textarea, so the clipboard events there are the graph's and
the source pane's own copy and paste stay untouched. 0018 rejected ⌘A for
fighting the textarea over a chord; moving focus is what avoids that fight here.
0006's ⌘Z still works, because its handler sits on the root that both panes are
inside.

**Its own driven port**, `ForExchangeAFragment`, not a member on
`ForExportAGraph`: Graphviz's `DotExporter` implements that one and has no use for
a fragment.

## Consequences

- After a diagram gesture, typing goes nowhere until the textarea is clicked.
- Paste reads `clipboardData` in the `paste` event: `navigator.clipboard.readText`
  returns a promise this build cannot await. The menu's Copy row writes through
  the async API, whose refusal it cannot see.
- The menu's Paste row (on blank canvas, and on a selection, landing where ⌘V
  would) exists only where the host binds `__vgraphReadClipboard`: the host
  reads the clipboard and hands the text back to `editorClipboardRead`. The
  browser asks first — a permission prompt in Chrome, a Paste bubble in Safari.
- A refused paste is silent in the editor, like every named command.
- Copying a selected group and pasting at once puts the duplicate inside it.
  Considered and kept: the rule for where a paste lands stays one rule.
