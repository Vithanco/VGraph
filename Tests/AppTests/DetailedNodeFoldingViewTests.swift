import Testing
import VGLanguage
import VGraph

@testable import App

/// ADR-0032: `folded node type: T` folds the detailed nodes of type T.
@Suite("Views fold detailed nodes by node type")
struct DetailedNodeFoldingViewTests {
    let vgl = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node web: Container "Web";
            }
            group bank: Organisation "Big Bank" {
                node clerk: Person "Clerk";
            }
            edge customer -> web;
        }

        vview context "System Context" {
            folded node type: SoftwareSystem;
        }
        """

    @Test("Given folded node type: SoftwareSystem, when the view is shown, then the detailed node is folded and the plain group is not")
    func foldsDetailedNodesOfTheType() throws {
        let s = try makeTestSession(vgl: vgl)
        try s.selectView("context")
        #expect(s.isFolded("ibs"))
        #expect(!s.isFolded("bank"))
    }

    @Test("Given folded node type: SoftwareSystem, which repeats the default of a detailed node, when a command runs, then the export drops it")
    func exportDropsFoldedNodeTypeThatRepeatsTheDefault() throws {
        let s = try makeTestSession(vgl: vgl)
        try s.setLabel(of: "customer", to: "Client")
        let text = try s.exportVGL()
        #expect(!text.contains("folded node type: SoftwareSystem"))
        #expect(!text.contains("isfolded"))
    }

    @Test("Given folded node type: SoftwareSystem, when one detailed node is unfolded in the view, then it is no longer folded")
    func unfoldingOneWinsOverTheType() throws {
        let s = try makeTestSession(vgl: vgl)
        try s.selectView("context")
        try s.toggleFolding(of: "ibs")
        #expect(!s.isFolded("ibs"))
    }

    @Test("Given the model unfolds ibs, when a view says folded node type: SoftwareSystem, then the view folds it (ADR-0030: the layer comes first)")
    func viewTypeValueBeatsModelElementValue() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph banking: C4 "Internet Banking" {
                    node customer: Person "Customer";
                    group ibs: SoftwareSystem "Internet Banking System" {
                        isfolded: false;
                        node web: Container "Web";
                    }
                    edge customer -> web;
                }

                vview context "System Context" {
                    folded node type: SoftwareSystem;
                }
                """)
        #expect(!s.isFolded("ibs"))
        try s.selectView("context")
        #expect(s.isFolded("ibs"))
        try s.setLabel(of: "customer", to: "Client")
        #expect(try s.exportVGL().contains("folded node type: SoftwareSystem"))
    }

    @Test("Given folded node 'customer', then the view is refused: only a group or a node type folds")
    func foldedNodeIsRefused() {
        #expect(throws: VError.self) {
            try makeTestSession(vgl: vgl + "\nvview broken { folded node customer; }\n")
        }
    }
}
