import TestSupport
import Testing
import VGraph

@testable import App

@Suite("A host renders a named view as JSON")
struct RenderViewJSONTests {
    let app = VGraphTestApp()

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

    @Test("Given a view, when rendered as JSON, then the view's picture and the model's report come back")
    func rendersNamedView() throws {
        let model = try app.renderGraphJSON(twoViews)
        let view = try app.renderGraphJSON(twoViews, view: "context")
        #expect(view != model)
        #expect(view.contains("\"quality\":"))
    }

    @Test("Given an unknown view, when rendered as JSON, then the error lists the views")
    func unknownView() {
        #expect(throws: VError.unknownView("nope", available: ["context", "containers"])) {
            try app.renderGraphJSON(twoViews, view: "nope")
        }
    }
}
