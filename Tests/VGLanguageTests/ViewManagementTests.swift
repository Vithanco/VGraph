import Testing

@testable import VGLanguage
@testable import VGraph

@Suite("Removing and relabelling a view")
struct ViewManagementTests {
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

    private func graph() throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: twoViews)
    }

    @Test("Given two views, when context is removed, then only containers is listed")
    func removeLeavesTheOther() throws {
        let removed = try graph().removing(view: "context")
        #expect(removed.views.map { $0.name } == ["containers"])
    }

    @Test("Given two views, when context is removed, then displaying it fails as an unknown view")
    func removedViewCannotBeShown() throws {
        let removed = try graph().removing(view: "context")
        #expect(throws: VError.unknownView("context", available: ["containers"])) {
            try removed.displaying(view: "context")
        }
    }

    @Test("Given two views, when an unknown view is removed, then it is refused and the views are named")
    func removeUnknown() throws {
        let doc = try graph()
        #expect(throws: VError.unknownView("nope", available: ["context", "containers"])) {
            try doc.removing(view: "nope")
        }
    }

    @Test("Given two views, when containers is relabelled, then its label changes while its name and values stay")
    func relabel() throws {
        let doc = try graph()
        let key = ItemKey(.node, "web")
        let relabelled = try doc.relabelling(view: "containers", as: "Container View")
        #expect(relabelled.views.map { $0.name } == ["context", "containers"])
        #expect(relabelled.views.map { $0.label } == ["System Context", "Container View"])
        #expect(try relabelled.attributes(inView: "containers", of: key) == doc.attributes(inView: "containers", of: key))
    }

    @Test("Given two views, when an unknown view is relabelled, then it is refused")
    func relabelUnknown() throws {
        let doc = try graph()
        #expect(throws: VError.unknownView("nope", available: ["context", "containers"])) {
            try doc.relabelling(view: "nope", as: "X")
        }
    }
}
