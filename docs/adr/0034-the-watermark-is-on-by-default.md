# 34. The watermark is on by default

Date: 2026-10-21

## Status

Accepted. Decided in OLD-260.

## Context

Every exported diagram carries a semi-transparent Vithanco mark and
"VITHANCO.COM" in a free corner. It was added as a branding credit, with the
graph attribute `watermark` (default `true`) to turn it off. Nothing recorded
why it defaults to on, and a fork's output shows the mark unless it changes that.

## Decision

It stays on by default. Every export credits the project, and anyone who does
not want it writes `watermark: false`, documented in the
[VGL Guide](../VGL_GUIDE.md#attributes). The mark is the project's artwork, all
rights reserved (see `graphics/README.md`); leaving it in an export is allowed,
using it as another product's mark is not.

## Considered and rejected

Opt-in. It would change every snapshot and shipped example, and the project would
lose the credit that makes exports traceable.
