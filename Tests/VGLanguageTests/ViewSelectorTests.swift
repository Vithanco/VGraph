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

private func document(_ rules: String, in model: String = banking) -> String {
    model + "\n\nvview v {\n\(rules)\n}\n"
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

private func nodesShown(_ rules: String, in model: String = banking) throws -> Set<String> {
    Set(try parse(document(rules, in: model)).displaying(view: "v").nodes.map { $0.id })
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

/// `carries` and `offers` each make two propositions; `needs` one more.
private let concepts = """
    vgraph cm: ConceptMap "Propositions" {
        node skill: Concept "Skill"
        node prompt: Concept "Prompt"
        node method: Concept "Method"
        node context: Concept "Context"
        node server: Concept "Server"
        node tool: Concept "Tool"
        node carries: Relation "carries"
        node offers: Relation "offers"
        node needs: Relation "needs"
        edge skill -> carries
        edge prompt -> carries
        edge carries -> method
        edge server -> offers
        edge offers -> tool
        edge offers -> prompt
        edge method -> needs
        edge needs -> context
    }
    """

/// a and b together cause c; b also causes e on its own; c causes d.
private let causes = """
    vgraph crt: CRT "Causes" {
        node a: Changeable "A"
        node b: Changeable "B"
        node and1: AndJunctor
        node c: UndesirableEffect "C"
        node d: UndesirableEffect "D"
        node e: UndesirableEffect "E"
        edge a -> and1
        edge b -> and1
        edge and1 -> c
        edge c -> d
        edge b -> e
    }
    """

/// b is another input of a's AND, and also downstream of a through m.
private let sideways = """
    vgraph crt: CRT "Sideways" {
        node a: Changeable "A"
        node b: Changeable "B"
        node m: Changeable "M"
        node and1: AndJunctor
        node c: UndesirableEffect "C"
        node e: UndesirableEffect "E"
        edge a -> and1
        edge b -> and1
        edge and1 -> c
        edge a -> m
        edge m -> b
        edge b -> e
    }
    """

@Suite("View selectors: reach adds neighbourhoods (ADR-0038)")
struct ViewSelectorNeighborhoodTests {

    @Test("Given include node prompt +1, then every proposition prompt is part of is shown whole, and no other subject of a shared Relation")
    func aroundAConcept() throws {
        #expect(try nodesShown("include node prompt +1;", in: concepts) == ["prompt", "carries", "method", "offers", "server"])
    }

    @Test("Given include node prompt +2, then the propositions of method and server are added too")
    func twiceAroundAConcept() throws {
        #expect(
            try nodesShown("include node prompt +2;", in: concepts) == [
                "prompt", "carries", "method", "offers", "server", "skill", "needs", "context", "tool",
            ])
    }

    @Test("Given include node prompt downstream 1, then only the propositions prompt is subject of are shown")
    func downstreamOfAConcept() throws {
        #expect(try nodesShown("include node prompt downstream 1;", in: concepts) == ["prompt", "carries", "method"])
    }

    @Test("Given include node method upstream 1, then every proposition method is object of is shown, with all their subjects")
    func upstreamOfAConcept() throws {
        #expect(try nodesShown("include node method upstream 1;", in: concepts) == ["method", "carries", "skill", "prompt"])
    }

    @Test("Given include node prompt then expand 1, then the same as include node prompt +1 is shown")
    func expandAddsANeighborhood() throws {
        #expect(try nodesShown("include node prompt;\nexpand 1;", in: concepts) == ["prompt", "carries", "method", "offers", "server"])
    }

    @Test("Given include node a downstream 1, then the AND is shown with all its inputs and its output")
    func downstreamThroughAnAnd() throws {
        #expect(try nodesShown("include node a downstream 1;", in: causes) == ["a", "and1", "b", "c"])
    }

    @Test("Given include node a downstream 2, then it goes on from the AND's output only, not from its other input")
    func downstreamGoesOnInItsDirection() throws {
        #expect(try nodesShown("include node a downstream 2;", in: causes) == ["a", "and1", "b", "c", "d"])
    }

    @Test("Given include node a +2, then it goes on from every node the first round reached")
    func aroundGoesOnFromEverything() throws {
        #expect(try nodesShown("include node a +2;", in: causes) == ["a", "and1", "b", "c", "d", "e"])
    }

    @Test("Given include node and1 downstream 1, then the AND is shown with its inputs as well as its output")
    func downstreamFromAnAnd() throws {
        #expect(try nodesShown("include node and1 downstream 1;", in: causes) == ["and1", "a", "b", "c"])
    }

    @Test("Given include node carries downstream 1, then its subjects come as well as its object")
    func downstreamFromARelation() throws {
        #expect(try nodesShown("include node carries downstream 1;", in: concepts) == ["carries", "skill", "prompt", "method"])
    }

    @Test("Given include node carries downstream 2, then the second round goes on from its object only")
    func downstreamFromARelationGoesOnFromItsObject() throws {
        #expect(
            try nodesShown("include node carries downstream 2;", in: concepts) == [
                "carries", "skill", "prompt", "method", "needs", "context",
            ])
    }

    @Test("Given include node carries upstream 2, then the second round goes on from its subjects only")
    func upstreamFromARelationGoesOnFromItsSubjects() throws {
        #expect(
            try nodesShown("include node carries upstream 2;", in: concepts) == [
                "carries", "skill", "prompt", "method", "offers", "server",
            ])
    }

    @Test("Given include node and1, c downstream 1, then the AND brings its whole claim and c only what it causes")
    func startsMixingAnAndAndAnOrdinaryNode() throws {
        #expect(try nodesShown("include node and1, c downstream 1;", in: causes) == ["and1", "a", "b", "c", "d"])
    }

    @Test("Given a node first reached as another input of an AND and later downstream, then downstream goes on from it")
    func downstreamGoesOnFromANodeFirstReachedSideways() throws {
        #expect(try nodesShown("include node a downstream 2;", in: sideways) == ["a", "and1", "b", "c", "m"])
        #expect(try nodesShown("include node a downstream 3;", in: sideways) == ["a", "and1", "b", "c", "m", "e"])
    }

    @Test("Given exclude node prompt +1, then prompt's whole neighbourhood goes")
    func excludeANeighborhood() throws {
        #expect(try nodesShown("exclude node prompt +1;", in: concepts) == ["skill", "context", "tool", "needs"])
    }

    @Test("Given include node c upstream 1, then the AND is shown with all its inputs")
    func upstreamThroughAnAnd() throws {
        #expect(try nodesShown("include node c upstream 1;", in: causes) == ["c", "and1", "a", "b"])
    }
}
