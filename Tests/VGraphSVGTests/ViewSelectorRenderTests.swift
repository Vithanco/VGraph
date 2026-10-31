import Foundation
import TestSupport
import Testing
import VGraph

@testable import App

private let banking = """
    vgraph banking: C4 "Internet Banking" {
        node customer: Person "Customer";
        node mainframe: SoftwareSystem "Mainframe";
        group ibs "Internet Banking System" {
            node web: Container "Webapp";
            node api: Container "Gateway";
            node db: Database "Storage";
        }
        edge customer -> web;
        edge web -> api;
        edge api -> db;
        edge api -> mainframe;
    }
    """

// Four words in a concept label draw a quality warning.
private let concepts = """
    vgraph test: ConceptMap "Test?" {
        node a: Concept "A Very Long Concept Name"
        node b: Concept "Cat"
        node r1: Relation "is a"
        edge a -> r1
        edge r1 -> b
    }
    """

/// The elements the picture draws, by the id the renderer stamps on each.
private func drawn(_ view: String?, _ source: String, _ app: VGraphTestApp) throws -> Set<String> {
    let svg = try app.renderGraph(source, view: view).svg
    return Set(["customer", "mainframe", "web", "api", "db"].filter { svg.contains("id=\"node-\($0)\"") })
}

@Suite("View selectors: rendering and judging")
struct ViewSelectorRenderTests {
    private let app = VGraphTestApp()

    @Test("Given include node nothere, then nothing is shown and rendering that view does not fail")
    func emptyViewRenders() throws {
        let source = banking + "\nvview v {\n include node nothere;\n}\n"
        #expect(Set(try app.parseGraph(source).displaying(view: "v").nodes.map { $0.id }).isEmpty)
        _ = try app.renderGraph(source, view: "v")
    }

    @Test("Given a view showing only customer and web, when rendered, then the SVG has those two nodes and not api or db")
    func renderedSubset() throws {
        let source = banking + "\nvview v {\n include node customer, web;\n}\n"
        #expect(try drawn("v", source, app) == ["customer", "web"])
    }

    @Test("Given the same document, when the default view is rendered, then the SVG is what it is today")
    func defaultViewShowsEverything() throws {
        let source = banking + "\nvview v {\n include node customer, web;\n}\n"
        #expect(try drawn(nil, source, app) == ["customer", "mainframe", "web", "api", "db"])
    }

    @Test("Given a model with a quality problem, when a view hiding the offending node is rendered, then the quality report still lists it")
    func judgingIgnoresViews() throws {
        let source = concepts + "\nvview v {\n exclude node a;\n}\n"
        let report = try app.renderGraph(source, view: "v").qualityReport
        #expect(report.formatted()?.contains("A Very Long Concept Name") == true)
    }

    @Test("Given a view that hides db, when its sibling view is rendered, then db is still there")
    func viewsAreIndependent() throws {
        let source =
            banking + "\nvview hides {\n exclude node db;\n}\n\nvview sibling {\n node customer [fontsize: 16];\n}\n"
        #expect(!(try drawn("hides", source, app)).contains("db"))
        #expect(try drawn("sibling", source, app).contains("db"))
    }
}
