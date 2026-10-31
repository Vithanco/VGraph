# Security

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Report it privately, either way:

- on GitHub: **Security → Report a vulnerability** on this repository, or
- by email to klaus@vithanco.com.

Say what you found, how to reproduce it, and which version or commit you tried.
I aim to answer within seven days. If the report holds up, we agree on a date
for the fix and for telling everyone else, and you are credited in the release
notes if you wish.

## Supported versions

Fixes go into the latest release. The MCP server, the Obsidian plugin and the VS
Code extension share one version number and are released together.

## What is in scope

- **The engine:** the VGL parser and the SVG renderer. Untrusted VGL, for
  example from a shared note or a model's output, must not be able to inject
  markup or script into the SVG that comes out, or crash the host.
- **The hosts** around the engine: the local MCP server (`@vithanco/vgraph-mcp`),
  the Obsidian plugin and the VS Code extension, in how they treat untrusted VGL.
- **The hosted MCP server** at `mcp.vithanco.com`. It is open to anyone on
  purpose and does not check the `Origin` header, because its clients are
  assistants and not browsers. Ways to make it consume unbounded resources are in
  scope; please do not load-test it to prove the point, a description is enough.

## What the hosted server logs

Diagrams are not stored. The logs hold request metadata and warnings; a warning
may name a node, edge or type id, never a label, a note or a document.
`VGRAPH_LOG_LEVEL` (`error`, `warn`, `info`, `debug`) sets how much is written,
and the default is `warn`. At `debug` the Graphviz source of every render is
logged, titles and labels included, so only developers set it. Logs are kept for
30 days in Cloud Logging, then deleted.

Origin is not validated. The server is public and keeps no state or credentials,
so a browser request can reach nothing a direct request could not. There is no
per-client rate limit; the per-request bounds in `docs/mcp-hardening.md` cap what
one request costs. Both are revisited if the endpoint is abused.

## What is not

- Weaknesses in a dependency itself. Report those upstream, and tell me if they
  affect VGraph.
- Findings that need a user to paste hostile input into their own machine and
  then expect protection from it, such as a local command-line run on a file the
  user chose.
- Social engineering, and anything against accounts or infrastructure other than
  the software in this repository.
