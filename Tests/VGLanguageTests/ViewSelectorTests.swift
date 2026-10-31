import Testing

@testable import App
@testable import VGLanguage
@testable import VGraph

private let banking = """
    vnotation Banking extends C4 {
        group type: Zone
    }

    vgraph banking: Banking "Internet Banking" {
        node customer: Person "Customer";
        node mainframe: SoftwareSystem "Mainframe";
        group ibs: Zone "Internet Banking System" {
            node web: Container "Web";
            node api: Container "API";
            node db: Database "DB";
        }
        edge customer -> web;
        edge web -> api;
        edge api -> db;
        edge api -> mainframe;
    }
    """

private let everyNode: Set<String> = ["customer", "mainframe", "web", "api", "db"]

private func parse(_ source: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(source: source)
}

private func parseFails(_ source: String, mentioning fragment: String) {
    do {
        _ = try parse(source)
        Issue.record("expected a parse error mentioning '\(fragment)'")
    } catch {
        #expect("\(error)".contains(fragment), "\(error)")
    }
}

private func document(_ rules: String) -> String {
    banking + "\n\nvview v {\n\(rules)\n}\n"
}

/// What a view shows, as ids: nodes, groups and edges ("a->b").
private struct Shown: Equatable {
    var nodes: Set<String>
    var groups: Set<String>
    var edges: Set<String>

    init(nodes: Set<String>, groups: Set<String> = [], edges: Set<String> = []) {
        self.nodes = nodes
        self.groups = groups
        self.edges = edges
    }

    init(_ graph: VGraph) {
        nodes = Set(graph.nodes.map { $0.id })
        groups = Set(graph.groups.map { $0.id.id })
        edges = Set(graph.edges.map { "\($0.from.id)->\($0.to.id)" })
    }
}

private let allEdges: Set<String> = ["customer->web", "web->api", "api->db", "api->mainframe"]

private func shown(_ rules: String) throws -> Shown {
    Shown(try parse(document(rules)).displaying(view: "v"))
}

private func nodesShown(_ rules: String) throws -> Set<String> {
    try shown(rules).nodes
}

private func viewBlock(_ name: String, in exported: String) -> String {
    guard let start = exported.range(of: "vview \(name)") else { return "" }
    let rest = exported[start.lowerBound...]
    guard let end = rest.range(of: "\n}\n") else { return String(rest) }
    return String(rest[..<end.upperBound])
}

@Suite("View selectors: which elements a view shows")
struct ViewSelectorShownTests {

    // MARK: starting set

    @Test("Given a view whose first rule is exclude, when shown, then it starts from everything and loses what is excluded")
    func firstRuleExclude() throws {
        #expect(try nodesShown("exclude node db;") == everyNode.subtracting(["db"]))
    }

    @Test("Given a view whose first rule is include, when shown, then it starts from nothing and shows only what is included")
    func firstRuleInclude() throws {
        #expect(try nodesShown("include node web;") == ["web"])
    }

    @Test("Given a view with only attribute statements, when shown, then everything is shown")
    func attributesOnly() throws {
        #expect(try nodesShown("node db [fontsize: 20];") == everyNode)
    }

    @Test("Given no view named, when shown, then everything is shown, even if the document declares views")
    func noViewNamed() throws {
        let graph = try parse(document("include node web;"))
        #expect(Set(try graph.displaying(view: nil).nodes.map { $0.id }) == everyNode)
    }

    // MARK: selectors

    @Test("Given include node customer, db, then exactly those two nodes are shown")
    func nodeList() throws {
        #expect(try nodesShown("include node customer, db;") == ["customer", "db"])
    }

    @Test("Given include node type: Container, then web and api are shown")
    func nodeType() throws {
        #expect(try nodesShown("include node type: Container;") == ["web", "api"])
    }

    @Test("Given include group ibs, then the group and its three members are shown")
    func group() throws {
        let result = try shown("include group ibs;")
        #expect(result.nodes == ["web", "api", "db"])
        #expect(result.groups == ["ibs"])
    }

    @Test("Given include group type: Zone, then ibs and its members are shown")
    func groupType() throws {
        let result = try shown("include group type: Zone;")
        #expect(result.nodes == ["web", "api", "db"])
        #expect(result.groups == ["ibs"])
    }

