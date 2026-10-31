// WASM composition root — wires the WASM driven adapters (ConsoleLogger,
// in-process Graphviz layout) into a VGraphApplication.

import App
import VGraph

/// Fully-configured VGraphApplication for the WASM platform.
///
/// Graphviz layout runs in-process (swiftGraphviz, compiled into this wasm
/// module) — no JS-host round-trip, no precomputed layout JSON. Only the
/// logger is wasm-specific; the wiring is `NativePorts`, shared with the
/// CLI, MCP and the tests.
public typealias VGraphWasmApp = VGraphApplication<NativePorts<ConsoleLogger>>

/// GraphSession specialised for the WASM editor (see GraphSession.swift).
///
/// `NullDocumentObserver` because this editor is still one component owning
/// both panes: applying a change moves the textarea, the highlight, the
/// preview and the history flags in one ordered function, so there is
/// nothing for an announcement to tell. The observer earns its keep when the
/// panes become separately mountable (ADR-0013).
public typealias VGraphWasmSession = GraphSession<
    NativePorts<ConsoleLogger>, InMemoryVersionStore, NullDocumentObserver
>

extension VGraphWasmApp {
    public init() {
        self.init(ports: NativePorts(logger: ConsoleLogger()))
    }
}
