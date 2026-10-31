import Testing
import VGraph

@testable import App

@Suite("A host learns a document's views")
struct ViewListingTests {
    let app = makeTestApp()

    let twoViews = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
            node web: Container "Web App";
            edge customer -> web;
        }

        vview context "System Context" {
            node web [fontsize: 16];
        }

        vview containers "Containers" {
            node web [fontsize: 20];
        }
        """

    let noViews = """
        vgraph banking: C4 "Internet Banking" {
            node customer: Person "Customer";
        }
        """

    @Test("Given views, when listed, then name and label come in document order")
    func listsInDocumentOrder() throws {
        #expect(
            try app.listViewsJSON(twoViews)
                == #"[{"name":"context","label":"System Context"},{"name":"containers","label":"Containers"}]"#)
    }

    @Test("Given no views, when listed, then the list is empty")
    func emptyList() throws {
        #expect(try app.listViewsJSON(noViews) == "[]")
    }
}