    @Test("Given include *, then everything is shown")
    func star() throws {
        let result = try shown("include *;")
        #expect(result == Shown(nodes: everyNode, groups: ["ibs"], edges: allEdges))
    }

    @Test("Given include * then exclude node type: Database, then everything but db is shown")
    func starThenExclude() throws {
        #expect(try nodesShown("include *;\nexclude node type: Database;") == everyNode.subtracting(["db"]))
    }

    @Test("Given exclude group ibs, then the group and its members are gone and customer and mainframe remain")
    func excludeGroup() throws {
        let result = try shown("exclude group ibs;")
        #expect(result.nodes == ["customer", "mainframe"])
        #expect(result.groups.isEmpty)
    }

    // MARK: neighbourhood

    @Test("Given include node customer downstream 1, then customer and web are shown")
    func downstreamOne() throws {
        #expect(try nodesShown("include node customer downstream 1;") == ["customer", "web"])
    }

    @Test("Given include node api upstream 1, then api and web are shown")
    func upstreamOne() throws {
        #expect(try nodesShown("include node api upstream 1;") == ["api", "web"])
    }

    @Test("Given include node api +1, then api, web, db and mainframe are shown")
    func bothWaysOne() throws {
        #expect(try nodesShown("include node api +1;") == ["api", "web", "db", "mainframe"])
    }

    @Test("Given include node customer downstream 2, then customer, web and api are shown")
    func downstreamTwo() throws {
        #expect(try nodesShown("include node customer downstream 2;") == ["customer", "web", "api"])
    }

    @Test("Given include group ibs downstream 1, then ibs, its members and mainframe are shown")
    func groupDownstream() throws {
        let result = try shown("include group ibs downstream 1;")
        #expect(result.nodes == ["web", "api", "db", "mainframe"])
        #expect(result.groups == ["ibs"])
    }

    @Test("Given include node customer downstream 99, then everything reachable from customer is shown and nothing else")
    func downstreamFar() throws {
        #expect(try nodesShown("include node customer downstream 99;") == everyNode)
    }

    // MARK: expand

    @Test("Given include node api then expand 1, then api, web, db and mainframe are shown")
    func expandOne() throws {
        #expect(try nodesShown("include node api;\nexpand 1;") == ["api", "web", "db", "mainframe"])
    }

    @Test("Given include node customer then expand 2, then customer, web and api are shown")
    func expandTwo() throws {
        #expect(try nodesShown("include node customer;\nexpand 2;") == ["customer", "web", "api"])
    }

    @Test("Given exclude node db then expand 1, then everything is shown, because expanding re-includes what is next to the set")
    func expandReincludes() throws {
        #expect(try nodesShown("exclude node db;\nexpand 1;") == everyNode)
    }

    // MARK: ordering and edges

    @Test("Given include node web then exclude node web, then web is not shown")
    func laterExcludeWins() throws {
        #expect(try nodesShown("include node web;\nexclude node web;").isEmpty)
    }

    @Test("Given exclude node web then include node web, then web is shown")
    func laterIncludeWins() throws {
        #expect(try nodesShown("exclude node web;\ninclude node web;") == everyNode)
    }

    @Test("Given include node customer, db, then no real edge is shown, since no edge has both ends shown, only the derived one")
    func noEdgeWithoutBothEnds() throws {
        #expect(try shown("include node customer, db;").edges == ["customer->db"])
    }

    @Test("Given include node web, api, then the web to api edge is shown and no other")
    func edgeWithBothEnds() throws {
        #expect(try shown("include node web, api;").edges == ["web->api"])
    }

    @Test("Given a view showing only db from the group, then the group box is shown around it, and with include node customer no group box is shown")
    func groupBoxFollowsMembers() throws {
        #expect(try shown("include node db;").groups == ["ibs"])
        #expect(try shown("include node customer;").groups.isEmpty)
    }

    @Test("Given include group ibs then exclude node type: Container, Database, then the group is still shown, empty, and its members are gone")
    func explicitGroupStaysWithoutMembers() throws {
        let result = try shown("include group ibs;\nexclude node type: Container, Database;")
        #expect(result.groups == ["ibs"])
        #expect(result.nodes.isEmpty)
    }

    // MARK: unknown ids

