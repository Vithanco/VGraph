# Editor browser tests

Playwright tests for the editor in `VGraphWasm/VGraphEditor/`, driving the real
editor against the deployed `website/`. Two projects: `chromium` for the mouse
gestures, and `ipad` for `touch.spec.js`.

```bash
just test-editor                       # all of them
just test-editor 'getScreenCTM'        # -g pattern
```

Build first (`just wasm`) — they run against `website/`. `just test` does both.

## Why a real browser

The inline label editor (ADR-0009) is positioned from `getBoundingClientRect`,
and for edges from `getPointAtLength` + `getScreenCTM`. jsdom has none of those:
every client rect is zero and the SVG geometry APIs do not exist. A jsdom harness
would report the viewBox-origin bug `inline-edit-anchors.spec.js` pins as
passing.

The decision logic that needs no DOM lives in Swift and is unit tested there —
`SVGElementId` (VGraphSVG) and `VCommandOption.soleCandidate` (VGraph).

## Notes

- `known-defects.spec.js` holds `test.fail()` reproductions of open bugs. The
  marker fails the moment a bug is fixed, so the test gets promoted into its
  real suite rather than forgotten. Currently empty.
- Chromium is downloaded on first run (~95 MB); `just test-editor` handles it.
  The `ipad` project needs WebKit as well (~77 MB) — `npx playwright install
  webkit`. WebKit rather than a Chromium-with-touch emulation because the device
  this feature exists for runs Safari, and `touch-action` and the compatibility
  mouse events are exactly where the engines differ.
- Touch *events* in `touch.spec.js` are dispatched by hand (the `finger` helper).
  Playwright's own input is either a mouse — always `pointerType: "mouse"` — or a
  bare `touchscreen.tap()`, and neither can express a finger drag.
- `website/index.html` pulls the WASI shim from a CDN, so a run needs network.

## The Obsidian smoke

`obsidian/` is a separate suite, run by `just obsidian-smoke`, not by `just
test`: it needs a desktop Obsidian and the cloned plugin, and it opens a window.
It loads the built `obsidian-vithanco/main.js` into a second Obsidian instance
with its own `--user-data-dir`, so the maintainer's open Obsidian is never
touched, and tests the newest `obsidian-<ver>.asar` from their install rather
than the older one the installer bundles. Set `OBSIDIAN_PLUGIN_DIR`,
`OBSIDIAN_BIN` or `OBSIDIAN_ASAR` (empty: the bundled version) to point it
elsewhere.

- Playwright's `_electron.launch` cannot attach — Obsidian's builds disable the
  Node inspector — so the app is spawned with `--remote-debugging-port` and
  reached over CDP.
- `browser.close()` over CDP can hang. The instance is killed by matching its
  `--user-data-dir`, never by app name.

## The VS Code preview

`vscode/` is run by `just vscode-preview` (and by `just test` when
`vscode-vithanco/` is cloned). No test can open VS Code's Markdown preview, so it
loads what the extension contributes to it — the block markup from
`src/html.ts`, the built preview script and the styles — into Chromium, and
updates it the way the preview does after an edit. It is also the in-depth test
of `src/zoom.ts`, which the Obsidian plugin shares.
