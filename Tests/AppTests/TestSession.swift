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

/// Risk and Control related two ways, Issue and Control one: retyping an Issue
/// to a Risk leaves each of its edges ambiguous.
let riskMapNotation = """
    vnotation RiskMap {
      node type: Risk [nodeStyle: roundedBox, color: "#cc3333"]
      node type: Issue [nodeStyle: roundedBox, color: "#3366cc"]
      node type: Control [nodeStyle: roundedBox, color: "#339933"]

      edge type: mitigated_by from: Risk to: Control
      edge type: monitored_by from: Risk to: Control
      edge type: fixed_by from: Issue to: Control
    }
    """
