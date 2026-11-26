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
notation-specific check has a document that breaks it, and a test requires it
to fire, so a published rule cannot outlive its check unnoticed.

## Consequences

- Wording is the engine's, not the page's. Bound sentences read mechanically
  ("A Plus has at most 1 incoming "plus_first_operand" edge."); a hand-written
  sentence per bound is deferred until one reads badly enough to need it.
- A user-defined notation names its checks, so their rules exist, but such a
  notation has no self-description yet to list them in.
