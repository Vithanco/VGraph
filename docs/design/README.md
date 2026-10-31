# Vithanco Diagram Design — docs/design/

Visual reference for the **default theme** of the VGraph renderer (light + dark).

This is the guide's only home: edit it here like any other file. The renderer
doesn't read it, so every hex lives twice — here and in `SemanticColor` / the
notation's tokens. Change both in the same PR; a hex changed in one place only is
how `edgeBold` drifted. For a new visual direction, iterating on these files in a
Claude design is quicker than in code; bring the result back as a PR.

## Status of each file

| File | Status | Use |
|---|---|---|
| `Diagram Style Guide.html` | **Normative** | Binding visual reference for the default theme. Renderer output that deviates is a bug. Change the guide first, then the code. |
| `Timeline Notation Brief.html` | **Approved amendment** | Binding for the Timeline notation (axis anchors, column guides, 3 new tokens) until merged into the guide. |
| `exploration/` | **Non-binding** | History of options considered. Never implement from it. |

Open the HTML files directly in a browser (they load React/Babel + Google Fonts from CDN). The style guide has a light/dark toggle.

## What is binding

- Hex values and tokens (light + dark), incl. every notation's fill/border/text triple (§03, §11)
- Sizes, radii, stroke widths, dash patterns, typography (§01–§09, §12, §13)
- Icons: every path in `ICONS` and the construction rules (§14)
- Render z-order (Timeline brief §04)
- The §11 token rule (below)

**Not binding:** the guide's own page layout and prose; Graphviz attribute suggestions in §10 (recommendations).

## When to consult it

- Adding or changing a notation or node type
- Touching any color / token
- Dark-mode work
- Rendered output "looks off"

## Key rules (most common regression sources)

1. **Dark mode is keyed on the light hex.** Two tokens sharing a light value must share the dark value. `--edge-bold` is an alias of `--ink-2` (`#5a564e` → `#a8a49a`). If a token needs its own dark value, give it a distinct light value first. Exception: `#ffffff` and `#000000` are both theme-fixed (icons on a coloured fill) and flipping (`--card`, label text), so a token in either must say explicitly which it is. `--badge-icon`, the icon in a node type badge, is the flipping kind: white on the light circle, `#14120f` on the dark mode's brightened one, because white falls below 3:1 on most of them. `--badge-icon`, the icon in a node type badge, is the flipping kind: white on the light circle, `#14120f` on the dark mode's brightened one, because white falls below 3:1 on most of them.
2. **Edge labels use ink-2, not ink-3.** DM Sans 11px italic, `#5a564e` light / `#a8a49a` dark. Ink-3 fails contrast in dark mode.
3. **Group containers recede.** Fill `#f4f3f0` light / `#1c1a16` dark, dashed border. Never brighter than the page in dark mode.
4. **Page background dark is `#0e0d0a`**, not `#000`.
5. **TimePoint nodes do not use the standard node pipeline** (see Timeline brief). Short-circuit them in node dispatch.
6. **Icons are drawn for the project, never traced.** A new icon is drawn in `ICONS` (§14) first and copied into `BuiltinIcons`; `StyleGuideSyncTests` fails when the two differ, as it does for colours.

## Core chrome tokens

| Token | Light | Dark |
|---|---|---|
| `--page` | `#faf9f6` | `#0e0d0a` |
| `--card` | `#ffffff` | `#181612` |
| `--rule` | `#e8e3db` | `#2a2824` |
| `--ink` | `#18160f` | `#ecebe5` |
| `--ink-2` / `--edge-bold` | `#5a564e` | `#a8a49a` |
| `--ink-3` | `#9a9690` | `#6e6a62` |
| `--edge` | `#b0a898` | `#6e6a60` |
| `--group-fill` | `#f4f3f0` | `#1c1a16` |
| `--junctor` | `#303030` | `#e8e3db` |
| `--timeline-axis` | `#5a564e` @0.5 | `#a8a49a` @0.5 |
| `--timeline-guide` | `#5a564e` @0.35 | `#a8a49a` @0.30 |
| `--timeline-year` | `#18160f` | `#ecebe5` |

Full per-notation palettes: Style Guide §03 (light) and §11 Dark Palette Atlas.

Fonts: **DM Sans** (all diagram text), **DM Mono** (code/specs).
