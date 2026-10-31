# Hexagonal Architecture

How VGraph is put together, and why. For the ports themselves, read
`Sources/VGraph/VStdPorts/`; this document covers only what the code cannot
state.

## The shape

```
        drivers                 application              driven adapters
  ┌──────────────────┐      ┌────────────────┐      ┌────────────────────┐
  │ vgraph-cli       │      │                │      │ VGLanguage         │
  │ vgraph-mcp       │─────▶│ VGraphApplic.  │─────▶│  VGraphParser      │
  │ VGraphWasm       │      │ GraphSession   │ports │  VGLExporter       │
  └──────────────────┘      │                │      │ VGraphSVG          │
                            └────────┬───────┘      │  VSVGRenderer      │
                                     │              │ VGraphvizLib       │
                                     ▼              │  GraphvizLibLayout │
                               VGraph (core)        │  DotExporter       │
                          domain types + ports      └────────────────────┘
```

Dependencies point inward. `VGraph` holds graph types, attributes, notations and
every port protocol, and depends on nothing but `MathUtils`. Adapters depend on
`VGraph` and implement its ports; they never see `App`, and never see each
other.

## Ports

All live in `Sources/VGraph/VStdPorts/`, declared as `VFor<Verb><Noun>` and
known by the plain `For<Verb><Noun>` everywhere else (see
[below](#why-every-port-has-two-names)) — driving and driven alike. They live in
the core rather than in `App` because adapter modules must conform to them
without being able to see `App`.

| Port | Implemented by |
|---|---|
| `ForParseAGraph` | `VGraphParser` (VGLanguage) |
| `ForHighlightVGL` | `VGraphParser`, `NullHighlighter` |
| `ForExportAGraph` | `VGLExporter` (VGLanguage), `DotExporter` (VGraphvizLib) |
| `ForLayoutAGraph` | `GraphvizLibLayoutEngine` (VGraphvizLib), `NullLayoutEngine` |
| `ForRenderAGraph` | `VSVGRenderer` (VGraphSVG), `NullRenderer` — see [ADR-0015](adr/0015-svg-ir-and-elementary-upstreaming.md) |
| `ForLogMessages` | `PrintLogger` (CLI), `StderrLogger` (MCP), `ConsoleLogger` (WASM), `NoOpLogger`. The CLI and MCP loggers filter by `VGRAPH_LOG_LEVEL` (default `warn`), so a self-hoster does not log diagram content by accident |
| `ForStoreDocumentVersions` | `InMemoryVersionStore` — see [ADR-0007](adr/0007-document-versions-port.md) |
| `ForObserveDocumentChanges` | `NullDocumentObserver` — see [ADR-0013](adr/0013-driving-ports-and-named-commands.md) |
| `ForEditVGL` | `GraphSession` — see [ADR-0013](adr/0013-driving-ports-and-named-commands.md) |
| `ForEditAGraphVisually` | `GraphSession` |
| `ForManageADocument` | `GraphSession` |

Absent capabilities are null objects, not optionals. A `Renderer?` had to be
re-checked at every use, and one path force-unwrapped it — so a configuration
with layout but no renderer trapped instead of reporting a missing capability.
`NullRenderer` and `NullLayoutEngine` throw `.notImplemented`;
`NullHighlighter` returns the source unchanged, because highlighting is
presentation and its absence is not an error.

### A port is an actor's conversation, not a use case

Ports are counted by **actor**, not by operation. `ForEditAGraphVisually` carries
a dozen editing commands because the diagram pane is one actor having one
conversation. Use cases are what a port *offers*, not what a port *is*.

The alternative — a narrow port per use case, argued from interface segregation
— does not transfer here. Half of `ForEditAGraphVisually` is candidate queries
that are not use cases at all, and `EditorCore.menu(for:in:notationBreak:)`
builds one menu from most of them, so it would need the union back. Since a port
is a generic parameter and never an existential, that union is either a dozen
composed constraints or an `AppPorts`-shaped bundle — the same port under a
longer name.

`ArchitectureTest.eachDrivingPortOffersExactlyItsActorsSurface` holds each port
to its actor's surface. The granularity rule stays prose: no test can tell an
actor from an operation.

### Why every port has two names

Each port is declared once in the core as `VFor*`, and every hexagon that speaks
it re-exports it under the plain name:

```swift
// Sources/VGraph/VStdPorts/ForRenderAGraph.swift
public protocol VForRenderAGraph { ... }

// Sources/VGraphSVG/Inbound/ForRenderAGraph.swift
public typealias ForRenderAGraph = VForRenderAGraph
```

The typealias is **that hexagon's declaration of its own port**. Every port
using the same data types today is a convenience, not a guarantee; the re-export
is the seam that lets one hexagon's port diverge without disturbing the others.

The `V` prefix is forced, because neither obvious spelling compiles:

```swift
public typealias ForExportAGraph = ForExportAGraph
// error: type alias 'ForExportAGraph' references itself

public typealias ForExportAGraph = VGraph.ForExportAGraph
// error: 'ForExportAGraph' is not a member type of struct 'VGraph.VGraph'
```

The module-qualified form fails because the module `VGraph` contains a *struct*
named `VGraph`, which shadows the module as a qualifier. (Verified on Swift
6.3.3; if a future compiler lets the module qualifier win, the prefix could go.)

So **do not collapse the two names into one.** Doing so compiles and passes the
full suite while silently removing the per-hexagon port declarations.

## Ports are generic parameters, not existentials

Every port is a compile-time type, never `any ForRenderAGraph`. Embedded Swift
6.4 would compile the existential; the choice stands because generics keep port
calls statically dispatched and specialised, and because an `any` port could
not be passed on to generic code — the one existential use Embedded Swift still
rejects.

One generic parameter per port does not scale: it reached five on
`VGraphApplication` and six on `GraphSession`, and every added port grew every
signature, typealias and `where` clause in the module. They are bundled into
`AppPorts` (`Sources/App/Ports/AppPorts.swift`), one `associatedtype` each.
Associated types resolve at compile time exactly as the parameters did, and
adding a port now touches the protocol and each composition root instead of
every signature in between.

```swift
public struct VGraphApplication<Ports: AppPorts>
public final class GraphSession<
    Ports: AppPorts, VersionStore: ForStoreDocumentVersions,
    Observer: ForObserveDocumentChanges
>
```

## Driving ports point the other way

Most ports are ones the application *needs*. Three are what it *offers*:
`ForEditVGL`, `ForEditAGraphVisually` and `ForManageADocument` — one per actor
(text pane, diagram pane, toolbar), all conformed to by `GraphSession` and
re-exported from `Sources/App/Ports/Inbound/`. A component holding one cannot
reach another actor's surface: the editor is not one actor merely because it is
one window. See [ADR-0013](adr/0013-driving-ports-and-named-commands.md).

`Inbound/` and `Outbound/` read alike, and the two-name rule does not bend for
them — direction is a fact about who calls whom, not about where a protocol is
written. A driving port declared in `Inbound/` compiles fine, so
`ArchitectureTest.everyDrivingPortIsDeclaredInTheCore` and
`inboundDeclaresNoProtocolOfItsOwn` are what notice.

No driving port has an associated type — every type they name is concrete — so a
pane is `struct DiagramPane<Session: ForEditAGraphVisually>` and never names
`AppPorts` or a version store. A pane wanting two holds `A & B`, still static
dispatch (confirmed by `VGraphWasm/VGraphEditor/DrivingPortWitness.swift`).

Changes flow back through `ForObserveDocumentChanges`, an **Observer**: once the
panes are separable, a change in one has to reach the others. It carries no
payload, because the three readers want different things and anything carried
would serve one of them — each pulls what it needs from the port it already
holds. There is one observer and not a list, `[any ForObserveDocumentChanges]`
being exactly the existential this codebase is built around not having; fanning
out is the implementing adapter's job.

## Composition

`VGraphApplication` is generic; an assembled app is a specialisation of it.
Choosing a `Ports` conformer is the assembly step, and the conformers are the
only types allowed to name concrete adapters:

- **`NativePorts<Logger>`** — every capability: VGL parsing and highlighting,
  SVG rendering, in-process Graphviz layout.
- **`ParseOnlyPorts<Logger>`** — parsing, export, history, quality analysis.

Every driver therefore differs only in its logger:

```swift
public typealias VGraphCLIApp  = VGraphApplication<NativePorts<PrintLogger>>
public typealias VGraphMCPApp  = VGraphApplication<NativePorts<StderrLogger>>
public typealias VGraphWasmApp = VGraphApplication<NativePorts<ConsoleLogger>>
public typealias VGraphTestApp = VGraphApplication<NativePorts<NoOpLogger>>
```

One shared wiring is deliberate: when MCP assembled its own pipeline it drifted,
applying folding but not the notation phase, and rendered notations differently
from the CLI and the editor.

`Sources/App/` splits along the same line, checkable from the imports:

- `Domain/` — use cases. Imports `VGraph` only. An adapter import here means the
  boundary has been crossed.
- `Ports/`, `Adapters/` — the `AppPorts` bundle; in-memory and null adapters.
- `Composition/` — the wiring. Imports adapter modules by design.

Anything needing a concrete adapter belongs in `Composition/`, which is why the
DOT helpers live there: DOT is the Graphviz adapter's format, not something the
application layer knows about.

`GraphSession` is built by `VGraphApplication.makeSession`, never the other way
round, and drives the app's ports rather than constructing adapters. It
previously built its own `VGraphParser`, which made its parser port decorative.

## Adapter logic that is not adapter-specific

`Sources/EditorCore/` holds the part of the editor that is decision rather than
rendering. It drives `ForEditAGraphVisually` generically and knows nothing about
the DOM, ElementaryUI or JavaScriptKit, so it is an ordinary Swift target the
test suite imports.

The sorting rule is **does this line make a choice**, not *is it domain logic* —
the second is too weak, and would leave a command's whole question-and-answer
state machine in the wasm target on the grounds that none of it is a notation
rule. What stays behind is what the browser genuinely owns: hit-testing through
`closest`, pointer capture, key handling, and where a thing sits on screen.

It exists because `VGraphWasm` is covered only by JS smoke tests and browser
tests (`VGraphWasm/Tests-JS/`, `VGraphWasm/Tests-Browser/`) — every rule left
there is one no Swift test guards. Menu contents,
ordering and greying moved out of `VGraph` and into the editor
([ADR-0013](adr/0013-driving-ports-and-named-commands.md)); putting them straight
into the wasm package would have traded a behaviour asserted in Swift for one
asserted nowhere. `GoldenMenuTest` pins the whole menu through `EditorCore` and
passed unchanged across the move, which is how we know it was a relocation.

The rule that keeps it honest: `EditorCore` may *display* a domain fact and
*invoke* a domain operation, never compute one. A notation rule it re-derives
itself is the bug this target exists to prevent.

## Layout runs in-process

Graphviz compiles into the wasm module via swiftGraphviz. There is no JS-host
round-trip and no precomputed layout JSON, so `VGraphWasm` uses the same
`NativePorts` wiring as every native driver.

## Rendered output carries its source

`ForRenderAGraph.render` takes the graph's VGL text alongside the graph, and the
adapter decides how to carry it — `VSVGRenderer` embeds it as `<metadata>`, a
PNG renderer might use a text chunk, another might drop it. The application layer
only promises the text is semantically the same graph. It used to post-process
the returned SVG string itself, which put an SVG detail in the use-case layer.
