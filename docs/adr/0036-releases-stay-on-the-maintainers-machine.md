# 36. Releases stay on the maintainer's machine

Date: 2026-11-08

## Status

Accepted. Supersedes [0035](./0035-a-release-is-a-tag-started-from-the-maintainers-machine.md).

## Context

0035 had a VGraph tag start each plugin's build on GitHub and open a bump PR there.
That left the release half on GitHub and half local, and finishing it on GitHub
would have needed either publish credentials in public repositories or OIDC
trust granted to them. Neither is wanted.

## Decision

A release is built, tagged and published from the maintainer's machine, with the
maintainer's own credentials: `just plugins-release`, `just release`, then
`just publish-all` or the `publish-*` recipes it runs. No repository holds a
publish or cross-repository credential.

GitHub only checks. VGraph's CI builds the optimized engine on every change, and
each plugin's CI builds against VGraph's `main`, so an engine change that breaks a
plugin shows before a release rather than during one.

## Consequences

The version bump in VGraph (`plugins.json`, `vgraph-mcp-node`) reaches `main`
through a PR like any other change, because `main` takes no direct pushes.

`publish-plugins` refuses a plugin checkout that is not on `main`: it tags and
pushes whatever is checked out.
