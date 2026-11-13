# 36. Releases stay on the maintainer's machine

Date: 2026-11-08 (revised 2026-11-13)

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

`just plugins-release` only bumps: each consumer's `release.sh --bump-only`
writes its version and builds nothing, because `just release` builds and tests
what ships, from the merged bump, and an earlier build would be thrown away.
Every engine build records the commit it built from and the wasm's hash in
`website/Package/VGRAPH_BUILD` (`scripts/record-engine-build.sh`, run by
`build-wasm.sh`), because that folder is not tracked and each build replaces it.

The engine ships inside both plugins, so a release must say which source it came
from. `publish-plugins` names the recorded commit in both releases, and refuses
when it cannot fetch `origin/main`, when VGraph has uncommitted changes, when the
build was made from uncommitted changes or from a commit not on `origin/main`,
when the engine sources changed between that commit and HEAD, or when either
plugin's wasm is not the recorded one. A version-bump commit after the build is
expected and allowed.

GitHub only checks. VGraph's CI builds the optimized engine on every change, and
each plugin's CI builds against VGraph's `main` from the ref it checks out
(`scripts/ci-engine.sh`, inside the container named by that ref's
`.swift-version`), so an engine change that breaks a plugin shows before a release
rather than during one, and a Swift bump in VGraph needs no change in the plugins.

GitHub also attests, which Obsidian's directory review looks for. When an Obsidian
plugin release is published, a workflow in that repository rebuilds the tag,
checks the result is byte-identical to the released `main.js` and `styles.css`,
and attests its own build. It can write attestations but not publish, push or
create a release, so the release itself still comes only from the maintainer's
machine. This depends on the bundle being reproducible, which is why it does not
depend on the Node version that builds it.

## Consequences

The version bump in VGraph (`plugins.json`, `vgraph-mcp-node`) reaches `main`
through a PR like any other change, because `main` takes no direct pushes.
`plugins-release` commits it on `release/<version>` and opens that PR. Each
plugin's bump stays uncommitted until `publish-plugins` commits it with the
engine it ships, so a plugin's release is one commit.

`publish-plugins` pushes the `.vsix` to the VS Code Marketplace after both GitHub
releases when a credential is reachable, and otherwise says how to upload it by
hand: the Marketplace may have no automated credential.

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
