# 35. A release is a tag started from the maintainer's machine

Date: 2026-11-06

## Status

Superseded by [0036](./0036-releases-stay-on-the-maintainers-machine.md) before
any release used it.

## Context

The plugins live in their own repositories and did not rebuild when the engine
changed. GitHub offers no way for one repository's workflow to start another's
without a token that can write to the other repository, and VGraph keeps no such
secret in CI: it is public, and releases stay on the maintainer's machine.

## Decision

A VGraph release is a `v*` tag pushed by `just release-engine`. The same recipe
uses the maintainer's own `gh` login to start each plugin's workflow. That workflow
builds the engine from the tag, builds the plugin, and opens a bump PR. Publishing
stays with `just publish-plugins`.

Plugin CI runs the engine build from the ref it checks out (`scripts/ci-engine.sh`,
inside the container named by that ref's `.swift-version`), so a Swift bump in VGraph
needs no change in the plugin repositories.

## Consequences

A tag pushed by hand starts nothing. Scheduled polling would catch one, but GitHub
disables schedules after 60 days without activity, which quiet plugin repositories
can reach.

An engine build costs minutes on each new VGraph ref, and is cached by commit. Plugin
PRs build against the latest tag rather than `main`, so they keep the same cache
between releases.
