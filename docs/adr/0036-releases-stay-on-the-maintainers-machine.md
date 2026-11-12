# 36. Releases stay on the maintainer's machine

Date: 2026-11-08 (revised 2026-11-12)

## Status

Accepted. Absorbs 0035, which had a VGraph tag start each plugin's build on
GitHub and was replaced before any release used it.

## Context

The plugins live in their own repositories and do not rebuild when the engine
changes. GitHub offers no way for one repository's workflow to start another's
without a token that can write to the other repository, and VGraph keeps no such
secret in CI: it is public. Finishing a release on GitHub would also need either
publish credentials in public repositories or OIDC trust granted to them. Neither
is wanted.

## Decision

A release is built, tagged and published from the maintainer's machine, with the
maintainer's own credentials: `just plugins-release`, `just release`, then
`just publish-all` or the `publish-*` recipes it runs. No repository holds a
publish or cross-repository credential.

`just plugins-release` builds the optimized engine itself before bumping, since
each plugin's `release.sh` copies `website/Package` in and a fresh checkout has
none.

`publish-plugins` refuses a VGraph checkout with uncommitted changes or a HEAD
that is not on `origin/main`, and both releases name the VGraph commit. The
engine ships inside both plugins, so a release must say which source it came from.

GitHub only checks. VGraph's CI builds the optimized engine on every change, and
each plugin's CI builds against VGraph's `main` from the ref it checks out
(`scripts/ci-engine.sh`, inside the container named by that ref's
`.swift-version`), so an engine change that breaks a plugin shows before a release
rather than during one, and a Swift bump in VGraph needs no change in the plugins.

## Consequences

The version bump in VGraph (`plugins.json`, `vgraph-mcp-node`) reaches `main`
through a PR like any other change, because `main` takes no direct pushes.

`publish-plugins` refuses a plugin checkout that is not on `main`: it tags and
pushes whatever is checked out.

The Obsidian plugin commits its copy of the engine, the wasm and its `vendor/Package`
glue, because Obsidian's directory builds that repository on its own.
`publish-plugins` commits both under the release tag so they cannot disagree.

An engine build costs minutes on each new VGraph ref in plugin CI, and is cached
by commit.

## Alternatives considered

- **A `v*` tag pushed by `just release-engine` starts each plugin's workflow**
  through the maintainer's `gh` login; the workflow builds the engine from the
  tag, builds the plugin and opens a bump PR (0035). Rejected because it left the
  release half on GitHub and half local, and a tag pushed by hand started nothing.
- **Scheduled polling in each plugin for new VGraph tags.** Rejected because
  GitHub disables schedules after 60 days without activity, which quiet plugin
  repositories can reach.
