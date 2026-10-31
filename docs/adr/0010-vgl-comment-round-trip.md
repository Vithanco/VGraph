# 10. VGL comments survive the round trip

Date: 2026-07-27

## Status

Accepted.

## Context

The lexer consumed `//` to end-of-line and emitted no token, so comments never
reached the AST. `VGLExporter` regenerates VGL from the graph rather than editing
text, so every comment was gone the moment a document was exported.

Not a niche path: `GraphSession` re-exports the OriginGraph after every VCommand,
so one right-click rewrites the whole document. The OriginGraph's stated
round-trip invariant — "nothing is lost or added" — was simply false for any
document with a comment.

Measured over the 11 `.vgl` files in the repository, 113 comment lines: 98 sit
directly above a statement, 15 sit above one with a blank line between, and none
are trailing, in a header, before a closing brace, or inside a `vnotation` block.
The 15 are all one pattern — a `// ====` section banner introducing a run of
nodes — so a rule requiring a comment to be *directly* above its element would
silently drop exactly the comments that carry a document's structure.

Two properties of the attribute machinery constrain the encoding: `[String]`
attributes serialise with a naive comma split and no escaping, so a comment
containing a comma or `]` would be shredded; and all three
`AttributeExportFilter` entry points already skip anything not `.persistent`.

## Decision

**Comments are element attributes on the graph, node, edge and group, restored by
the exporter in `//` syntax.** They become ordinary domain data: they live in the
OriginGraph, ride through undo/redo and VCommands, and are deleted with the
element they describe.

- **Two slots per element** — `comment` for the leading run, `trailingComment`
  for the same-line one. Both `String`, joined by `\n`, safe by construction
  because a `//` comment cannot contain a newline.

- **Lines are stored verbatim, marker included**, so emission is a passthrough
  and `//` versus `// ` spacing survives.

- **The leading run is every contiguous comment-or-blank line above a
  statement**, back to the previous statement or the opening brace, **with blank
  lines trimmed at both ends**. Interior blanks are kept, so a banner and its
  sub-heading stay apart. Trimming the edges is what makes the round trip a fixed
  point: the exporter already emits a blank line before every group, and an
  untrimmed run would re-absorb and re-emit it, growing the file by one line per
  save.

- **Anchors are leading and same-line trailing only.** A comment before a closing
  brace, inside `[...]`, inside a `vnotation` block, or after the final `}` has no
  element and is dropped. A comment above the `vgraph` line belongs to the graph.

- **`[comment: "hello"]` is accepted as input**, re-exporting as a `// hello`
  line. It falls out of the attribute lookup for free and gives VGL-generating
  tools — the MCP tools build attribute lists, not text — a way to emit comments.

- **The attributes are `.persistent`**, excluded from the four generic emit sites
  through one shared `CommentAttributes` set rather than four hand-written lists,
  with a test asserting no export path produces a literal `comment:`. Persistence
  is what makes the input alias coherent — a kind meaning "not really an
  attribute" would contradict an attribute the user may write.
  `CommentAttributes` also owns the canonical form, applied as a value comes in,
  so the graph never holds a comment without its marker.

- **The lexer collects comments into a side list** and leaves the token stream
  untouched; the parser consults that list when it begins a statement. Comment
  tokens in the stream would require every `check`, `match`, `peek` and `advance`
  in `Parser` to hop over them.

- **Acceptance is idempotence plus survival**, not textual identity:
  `export(parse(x))` is a fixed point under a second pass, and every comment
  anchored to a surviving element reappears on that element.

## Alternatives considered

- **A trivia side-table on `VGraph`**, keyed by element id and position. Cannot
  collide with a user-written `comment:` and keeps comments out of the domain
  model. Rejected: it needs a new field every graph-copying path must carry, and
  it forecloses the `[comment: ...]` input alias.
- **A new `AttributeKind.trivia`.** Rejected as incoherent with comments being
  user-writable attributes; the shared exclusion set plus its test closes the
  same hole.
- **`[String]` for the leading run.** Rejected on the encoding above.
- **Lossless source patching** — keep the user's text as the artifact and have
  VCommands patch it surgically. Fixes comments, blank lines, statement order and
  formatting in one move, and would make `export(parse(x)) == x` reachable.
  Rejected as far larger than the problem: every VCommand would need a text-edit
  story, and the exporter would survive anyway for freshly built and imported
  graphs.
- **Restoring edges to their source group.** `GraphStructureTraverser` emits every
  edge at the end of the file, so a comment written above an edge inside a group
  reappears at the bottom. Rejected deliberately: edges are graph-level, and the
  nested source form is the anomaly, not the export.

## Consequences

- **Comments are semantic.** Visible to any attribute consumer — inspectors, MCP
  tools, future tooltips — and they land in the undo history. A feature, and a
  surface to watch: a comment is now something a command can read and rewrite.
- **A comment above a statement that moves, moves with it.** Export puts nodes
  before groups and all edges last. Restoration does not make the round trip
  faithful — it makes it non-destructive.
- **Group attribute lookup must read the group's own value**, not an inherited
  ancestor's, or a parent group's comment would be re-emitted on every child.
- **`comment` becomes reserved vocabulary in VGL.** A notation cannot later
  define an attribute by that name.
- **Comments outside the anchor rules are still dropped**, silently. Zero
  instances today; if they appear, this is where the rule to revisit is written.
- **The fixed-point criterion exposed two older export bugs**, both fixed here
  because the criterion cannot hold without them. `needsQuoting` decided by a
  blacklist and so wrote `8,4`, `1e5`, `8px`, `1.2.3` and `a//b` unquoted —
  values the lexer does not read back as one token; it now asks the lexer
  directly. And the four attribute emit sites iterated a dictionary, so a
  document reordered its own attributes between saves; they now sort by key.
