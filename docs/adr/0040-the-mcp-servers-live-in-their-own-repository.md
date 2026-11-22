# 40. The MCP servers live in their own repository

Date: 2026-11-22

## Status

Accepted. Amends [0036](./0036-releases-stay-on-the-maintainers-machine.md).

## Context

The MCP servers (stdio, the HTTP server behind `mcp.vithanco.com`, and the npm
host) mostly changed on their own, and they brought swift-nio and the MCP SDK into
VGraph's `Package.swift`, which every package depending on VGraph resolves. The
npm host was already an engine consumer like the plugins, but the only one
living inside VGraph.

## Decision

They move to `Vithanco/vgraph-mcp`, which `just plugins-setup` clones into
`vgraph-mcp/`, as it does the plugins. The Swift servers and the npm host move
together, because the host's `tools.json` is generated from the Swift server.

Its `Package.swift` depends on VGraph as `.package(path: "..")`, not by URL. A
release ships every consumer from one engine build, and VGraph is tagged only
when it publishes, after that build; a URL dependency could not name the engine
being released. VGraph exports its `TestSupport` target as `VGraphTestSupport`,
so the servers' tests use the same wiring as VGraph's.

## Consequences

`vgraph-mcp` does not build on its own, and the folder around it must be called
`VGraph`, because SwiftPM names a path dependency after its folder. Its CI checks
out VGraph and puts the repository inside it.

VGraph's justfile stays the one front door. `just mcp <recipe>` runs a recipe of
`vgraph-mcp/justfile`. `just release` builds the servers and the npm host, and
`just publish-all` runs `just mcp publish`, which commits and tags its version
bump as `publish-plugins` does the plugins'. Its recipes that ship the engine run
VGraph's `_require-vgraph-main` first.

VGraph's CI no longer sees a change that breaks the servers. `just test` runs
their tests when the checkout is there, and their own CI builds against VGraph's
`main`, as the plugins' does.

The Cloud Run image is built from a staged context that holds the tracked
sources of both repositories, laid out as in a checkout.

Dependabot cannot update `vgraph-mcp`'s Swift pins: it has no VGraph around it.

## Alternatives considered

- **A URL dependency pinned to a VGraph tag.** The repository would build alone,
  but `publish-all` would have to tag VGraph before building what it releases.
- **Moving only the npm host.** `tools.json` would then be generated across
  repositories.
