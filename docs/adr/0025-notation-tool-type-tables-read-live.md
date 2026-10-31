# 25. Read node/edge type tables live, not generated or duplicated

Date: 2026-09-25

## Status

Accepted. Resolves OLD-137 with a narrower scope than that issue proposed.

## Context

OLD-137 proposed generating a "spine" (purpose, when-to-use, node/edge type
tables) for `VGraphTool.descriptionBody` from `NotationEntry` via
`NotationMarkdown.render`, and shrinking `VGraphTool` to `{name, errorNoun,
notationName, vglParameterDescription, workedExample, rules}`, ahead of twelve
more `create_*` tools.

Measured against the four live tools (CLD, IBIS, ConceptMap, Timeline), the
claimed duplication mostly isn't there. `purposeSentence` and `entry.purpose`
are different texts for different audiences — one written for a model
deciding whether to call the tool, the other for notation-page prose — not
copies of each other. The node/edge type bullet lists are the only thing
that's actually a copy of `NotationEntry` data, and they're a small fraction
of each `descriptionBody` (~10 of CLD's ~125 lines). The rest — VGL syntax,
worked example, rules, and notation-specific mechanism explanations such as
Timeline's `alignGroup` — has no equivalent in `NotationEntry` and cannot be
generated from it.

The one real risk: a node or edge type added to a `NotationDeclaration` and
never added to the matching tool's hand-typed list, silently leaving a model
unable to produce that type through the tool.

## Decision

Stop hand-typing node/edge type bullet lists in `descriptionBody`. Read them
from `entry.nodeTypeDefinitions` / `entry.edgeTypeDefinitions` at
description-build time instead, through a small tool-facing renderer — narrower
than the page-oriented `NotationMarkdown.render`, with no title, tagline, or
heading-level collision to reconcile against the tool's own framing sentence
and hand-written `##` sections.

Everything else — `purposeSentence`, the VGL syntax walkthrough, the worked
example, the rules, and any mechanism explanation — stays exactly as
hand-written as it is today. `VGraphTool`'s protocol is unchanged.

Considered and rejected:

- **Generate the full spine (purpose + when-to-use + type tables) and shrink
  the protocol**, as OLD-137 proposed. Targets the wrong-sized piece of the
  problem: purpose and when-to-use aren't actually duplicated, and the bulk of
  each `descriptionBody` has no source in `NotationEntry` to generate from.
  Also forces embedding `NotationMarkdown.render`'s page-shaped output into a
  prompt that already has its own framing and its own headings — a formatting
  collision the issue left unresolved.
- **Keep hand-typing, add a parity test** asserting every declared type id
  appears in `descriptionBody`. Closes the risk for a reviewer, not for the
  model: an MCP client reads `Tool.description` once, up front, and a passing
  test doesn't put a missing fact into that text. Reading live does.
- **A new dedicated repository/module for notation content.**
  `NotationRegistry`/`NotationEntry` already is that repository for type
  facts. A second one would just be a second thing that needs to agree with
  the first — the opposite of removing drift.

## Consequences

- No protocol change and no migration ahead of the twelve new `create_*`
  tools — each still hand-writes its own purpose sentence, syntax, worked
  example, and rules, and gets its type table for free from whatever it
  declares.
- Does not touch OLD-121 (whether to build `vgraph-cli notation-page <Id>` for
  the website). That question is about generating the *whole* page from
  `NotationMarkdown.render`; this decision only reads two of `NotationEntry`'s
  fields inline into an otherwise hand-written string, and shares no machinery
  worth reconciling between the two.
- If a future notation's tool prompt needs per-type detail `NotationEntry`
  doesn't carry (CLD's hand-typed "Examples: Population, Revenue…" has no home
  in `NodeTypeDefinition.description` today), that stays a hand-written
  addition to that tool's prose, same as today — not a reason to reopen this
  decision.
