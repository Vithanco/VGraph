# Releasing

An **engine consumer** bundles the VGraph engine and carries the shared version
number: everything listed in `plugins.json`, today the Obsidian plugin, the VS
Code extension and the MCP servers (`vgraph-mcp`: the npm host, and the hosted
server on Cloud Run). A **release** ships
every engine consumer at one version, so a version number names one engine build
wherever it is quoted. The website and Cloud Run run the engine too but have no
version; updating only them is a deploy, not a release.

Releases run on the maintainer's machine with the maintainer's own logins;
GitHub only checks. Why: [ADR 0036](./adr/0036-releases-stay-on-the-maintainers-machine.md).

## Before the first release

- `export VITHANCO_MAINTAINER=1` in the shell that publishes.
- `just plugins-setup`, and the `obsidian-vithanco`, `vscode-vithanco` and
  `vgraph-mcp` checkouts on `main`.
- Logged in: `gh`, `npm` (2FA), `gcloud` (`gcloud auth login && gcloud auth configure-docker`).
- `mcp-publisher` with the signing key in `~/.config/mcp-publisher/` for the MCP Registry.
- The Publish CLI on `PATH` and the website checkout at `$VITHANCO_WEBSITE_DIR`
  (default `../VithancoWebsite`).
- Optional: a VS Code Marketplace token (`VSCE_PAT` or the `vscode-vsce`
  keychain entry). Without it, upload the `.vsix` by hand at the end.

## A release

```bash
git switch main && git pull
just plugins-release patch     # or minor, major, or an explicit version
```

This bumps every engine consumer and builds nothing. VGraph's half of the bump
(`plugins.json`) is committed and pushed straight to `main`: it holds only
version fields, and CI checks `main` after the push (`main`'s ruleset asks for a
PR, which the maintainer bypasses). Each consumer's half stays uncommitted in its
checkout until it is published.

It refuses to bump while a Dependabot PR is open in VGraph or any consumer, and
lists them: merge or close them first, or release anyway with
`IGNORE_DEPENDABOT=1 just plugins-release patch`. Then:

```bash
just publish-all
```

`publish-all` runs `just release` (the optimized engine, both plugins, the
`.vsix`, the MCP servers and the npm host), asks you to type `publish`, then
tags VGraph and ships the plugins (tag, push and GitHub release each), then
`just mcp publish` (tag and push `vgraph-mcp`, npm, the MCP Registry, Cloud Run),
the website, and the Marketplace when a token is found.

`just release` runs the tests itself only when CI has not passed on the commit
(`just release full` runs them anyway); why: ADR 0036.

VGraph's tag goes on the commit that built the engine, not on `main`'s tip, so
a Swift package that depends on a version gets the engine the plugins ship.

The consumers' bump commits go straight to their `main`, not through a PR: they
hold only version fields and the engine just tested, and each consumer's CI
checks `main` after the push.

## When a release stops halfway

Run `just publish-all` again. It skips `just release` while nothing that ships
has changed since it passed, the plugins when they carry the version, and
`vgraph-mcp`'s tag, npm and the MCP Registry when each does, and Cloud Build
when an image was already built from the same sources (its tag is their hash).
It redeploys the website and Cloud Run, which is harmless.

Nothing compiles twice. Every consumer ships the engine `just release` built:
the plugins and the npm host refuse any other (`scripts/check-engine-build.sh`). The registry publish retries on its own, because the registry stalls
now and then.
To finish one place by hand, run its recipe: `publish-plugins`,
`publish-website`, `publish-vscode-marketplace`, or in `vgraph-mcp`
`just mcp publish-node` and `just mcp publish-cloud-run`.

Every recipe that ships the engine refuses a VGraph checkout with uncommitted
changes or a commit not on `origin/main`, so what ships is always on `main`.
`vgraph-mcp`'s generated `tools.json` cannot be what makes a release stop:
its CI fails a pull request that leaves it stale, and `just mcp regen`
refreshes it.
