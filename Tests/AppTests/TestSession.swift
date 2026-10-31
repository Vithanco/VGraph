// Shared parse-only composition root for the session tests. AppTests does not
// depend on VGraphSVG or VGraphvizLib (which the native root wires in), and
// these suites exercise history/diff, which need neither.

import VGLanguage
import VGraph

@testable import App

typealias TestApp = VGraphApplication<ParseOnlyPorts<NoOpLogger>>
typealias TestSession = GraphSession<
    ParseOnlyPorts<NoOpLogger>, InMemoryVersionStore, NullDocumentObserver
>

func makeTestApp() -> TestApp {
    TestApp(ports: ParseOnlyPorts(logger: NoOpLogger()))
}

func makeTestSession(vgl: String) throws -> TestSession {
    try makeTestApp().makeSession(vgl: vgl)
}
