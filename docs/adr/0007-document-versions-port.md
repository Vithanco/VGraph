# 7. Document version history behind a port

Date: 2026-07-25

## Status

Accepted. Extends [ADR-0006](0006-undo-redo-history.md).

## Context

ADR-0006 gave `GraphSession` a private `[String]` undo stack capped at 100 — the
right first cut, but it hard-codes *where* history lives. The longer-term goal is
the **full** history of a document, **diffs** between versions (textual today,
semantic later), and eventually history backed by **git**: a local `.git` folder
on macOS, possibly with GitHub as a remote.

Git cannot live in the core. The WASM editor compiles under Embedded Swift;
there is no Swift git client that builds under Embedded, and libgit2 needs a
filesystem and networking the WASI reactor doesn't have wired up. But the core
doesn't need git — it needs *somewhere* to put VGL snapshots, which is what an
outbound port is for.

Folded in: the app, not the session, should be the composition root. The WASM
convenience `GraphSession.init(vgl:)` built a private `VGraphApplication` for
itself, which meant the editor held two separate app instances — one for
highlighting, one hidden inside the session.

## Decision

**`VForStoreDocumentVersions`**, re-exported to App as
`ForStoreDocumentVersions` — the same declaration-plus-typealias shape as every
other port, and a generic parameter rather than an existential.

- **A version is a VGL string, identified by an opaque `VersionRef`** carrying a
  monotonically increasing `number` (human-facing, never reused, even for
  versions a divergence abandons). It deliberately carries nothing else: an
  adapter with its own identity for a version (a git SHA) maps it to and from
  `number` internally rather than exposing a second identifier callers would have
  to know when to trust.
- **The data model is DAG-shaped; the navigation API stays linear.** Every
  version has a `parent` and `children`, so nothing blocks a future adapter from
  preserving real branches — but `record`, `amend`, `undo` and `redo` are the
  linear methods an editor needs today. Full branch/checkout navigation is
  additive later work.
- **Divergence is the adapter's call.** Recording after an undo invalidates redo
  either way, but whether the abandoned descendants are *dropped* (a stack) or
  *kept as a branch* (git) is left to the implementation.
- **`record` vs `amend`** mirror `git commit` vs `git commit --amend`: `record`
  adds a child of `current`, `amend` replaces `current`'s content without moving
  `parent`. This is what lets ADR-0006's text-edit coalescing survive the port
  unchanged — an open run calls `amend`, a sealed one calls `record`.

**Diff is not part of the port.** `TextDiff` is a pure function on two strings —
a stdlib-only line-based Myers diff, Embedded-safe by construction. Keeping it
off the port means every adapter gets diffing for free and diffing never depends
on git being present.

**`InMemoryVersionStore`** reproduces ADR-0006's exact stack semantics behind the
new port, and is the default: existing behaviour is unchanged, just relocated.

**App is the composition root.** `VGraphApplication` gains
`makeSession(vgl:versionStore:)`. The app builds and wires the session; a session
never builds its own app.

## Alternatives considered

- **Full branch/DAG navigation now** (`checkout(ref:)`, multi-child traversal).
  Nothing today needs it, and the linear API is a strict subset of what a
  DAG-preserving adapter can satisfy, so adding it later is additive.
- **Diff as part of the port**, so a git adapter could shell out to `git diff`.
  Rejected: it would make diffing depend on the adapter, defeating the point of a
  pure Embedded-safe diff that works identically everywhere, including inside the
  WASM binary with no adapter at all.
- **Keep history inside `GraphSession` and add git later some other way.**
  Without a port, a git adapter would have to live inside the Embedded core or
  the session would need `#if WASM` branches.

## Consequences

- `undo()`/`redo()` still return `String?` (the restored VGL) at the
  `GraphSession` level; the `VersionRef`-based port sits one layer below and is
  invisible to callers that only used the ADR-0006 API.
- Future git adapters — a local `.git` folder on macOS, a JS-bridged browser
  adapter over IndexedDB or the GitHub API — are host-only or JS-bridged targets
  conforming to this port. None of that needs to compile under Embedded, and none
  of it exists yet: this ADR only lands the seam.
- **The generic parameter this added was the warning sign.** It grew
  `GraphSession` to six parameters, accepted here as the cost of a new port; a
  seventh would have meant touching every signature again. The application ports
  are now bundled into `AppPorts`, so the next port costs one `associatedtype`.
  `VersionStore` stays separate: it is chosen per-session, not per-application.
