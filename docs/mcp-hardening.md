# Hardening the hosted MCP endpoint

`mcp.vithanco.com` is open to anyone on purpose (see `SECURITY.md`), so what a
request may cost is bounded in code, in one place: `MCPLimits`.

## Why the input is bounded and not the render

Graphviz layout runs in-process and cannot be cancelled. A deadline can only
abandon the work, which keeps burning CPU, so the worst case is kept short by
refusing big input before layout: body size at the HTTP layer, then length,
nodes, edges and views once parsed. The 120 s request deadline is the backstop
and sits below Cloud Run's `--timeout` so the client gets our 504.

## Measurements behind the concurrency numbers

Release build of `vgraph-mcp-http` on a 10-core Mac (arm64), not the 1 GiB / 1 CPU
Linux container, so treat them as relative. Peak resident memory of the server
plus its `rsvg-convert` children, one ConceptMap tool call, N at once with
distinct JSON-RPC ids:

| Document | 1 at once | 4 at once | 8 at once | Wall, 8 at once |
|---|---|---|---|---|
| 20 nodes, 25 edges | 43 MB | 105 MB | 133 MB | 0.3 s |
| 150 nodes, 300 edges | 74 MB | 236 MB | 265 MB | 1.0 s |
| 250 nodes, 450 edges | 136 MB | 336 MB | 362 MB | 1.4 s |
| 350 nodes, 700 edges | 191 MB | 439 MB | 488 MB | 2.0 s |
| 100 nodes, 8 views | 212 MB | 361 MB | 456 MB | 5.5 s |

- One `rsvg-convert` peaks at about 119 MB at the 25 megapixel cap, whatever the
  shape (5000 x 5000, 25000 x 1000 and 32000 x 780 px all gave 119 MB), so four
  at once cost about 480 MB. The gate held the children to four with eight
  requests in flight.
- Layout is CPU-bound, so requests in flight share one CPU: eight views-heavy
  requests took 5.5 s, a few seconds each alone. Four in flight stay far inside
  the 120 s deadline.
- **Not explained:** the server's resident memory between runs grew from 9 MB to
  247 MB over about 45 renders and did not come back. That may be allocator
  retention, not a leak, and Linux's allocator behaves differently. Watch the
  instance memory metric after the first deploy; at four in flight and a 1 GiB
  instance the headroom is roughly 700 MB after the children, but a growing base
  eats it.

So `--concurrency=4` and four PNG conversions at a time stand. Raise them only
with a Linux measurement in the real image.

## Found while measuring

- **Identical JSON-RPC ids hang.** The SDK's stateless transport keys a waiting
  response by the request `id`. Two overlapping requests with the same id (two
  clients that both start counting at 1) overwrite each other, and the first is
  never answered. The request deadline now ends it with a 504 after 120 s, but
  the cost is a held connection. Known upstream as
  modelcontextprotocol/swift-sdk#254 and swift-sdk#265, fixed by swift-sdk#298. We wait
  for that release rather than rewrite ids ourselves: a rewrite has to change
  only the top-level `id`, since re-encoding the body alters numbers in tool
  arguments and results. `RequestIDTests` marks the hang as a known issue and
  starts failing once a fixed SDK is pinned.
- **A diagram at the node and edge limits cannot become a PNG.** 500 nodes and
  1000 edges in a chain make an SVG whose bitmap is wider than the
  32767 pixels `rsvg-convert` allows, so the tool reported a PNG failure. The pixel
  cap bounded the area, not the longest side. Fixed: the zoom now also respects
  that side limit.
- **`--dpi-x/-y` does not scale our SVG.** VGraph's SVG sizes are plain pixels
  (`width="276.74"`), and rsvg-convert ignores dpi for pixel sizes: 144 dpi gives
  the SVG's own size, same as 72. Scaling down needs `--zoom` (or `--width`). The
  first version of the pixel cap scaled through dpi and so never took effect;
  it now passes `--zoom`, and the dpi flags are gone (OLD-253: a Linux rsvg and
  resvg-wasm agree to within about 1% of pixels, so rsvg-convert stays).

## Maintainer notes

Kill switch, stops public access at once and is reversible:

```
gcloud run services remove-iam-policy-binding vgraph-mcp --member=allUsers --role=roles/run.invoker --region europe-west1
```

Still to confirm in the console: a budget alert, and the Cloud Logging
retention for the service.
