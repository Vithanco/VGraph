# Releasing

An **engine consumer** bundles the VGraph engine and carries the shared version
number: everything listed in `plugins.json`, today the Obsidian plugin, the VS
Code extension and the npm MCP host (`vgraph-mcp-node`). A **release** ships
every engine consumer at one version, so a version number names one engine build
wherever it is quoted. The website and Cloud Run run the engine too but have no
version; updating only them is a deploy, not a release.

Releases run on the maintainer's machine with the maintainer's own logins;
GitHub only checks. Why: [ADR 0036](./adr/0036-releases-stay-on-the-maintainers-machine.md).

## Before the first release

- `export VITHANCO_MAINTAINER=1` in the shell that publishes.
- `just plugins-setup`, and both plugin checkouts on `main`.
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
(`plugins.json`, `vgraph-mcp-node`) is committed on `release/<version>` and
opened as a PR, because `main` takes no direct pushes. Each plugin's half stays
uncommitted in its checkout until it is published.

Merge the PR once CI is green, then:

```bash
git switch main && git pull
just publish-all
```

`publish-all` runs `just release` (the optimized engine, both plugins, the
`.vsix`), asks you to type `publish`, then
tags VGraph and ships the plugins (tag, push and GitHub release each), npm and
the MCP Registry, the website, Cloud Run, and the Marketplace when a token is
found.

`just release` runs the tests itself only when CI has not passed on the commit
(`just release full` runs them anyway); why: ADR 0036.

VGraph's tag goes on the commit that built the engine, not on `main`'s tip, so
a Swift package that depends on a version gets the engine the plugins ship.

The plugins' bump commits go straight to their `main`, not through a PR: they
hold only version fields and the engine just tested, and each plugin's CI checks
`main` after the push.

## When a release stops halfway

Run `just publish-all` again. It skips `just release` while nothing that ships
has changed since it passed, the plugins when they carry the version, and npm and
the MCP Registry when both do. It redeploys the website and Cloud Run, which is
harmless. The registry publish retries on its own, because the registry stalls
now and then.
To finish one place by hand, run its recipe: `publish-plugins`,
`publish-mcp-node`, `publish-website`, `publish-cloud-run`,
`publish-vscode-marketplace`.

Every recipe that ships the engine refuses a VGraph checkout with uncommitted
changes or a commit not on `origin/main`, so what ships is always on `main`.
Generated files such as `vgraph-mcp-node/tools.json` cannot be what makes it
uncommitted: CI fails a pull request that leaves one stale, and `just regen`
refreshes them.
