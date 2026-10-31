# Font System

VGraph only supports fonts it can measure without platform APIs, which is why
`FontFamily` is a closed enum rather than a string. Each family carries a
`charWidthRatio` (average character width to point size) that
`TextSizeEstimator` sizes text from on every platform. The ratio is the
contract; the installed font is not, and text that must fit exactly is not
something this system can promise.

## DM Sans is the default, and is not like the others

`FontFamily.default` is DM Sans. It is the one family that is neither web-safe
nor known to Graphviz, which is deliberate but has consequences:

- **Graphviz doesn't know it**, and warns on every use that it is falling back
  to Times metrics. So the DOT sent for layout names Helvetica (`DotExporter`,
  `graphvizSpelling`): its 0.55 is closer to DM Sans's 0.54 than Times' 0.50.
  Node text is unaffected: every node carries `fixedsize` with a width and
  height computed here, and its label is left empty in that DOT since Graphviz
  could only mis-measure it. What Graphviz sizes itself — edge labels, group
  labels and the graph title — it sizes with Helvetica metrics. The SVG still
  names DM Sans. What remains is a warning for each non-ASCII character in
  those labels, which Graphviz measures byte by byte.
- **Getting it to a renderer is a delivery problem.** Browsers fetch it via the
  `@import` in `SVGBuilder.dmSansFontImportCSS()`. Rasterisers cannot — see
  `fonts/README.md` for what they need instead and why.

## Serialization

`<FontFamily>;<Size>` — `Helvetica;12`, `Verdana;14.5`. A bare `12` means the
default family (DM Sans) at that size.
