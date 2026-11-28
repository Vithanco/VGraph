# 41. Notations state the rules they check

Date: 2026-11-26

## Status

Accepted.

## Context

Readers of a notation's page, and assistants asking the MCP server about a
notation, could not learn which rules Vithanco holds a diagram to. The only
lists were hand-written on two website pages, and one had already fallen behind
its notation. A check was an anonymous function, so there was nothing to list
from.

## Decision

A [[Quality check]] is a value with a name and a one-sentence rule saying what
good looks like, beside the function that reports where a graph breaks it. A
check cannot be declared without its rule, and a parameterised check builds its
rule from its numbers. A notation's self-description lists its rules under
"What Vithanco checks": the checks it names, its own, where each detail type
belongs, and its [[Bound]]s, all generated. The checks every notation runs are
told once (`describe --common`), not per notation. A [[Metric]] judges nothing,
so it has no rule and is not listed.

The website inlines this text at build time instead of writing its own. Each
check a built-in notation runs has a [[Counterexample]], held by the notation
because it is written in the notation's own types: a document that breaks that
rule and no other. A test requires it to, so a published rule cannot outlive
its check unnoticed, and the website shows readers the same document, so what
they see flagged is what the test proved. A check no small document can break
states why instead of carrying one.

## Consequences

- Wording is the engine's, not the page's. Bound sentences are generated, so
  they read well only as far as the notation helps: an edge type can say what
  its far end is ("first operand"), and the limits on one type become one
  sentence ("A Plus has at most one first operand, one second operand and one
  result."). Without that, an edge is named by its type.
- The Markdown lists rules only, because assistants read it through the MCP
  server; `describe --format json` gives a page each rule with its
  counterexample, and the page builds its own links.
- A check a `vnotation` can name has no notation to hold its counterexample, so
  it breaks on a document kept in its test instead.
- A user-defined notation has no name outside the document that declares it,
  so it is described from that document (`describe --file`), and lists the
  rules of exactly the checks analysis runs on it.
