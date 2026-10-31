import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

/// ADR-0032: a view treats a detailed node as being of its node type.
private let banking = """
    vgraph banking: C4 "Internet Banking" {
        node customer: Person "Customer";
        node mainframe: SoftwareSystem "Mainframe";
        group ibs: SoftwareSystem "Internet Banking System" {
            node web: Container "Web";
            node db: Database "DB";
        }
        group bank: Organisation "Big Bank" {
            node clerk: Person "Clerk";
        }
        edge customer -> web;
        edge web -> db;
        edge web -> mainframe;
        edge clerk -> mainframe;
    }
    """

private func shown(_ rules: String) throws -> (nodes: Set<String>, groups: Set<String>) {
    let source = banking + "\n\nvview v {\n\(rules)\n}\n"
    let view = try VGraphParser(logger: NoOpLogger()).parse(source: source).displaying(view: "v")
    return (Set(view.nodes.map { $0.id }), Set(view.groups.map { $0.id.id }))
}

@Suite("View selectors and detailed nodes")
struct DetailedNodeViewSelectorTests {

    @Test("Given include node type: SoftwareSystem, then the plain node and the detailed node with its details are shown")
    func nodeTypeSelectsDetailedNodes() throws {
        let result = try shown("include node type: SoftwareSystem;")
        #expect(result.nodes == ["mainframe", "web", "db"])
        #expect(result.groups == ["ibs"])
    }

    @Test("Given exclude node type: SoftwareSystem, then the detailed node goes with its details")
    func excludingANodeTypeDropsDetailedNodes() throws {
        let result = try shown("exclude node type: SoftwareSystem;")
        #expect(result.nodes == ["customer", "clerk"])
        #expect(result.groups == ["bank"])
    }

    @Test("Given include group type: Organisation, then only the plain group is shown")
    func groupTypeSelectsPlainGroups() throws {
        let result = try shown("include group type: Organisation;")
        #expect(result.nodes == ["clerk"])
        #expect(result.groups == ["bank"])
    }

    @Test("Given include group type: SoftwareSystem, then nothing is shown: a group type selector never picks a detailed node")
    func groupTypeNeverSelectsDetailedNodes() throws {
        let result = try shown("include group type: SoftwareSystem;")
        #expect(result.nodes.isEmpty)
        #expect(result.groups.isEmpty)
    }
}

@Suite("Highlighting view selectors for detailed nodes")
struct DetailedNodeViewHighlightTests {

    private func highlighted(_ rules: String) -> String {
        VGraphParser(logger: NoOpLogger()).semanticHighlightHTML(source: banking + "\n\nvview v {\n\(rules)\n}\n")
    }

    @Test("Given folded node type: SoftwareSystem, when highlighted, then folded is a keyword and SoftwareSystem a type")
    func foldedNodeType() {
        let html = highlighted("folded node type: SoftwareSystem;")
        #expect(html.contains("<span class=\"vg-kw\">folded</span>"))
        #expect(html.contains("<span class=\"vg-type\">SoftwareSystem</span>"))
        #expect(!html.contains("vg-error"))
    }

    @Test("Given include group type: SoftwareSystem, when highlighted, then SoftwareSystem is marked: it names no group type")
    func nodeTypeAsGroupTypeSelector() {
        let html = highlighted("include group type: SoftwareSystem;")
        #expect(html.contains("<span class=\"vg-error\">SoftwareSystem</span>"))
    }

    @Test("Given include node type: SoftwareSystem, when highlighted, then SoftwareSystem is a type")
    func nodeTypeSelector() {
        let html = highlighted("include node type: SoftwareSystem;")
        #expect(!html.contains("vg-error"))
    }
}
