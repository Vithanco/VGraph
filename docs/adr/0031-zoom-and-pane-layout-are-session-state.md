# 31. Zoom and pane layout are session state

Date: 2026-10-09

## Status

Accepted.

## Context

The Editor's preview was too small for a C4 diagram and could only scroll. It
gained a [[Zoom]] (fit or a fixed percentage) and a *Hide source* toggle. Both
could have been stored: in the document, or per [[View]] now that
[[0029-one-model-many-views]] gives presentation a home.

## Decision

Zoom, theme, source visibility and the Diagnostics strip's open state live in the
browser session only. They reach no document, no [[History]] entry and no view,
and a reload starts fitted with the source shown.

- They describe the *screen*, not the model: the same view on a phone and on a
  monitor wants different values, and a shared file should not carry the last
  author's window.
- Storing them would make a zoom change a document edit — a version, an undo
  step, a dirty file — which is exactly what 0003 and 0029 moved fold state away
  from.
- Fit is the default and is done by CSS, so it follows the pane without any
  stored number.

## Consequences

- Per-view zoom stays possible later; it would be a view attribute beside layout
  direction, and this ADR is what to reverse.
- "Zoom" in C4 is the notation's word for a fold level (0003). This is the other
  one, and the glossary keeps them apart.
- An editor in an iframe cannot outgrow it. Fullscreen's default permission
  policy is `self`, so the site's own iframes can go fullscreen with no `allow`
  attribute; a host that withholds it gets the editor on a page of its own
  instead, which is why the document travels in the link.
- Pinch zoom is not available on touch: the preview is pan-only so that a press
  on a node can drag (0018). The buttons zoom instead.
