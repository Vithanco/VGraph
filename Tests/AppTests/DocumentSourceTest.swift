//
//  DocumentSourceTest.swift
//  VGraph
//
//  Recovering a [[Diagram as document]]'s VGL from the artefact, through the
//  toolbar's own port.
//
//  On `ForManageADocument` because opening a file is the [[File menu]]'s
//  business and the toolbar is its actor — not on the diagram pane's port,
//  which never opens anything.
//

import Testing
import VGLanguage
import VGraph

@testable import App

struct DocumentSourceTest {
    /// `ParseOnlyPorts` wires `NullRenderer`, so this is the no-renderer
    /// configuration answering — and the answer is "this carries no source",
    /// not a trap and not `.notImplemented`. Being handed a picture that is only
    /// a picture is a normal thing, unlike being asked to draw with no renderer.
    @Test("A configuration with no renderer reports no source rather than failing")
    func aNullRendererCarriesNothing() throws {
        let session = try makeTestSession(
            vgl: """
                vgraph demo: IBIS "Demo" {
                  node q: Question "Q";
                }
                """)

        #expect(session.sourceVGL(from: "<svg><metadata>anything</metadata></svg>") == nil)
    }
}
