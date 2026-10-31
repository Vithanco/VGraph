import TestSupport
import Testing
import VGraph

@testable import App

@Suite("A session renders the view it shows")
struct ViewRenderSessionTests {
    let app = VGraphTestApp()

    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          node outside: Concept "Outside";
          group bank "Bank" {
            node inner: Concept "Inner";
          }
        }

        vview containers "Containers" {
          folded group bank;
        }
        """

    @Test("Given containers folds bank, when it is shown, then bank is drawn as a folded box; in the default view it is open")
    func rendersTheShownView() throws {
        let session = try app.makeSession(vgl: vgl)
        let open = try session.render().svg
        #expect(open.contains("id=\"node-inner\""))
        try session.selectView("containers")
        let folded = try session.render().svg
        #expect(folded.contains("vgraph-folded-group"))
        #expect(!folded.contains("id=\"node-inner\""))
    }
}