    @Test("Given exclude node nothere, then everything is shown")
    func excludeUnknown() throws {
        #expect(try nodesShown("exclude node nothere;") == everyNode)
    }
}

@Suite("View selectors: managing views")
struct ViewSelectorManagementTests {
    @Test("Given a view with rules, when duplicated, then the copy shows the same elements")
    func duplicateKeepsRules() throws {
        let graph = try parse(document("include node customer downstream 1;"))
        let copy = try graph.duplicating(view: "v", as: ViewDeclaration(name: "copy"))
        #expect(Shown(try copy.displaying(view: "copy")) == Shown(try graph.displaying(view: "v")))
        #expect(Set(try copy.displaying(view: "copy").nodes.map { $0.id }) == ["customer", "web"])
    }
}

@Suite("View selectors: VGL in and out")
struct ViewSelectorVGLTests {

    @Test("Given a view with include, exclude and expand rules, when exported, then the rules come back in the order written")
    func rulesKeepTheirOrder() throws {
        let exported = try VGLExporter().export(
            graph: parse(
                document("include node customer downstream 1;\nexclude node type: Database;\nexpand 1;")))
        let block = viewBlock("v", in: exported)
        let first = try #require(block.range(of: "include node customer downstream 1"))
        let second = try #require(block.range(of: "exclude node type: Database"))
        let third = try #require(block.range(of: "expand 1"))
        #expect(first.lowerBound < second.lowerBound)
        #expect(second.lowerBound < third.lowerBound)
    }

    @Test("Given any selector rule, when parsed, exported and parsed again, then the second view shows the same elements as the first")
    func roundTrip() throws {
        let rules = [
            "exclude node db;", "include node web;", "include node customer, db;",
            "include node type: Container;", "include group ibs;", "include group type: Zone;",
            "include *;", "include *;\nexclude node type: Database;", "exclude group ibs;",
            "include node customer downstream 1;", "include node api upstream 1;", "include node api +1;",
            "include node customer downstream 2;", "include group ibs downstream 1;",
            "include node api;\nexpand 1;", "include node customer;\nexpand 2;",
            "exclude node db;\nexpand 1;", "include node web;\nexclude node web;",
            "exclude node web;\ninclude node web;",
        ]
        for rule in rules {
            let first = try parse(document(rule))
            let exported = try VGLExporter().export(graph: first)
            let second = try parse(exported)
            #expect(
                Shown(try first.displaying(view: "v")) == Shown(try second.displaying(view: "v")), "\(rule)")
        }
    }

    @Test("Given a view with rules and attribute statements, when exported, then the rules come first and the attribute statements follow, unchanged")
    func rulesBeforeAttributes() throws {
        let exported = try VGLExporter().export(
            graph: parse(document("node db [fontsize: 20];\ninclude node web;")))
        let block = viewBlock("v", in: exported)
        let rule = try #require(block.range(of: "include node web"))
        let attribute = try #require(block.range(of: "node db [fontsize: 20]"))
        #expect(rule.lowerBound < attribute.lowerBound)
    }

    @Test("Given include node nothere, when exported, then the id is written back unchanged")
    func unknownIdSurvives() throws {
        let exported = try VGLExporter().export(graph: parse(document("include node nothere;")))
        #expect(viewBlock("v", in: exported).contains("include node nothere"))
    }

    @Test("Given include node customer with attributes, when parsed, then it fails saying include only chooses elements")
    func includeSetsNothing() {
        parseFails(document("include node customer [fontsize: 20];"), mentioning: "include only chooses")
    }

    @Test("Given expand without a number or with a word, when parsed, then it fails saying expand needs a whole number")
    func expandNeedsANumber() {
        parseFails(document("expand;"), mentioning: "expand needs a whole number")
        parseFails(document("expand x;"), mentioning: "expand needs a whole number")
    }

    @Test("Given include node customer downstream without a number, when parsed, then it fails saying the distance is missing")
    func distanceMissing() {
        parseFails(document("include node customer downstream;"), mentioning: "distance")
    }

    @Test("Given include edge or an edge statement, when parsed, then it fails saying edges are never selected")
    func edgesAreNeverSelected() {
        parseFails(document("include edge customer -> web;"), mentioning: "edges are never selected")
        parseFails(document("edge customer -> web;"), mentioning: "edges are never selected")
    }
}
