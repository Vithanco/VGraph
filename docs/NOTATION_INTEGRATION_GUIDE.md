# Notation Integration Guide

How to add a new notation to VGraph. `Sources/VGraph/Domain/Notations/ImpactMapping.swift`
is the reference implementation — read it alongside this.

## 1. Pin down the notation

Before writing code, know its **node types**, its **edge types** (each with a
source and target node type), and its natural reading direction. Sources are
usually the notation's page on Vithanco.com, the original paper or book, or an
industry standard.

For each node type decide a purpose and an icon; for each edge type a snake_case
id and the `from → to` pair. Colours are not decided here — they come from the
style guide (step 2). That specification is the whole input to the rest of this
guide.

If the notation needs a page on Vithanco.com, it goes in
`Content/Notations/<Category>/<notation-name>.md` in the VithancoWebsite repo —
`Change/impact-mapping.md` is the model to copy.

## 2. Visual design

**Layout.** `iconWithText` is the common node style; `simpleRoundedBox`,
`withCategory` and the other `NodeStyle` cases exist for plainer types. Layout
direction follows the notation's
flow — left-to-right for process chains and hierarchies, top-to-bottom for
org-chart and decision-tree shapes.

**Icons** are drawn for the project, never traced from another icon set.
A new one is drawn in the style guide's Icons section first, its master in the
`ICONS` table, then copied into `BuiltinIcons`; a test holds the two together.

**Colours come from the [style guide](design/README.md)**, which is normative: a
notation's palette — each node type's fill, border and text, light and dark — is
decided there first and then copied into code. A notation the guide has no
palette for gets one there before it gets one here.

**Colours must be `public static let` constants at the notation struct's top
level**, as `SemanticColor`s named for the guide's triple (`goalFill`,
`goalBorder`, `goalText`). Never inline `VColor(hexString:)` inside `values`.
This keeps every colour in one discoverable place, adjustable and referenceable
from tests.

## 3. Implement it

New file at `Sources/VGraph/Domain/Notations/<NotationName>.swift`, declaring a
`NotationDeclaration` with:

- a unique `id` matching the name users type in VGL;
- the colour constants from step 2;
- a `NodeTypes` struct — one `static let` per type, plus `all`;
- an `EdgeTypes` struct — one `static let` per type with its `from`/`to`, plus
  `all`;
- `values`: the attributes on its types and on the diagram (such as
  `layoutDirection`), as data. A notation never touches a graph; the parser
  places its types and values in the built-in layer (ADR-0030). The presets on
  `TypeValues` (`badge`, `preset`, `junctor`, `icon`) cover most node types.

Copy the structure from `ImpactMapping.swift` rather than working from a
template — it stays current and this document does not.

### Optional: a structural transform

Most notations only register types and styles. If yours must *rewrite* the graph
before layout — merging nodes, synthesising edges — declare a step:

```swift
// In Sources/VGraph/Domain/Layout/<YourStep>.swift
extension TransformStep.Id {
    public static var yourStep: Self { "yourStep" }
}

extension Notations.YourNotation {
    public static var yourStepStep: TransformStep {
        TransformStep(.yourStep) { (g: VGraph) throws(VError) in try applyYourStep(to: g) }
    }
}

// In the notation itself — this is the whole wiring
public static var step: TransformStep? { yourStepStep }
```

`step` defaults to `nil`, is carried on `NotationEntry`, and runs in the notation
phase of `DisplayPipeline`. Declaring it is sufficient — dispatch is the registry
entry, so there is no switch to extend.

Use a `TransformStep` rather than a bare closure so the step checks its
prerequisites and records itself in `completedSteps`, the ledger the document
exporter checks before writing VGL back to disk.

Two constraints:

- **No other step may declare `requires:` on your step's id.** The notation phase
  is per-graph, so the id is present only for graphs using your notation; a
  prerequisite on it would pass there and throw for every other notation.
- **A `vnotation` block's `transform:` names replace the compiled step rather
  than adding to it.** To make yours available to dynamic notations, register it
  in `TransformRegistry.resolveStep(name:)` too.

Working example: `Notations.ConceptMap.step` → `mergeStep`
(`Sources/VGraph/Domain/Layout/MergeRelationsStep.swift`), which merges duplicate
`Relation` nodes sharing a label and target set.

### Register it

One line in `NotationRegistry.entries`
(`Sources/VGraph/Domain/Notations/Notations.swift`):

```swift
("YourNotation", Notations.YourNotation.entry),
```

`Notations.X.entry` is the value-type `NotationEntry` snapshot synthesised by a
blanket extension on `NotationDeclaration`, capturing the static metadata, the
install closure and the optional `step`. The registry stores those values
directly rather than `any NotationDeclaration.Type` metatypes, which Embedded
Swift forbade before 6.4.

`NotationRegistry` is the single source of truth for both dispatch and the
"valid notations" error message, so this one line is all that is needed.

## 4. Test it

Add a full-cycle case to `Tests/VGLanguageTests/FullCycleTest.swift` (the suite
uses swift-testing, not XCTest). Write a realistic VGL example exercising every
node type and every edge type, then assert:

1. it parses without error;
2. the node and edge counts are right;
3. each node carries the expected node type, and each edge the expected edge
   type;
4. `exportVGL()` mentions the notation and its types;
5. re-parsing the exported VGL yields an equivalent graph — same id, label,
   counts;
6. any special attributes survive the round trip.

```bash
swift test --filter YourNotation
```

## 5. Add an editor example

Add an `ExampleGraph` to `exampleGraphs` in
`Sources/VGraph/Domain/Examples/ExampleGraphs.swift`, named `"<Notation> — <Title>"`; it
appears in the editor's **Examples…** picker. (The old flow — buttons in
`website/index.html` — is gone: the editor renders its own chrome and the
examples are compiled in.) Aim for 10–15 nodes: realistic, covering every node
type and most edge types, and visually interesting when rendered. Then check in
a browser that it loads, renders with the right styling, and round-trips through
VGL Export.

## 6. Document it in the VGL Guide

In [VGL_GUIDE.md](VGL_GUIDE.md), two places. Add a row to the table under
`## Notations` — the notation name linked to its section, plus a one-line
purpose. Then add a `###` section under `## Notation reference`, in the same
order as the table, following the shape every other notation uses: a one- or
two-line purpose, **Node types**, **Edge types** (with `from → to`), a lead-in
sentence, and one complete commented example.

Reuse the example from step 5 rather than writing a second one, so the guide and
the editor stay in step; if you deliberately show a simpler version, say so in
the note under it.

If the notation carries quality checks, list what they report under
`### Quality checks` in the `## Notations` section — that subsection covers all
notations, so checks do not belong in the notation's own section. Give each one
its severity and its actual threshold, not a paraphrase.

## Common problems

**The icon doesn't render.** The name resolves to nothing: the node draws a
missing-icon placeholder and the quality report names the icon. Check the name
against the built-in set (listed in the [VGL Guide](VGL_GUIDE.md#icon--artwork-of-your-own)).

**An edge type isn't recognised.** Ids are case-sensitive and must match the VGL
exactly; the `from`/`to` node types must be right; and the type must be in
`EdgeTypes.all`.

**The round-trip test fails.** Debug export and re-parse separately — the usual
cause is an attribute that is set but not exported.

**The layout looks messy.** Try the other layout directions before reaching for
special attributes, and test at more than one example size.
