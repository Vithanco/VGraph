import Testing
import VGLanguage
import VGraph

@testable import App

/// Every editor command exports the document and keeps that text as history,
/// so a view that the export drops is gone for good.
@Suite("Views survive the editor")
struct ViewSessionTests {
    let vgl = """
        vnotation Banking extends C4 {
            group type: Zone
        }

        vgraph banking: Banking "Internet Banking" {
            node customer: Person "Customer";
            group bankingSystem: Zone "Internet Banking" {
                node web: Container "Web App";
            }
            edge customer -> web;
        }

        vview context "System Context" {
            folded group type: Zone;
        }

        vview containers "Containers" {
            node web [fontsize: 16];
            node ghost [fontsize: 31];
        }
        """

    private func hasBothViews(_ text: String) -> Bool {
        text.contains("vview context \"System Context\"") && text.contains("folded group type: Zone")
            && text.contains("vview containers \"Containers\"") && text.contains("node web [fontsize: 16]")
            && text.contains("node ghost [fontsize: 31]")
    }

    @Test("Given views, when a command runs, then its export still has them")
    func commandKeepsViews() throws {
        let s = try makeTestSession(vgl: vgl)
        try s.setLabel(of: "customer", to: "Client")
        let text = try s.exportVGL()
        #expect(text.contains("\"Client\""))
        #expect(hasBothViews(text))
    }
}
