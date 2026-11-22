# Where a change goes

Read this before tracing a feature through the code by hand; the chain below
is the same every time.

## Adding a capability end to end

A feature that a user can reach from the editor, the MCP servers *and* wasm
touches these, in order. Each step is its own commit in practice.

1. **Domain** — `Sources/VGraph/Domain/` (graph, commands, attributes). Errors in `Identity/VErrors.swift`; command ids in `Commands/VCommandID.swift`.
2. **Port** — `Sources/VGraph/VStdPorts/For*.swift`. A new member on a driving port must also be added to the expected table in `Tests/AppTests/ArchitectureTest.swift`, which fails until you do.
3. **Use case** — `Sources/App/Domain/` (`VGraphApplication` for stateless calls, `GraphSession` for the editor's stateful ones). Ports are re-exported under the plain name in `Sources/App/Ports/Inbound/`.
4. **Editor decisions** — `Sources/EditorCore/` (`Menu`, `Conversation`, `Gesture`, `Views`…). The editor in `VGraphWasm/VGraphEditor/` only hit-tests, measures and paints. Wasm-graph code: see the Embedded rules in AGENTS.md.
5. **Wasm** — `VGraphWasm/Sources/Main.swift` (BridgeJS regenerates `Sources/Generated/` on `./build-wasm.sh`); editor UI in `VGraphWasm/VGraphEditor/`; JS smoke tests in `VGraphWasm/Tests-JS/` (`fixtures.js`, `smoke.test.js`); editor browser tests (Playwright) in `VGraphWasm/Tests-Browser/`.
6. **MCP servers** — another repository, cloned to `vgraph-mcp/` (ADR 0040). Swift: `Sources/VGraphMCPTools/VGraphTool.swift`, tests in `Tests/VGraphMCPTests/`. npm host: `src/` (`server.mjs`, `render.mjs`), tests in `test/`. `just mcp test` runs them against this checkout.
7. **Docs** — `docs/VGL_GUIDE.md` for language changes, `GLOSSARY.md` for new terms, `docs/adr/` for decisions.

## Adding a port

1. Declare `VFor<Verb><Noun>` in `Sources/VGraph/VStdPorts/`.
2. Re-export it under the plain name (`typealias For<Verb><Noun> = VFor<Verb><Noun>`)
   in the ports folder of every hexagon that speaks it; `ArchitectureTest` fails
   while there is none.
3. Add an `associatedtype` and its property to `AppPorts`
   (`Sources/App/Ports/AppPorts.swift`).
4. Wire an adapter into `NativePorts` and `ParseOnlyPorts`
   (`Sources/App/Composition/`); add a null adapter if the capability can be
   absent.

Parser and exporter for VGL syntax: `Sources/VGLanguage/Core/Domain/` (`Parser.swift`, `ASTNode.swift`, `VGraphParser.swift` builds the graph, `VGLExporter.swift` writes it back).

## Where a test goes

SwiftPM lets a target import its transitive graph, but a *test* target compiles only against its declared dependencies (`Package.swift`). Choose by what the test must call:

| The test needs… | Target | Entry point |
| --- | --- | --- |
| a parsed graph, no rendering (sessions, commands, menus) | `AppTests` | `makeTestSession(vgl:)` / `makeTestApp()` in `Tests/AppTests/TestSession.swift` (parse-only wiring) |
| parser, exporter, round trips | `VGLanguageTests` | `NativePorts(logger: NoOpLogger())` wired by hand (no `TestSupport` dependency); see `VNotationDocumentTest.swift` |
| a rendered SVG | `VGraphSVGTests` | `VGraphTestApp()` (`import TestSupport`) |
| Graphviz layout | `VGraphvizLibTests` | `VGraphTestApp()` |
| domain types only | `VGraphTests` | none |
| MCP tool results | `VGraphMCPTests`, in `vgraph-mcp/` | `VGraphTool.handle` |

`AppTests` does not depend on `VGraphSVG` or `VGraphvizLib`, so a render test written there fails to build; put it in `VGraphSVGTests`.
`VGraphTestApp` is the native wiring with a silent logger (`Tests/TestSupport/VGraphTestApp.swift`).

## Which test owns a contract

Each contract has one owning test. A copy elsewhere adds nothing but a second
place to change; extend the owner's table instead.

| Contract | Owner |
| --- | --- |
| a menu's rows (id, title, enabled) | `GoldenMenuTest` |
| whether a command asks, and what | `ConversationTest`, through `begin` / `next` |
| what an option list contains | the command's own file (`AddNodeTest`, `ChangeNodeTypeTest`, …) |
| the menu and the command agree, on every fixture | `MenuAgreesWithExecutionTest` |
| graph rules a session passes on (moving, grouping) | `VGraphTests` |
| parser and exporter rows | `VGLanguageTests` |

A session test asserts what the session adds: history, refusal, the exported
document.

A test proves its contract once it has been seen **red**: break the owner once
(drop a guard, swap an argument), watch the test fail for that reason, restore.
What made tests here pass without proving anything:

- a refusal that tripped an earlier guard — assert the exact `VError` case;
- a fixture that cannot show the difference — make the excluded type present,
  the pair have candidates, the bound be reached;
- an expected value read back from the code under test — write the literal;
- hand-built editor state — go through `begin` / `next`, `menu`, `rightClick`.
