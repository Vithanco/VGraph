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
        group bankingSystem: Zone "Internet Banking" {
            node web: Container "Web App";
            node db: Database "Database";
        }
        edge customer -> web;
        edge web -> db;
    }
    """

private let views = """

    vview context "System Context" {
        folded group type: Zone;
    }

    vview containers "Containers" [rankdir: LR] {
        node db [backgroundColor: "#ffd27f"];
        node customer, web [fontsize: 16];
    }
    """

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

/// The way the parser builds a value, so the stored strings are comparable.
private func fontsize(_ value: String, in graph: VGraph) throws -> Attribute {
    try graph.attributeDefinitions[Attributes.Node.fontsize.id]!.attribute(fromString: value)
}

private func viewBlock(_ name: String, in exported: String) -> String {
    guard let start = exported.range(of: "vview \(name)") else { return "" }
    let rest = exported[start.lowerBound...]
    guard let end = rest.range(of: "\n}\n") else { return String(rest) }
    return String(rest[..<end.upperBound])
}

@Suite("vview blocks: parse and export")
struct ViewDeclarationTests {

    @Test("Given two views, when parsed, then the graph lists them in declaration order with their labels")
    func viewsAreListed() throws {
        let graph = try parse(banking + views)
        #expect(graph.views.map { $0.name } == ["context", "containers"])
        #expect(graph.views.map { $0.label } == ["System Context", "Containers"])
    }

    @Test("Given a document with two views, when parsed and exported, then both views come back and a second pass changes nothing")
    func roundTrip() throws {
        let first = try VGLExporter().export(graph: parse(banking + views))
        let second = try VGLExporter().export(graph: parse(first))
        #expect(first == second)
        #expect(first.contains("vview context \"System Context\""))
        #expect(first.contains("vview containers \"Containers\""))
        #expect(viewBlock("context", in: first).contains("folded group type: Zone"))
        #expect(viewBlock("containers", in: first).contains("node db [backgroundcolor: \"#ffd27f\"]"))
        #expect(viewBlock("containers", in: first).contains("node customer [fontsize: 16]"))
    }

    @Test("Given a view with a label and no body, when parsed and exported twice, then the view survives and the second pass changes nothing")
    func emptyViewRoundTrips() throws {
        let graph = try parse(banking + "\nvview containers \"Containers\" {\n}\n")
        #expect(graph.views.map { $0.name } == ["containers"])
        let first = try VGLExporter().export(graph: graph)
        #expect(first.contains("vview containers \"Containers\""))
        let second = try VGLExporter().export(graph: parse(first))
        #expect(first == second)
    }

    @Test("Given views, when exported, then they follow the vgraph block in declaration order")
    func viewsFollowTheModel() throws {
        let exported = try VGLExporter().export(graph: parse(banking + views))
        let model = try #require(exported.range(of: "vgraph banking"))
        let context = try #require(exported.range(of: "vview context"))
        let containers = try #require(exported.range(of: "vview containers"))
        #expect(model.lowerBound < context.lowerBound)
        #expect(context.lowerBound < containers.lowerBound)
    }

    @Test("Given a view value equal to the model's, when exported, then it leaves the file")
    func prunedAgainstTheModel() throws {
        let source =
            banking.replacingOccurrences(
                of: "node db: Database \"Database\"", with: "node db: Database \"Database\" [fontsize: 20]")
            + "\nvview v {\n node db [fontsize: 20];\n node web [fontsize: 20];\n}\n"
        let exported = try VGLExporter().export(graph: parse(source))
        let block = viewBlock("v", in: exported)
        #expect(block.contains("vview v"))
        #expect(!block.contains("node db"))
        #expect(block.contains("node web"))
    }

    @Test("Given a view that names an id the model lacks, when exported, then the statement is kept")
    func unknownIdSurvives() throws {
        let source = banking + "\nvview v {\n node ghost [fontsize: 31];\n group nowhere [isFolded: true];\n}\n"
        let graph = try parse(source)
        let exported = try VGLExporter().export(graph: graph)
        #expect(viewBlock("v", in: exported).contains("node ghost [fontsize: 31]"))
        #expect(viewBlock("v", in: exported).contains("folded group nowhere"))
        _ = try graph.displaying(view: "v")
    }

    @Test("Given two views, when one is changed, then the other is not")
    func viewsAreIndependent() throws {
        let graph = try parse(banking + views)
        let key = ItemKey(.node, "db")
        let before = try graph.attributes(inView: "context", of: key)
        let changed = try graph.settingInView("containers", fontsize("33", in: graph), for: key)
        #expect(try changed.attributes(inView: "context", of: key) == before)
        #expect(try changed.attributes(inView: "containers", of: key)[Attributes.Node.fontsize.id] == "33")
    }

    @Test("Given a view value equal to the model's, when the model changes to match, then the view value goes too")
    func viewFollowsTheModel() throws {
        let graph = try parse(banking + "\nvview v {\n node db [fontsize: 20];\n}\n")
        let key = ItemKey(.node, "db")
        #expect(try graph.attributes(inView: "v", of: key)[Attributes.Node.fontsize.id] == "20")
        let matched = try graph.update(node: Node(string: "db"), attribute: fontsize("20", in: graph))
        #expect(try matched.attributes(inView: "v", of: key).isEmpty)
    }

    /// The notation colours Database, the model recolours db, and the view
    /// asks for the notation's colour back on the type.
    private let recolouredDatabase =
        banking
        .replacingOccurrences(
            of: "group type: Zone", with: "group type: Zone\n    node type: Database [backgroundColor: \"#ffd27f\"]"
        )
        .replacingOccurrences(
            of: "node db: Database \"Database\"", with: "node db: Database \"Database\" [backgroundColor: \"#aaaaaa\"]")
        + "\nvview v {\n node type: Database [backgroundColor: \"#ffd27fff\"];\n}\n"

    @Test(
        "Given a model value on an element, when a view sets its type back to the notation's value, then the view keeps it and wins (ADR-0030: the layer comes first)"
    )
    func viewTypeValueBeatsModelElementValue() throws {
        let graph = try parse(recolouredDatabase)
        let db = Node(string: "db")
        #expect(try graph.get(node: db, attribute: Attributes.Node.backgroundColor).hexString == "#aaaaaa")
        #expect(try graph.displaying(view: "v").get(node: db, attribute: Attributes.Node.backgroundColor).hexString == "#ffd27f")
        let exported = try VGLExporter().export(graph: graph)
        #expect(viewBlock("v", in: exported).contains("node type: Database [backgroundcolor: \"#ffd27fff\"]"))
    }

    @Test("Given a view type value that only beats a model value, when the model value goes, then the view value goes too")
    func viewTypeValueFollowsTheModel() throws {
        let graph = try parse(recolouredDatabase)
        let matched = graph.erasing(Attributes.Node.backgroundColor.id, for: ItemKey(.node, "db"))
        #expect(try matched.attributes(inView: "v", of: ItemKey(.nodeType, "Database")).isEmpty)
    }

    @Test("Given an element a view styles, when it is deleted, then every layer forgets it")
    func deleteReachesViews() throws {
        let graph = try parse(banking + views)
        let key = ItemKey(.node, "db")
        #expect(!(try graph.attributes(inView: "containers", of: key)).isEmpty)
        let deleted = try graph.delete(node: Node(string: "db"))
        #expect(try deleted.attributes(inView: "containers", of: key).isEmpty)
    }

    @Test("Given views, when the store lists its layers, then each view is one of them")
    func storeListsLayers() throws {
        let layers = try parse(banking + views).ads.layerNames.map { $0.rawValue }
        for expected in ["engine", "builtin", "vnotation", "model", "view:context", "view:containers"] {
            #expect(layers.contains(expected))
        }
    }

    @Test("Given a view sharing a name with an element, when parsed, then it is accepted")
    func viewMayShareANameWithAnElement() throws {
        let graph = try parse(banking + "\nvview web {\n}\n")
        #expect(graph.views.map { $0.name } == ["web"])
    }
}

@Suite("vview blocks: what a view may say")
struct ViewDeclarationErrorTests {

    @Test("A vview inside the vgraph block is an error")
    func insideTheModel() {
        parseFails(banking.replacingOccurrences(of: "edge web -> db;", with: "vview v {}\n edge web -> db;"), mentioning: "vview")
    }

    @Test("A vview before the vgraph block is an error")
    func beforeTheModel() {
        parseFails("vview v {\n}\n" + banking, mentioning: "vview")
    }

    @Test("Two views with one name are an error")
    func duplicateName() {
        parseFails(banking + "\nvview v {\n}\nvview v {\n}\n", mentioning: "'v'")
    }

    @Test("A type on a node in a view is an error saying a view sets presentation only")
    func typeOnNode() {
        parseFails(banking + "\nvview v {\n node db: Database;\n}\n", mentioning: "presentation")
    }

    @Test("A label on a node in a view is an error saying a view sets presentation only")
    func labelOnNode() {
        parseFails(banking + "\nvview v {\n node db \"Other\";\n}\n", mentioning: "presentation")
    }

    @Test("A group with members in a view is an error saying a view sets presentation only")
    func groupWithMembers() {
        parseFails(banking + "\nvview v {\n group g {\n node x;\n }\n}\n", mentioning: "presentation")
    }

    @Test("A content attribute in a view is an error saying a view sets presentation only")
    func contentAttribute() {
        parseFails(banking + "\nvview v {\n node db [label: \"Other\"];\n}\n", mentioning: "presentation")
        parseFails(banking + "\nvview v [label: \"Other\"] {\n}\n", mentioning: "presentation")
    }

    @Test(
        "Selectors in an attribute statement are errors saying they are not supported yet",
        arguments: ["node *;", "group *;", "node +db;", "node downstream db;", "node upstream db;"])
    func notSupportedYet(_ statement: String) {
        parseFails(banking + "\nvview v {\n \(statement)\n}\n", mentioning: "not supported yet")
    }
}

@Suite("vview blocks: what a view shows")
struct ViewDisplayTests {
    private func isFolded(_ graph: VGraph) throws -> Bool {
        try graph.get(group: Group(rawValue: "bankingSystem"), attribute: Attributes.Group.isFolded)
    }

    @Test("Given a view folding a group type, when displayed, then the group is folded there and not in the model")
    func viewFoldsAGroupType() throws {
        let graph = try parse(banking + views)
        #expect(try !isFolded(graph))
        #expect(try isFolded(graph.displaying(view: "context")))
        #expect(try !isFolded(graph.displaying(view: "containers")))
    }

    @Test("Given no view name, when displayed, then the model is shown, even if the document declares views")
    func theModelIsTheDefaultView() throws {
        let graph = try parse(banking + views)
        let shown = try graph.displaying(view: nil)
        #expect(try !isFolded(shown))
        #expect(
            try shown.getAttributes(node: Node(string: "db")) == graph.getAttributes(node: Node(string: "db")))
    }

    @Test("Given a group the model folds, when a view unfolds it, then it is unfolded there")
    func viewUnfolds() throws {
        let source =
            banking.replacingOccurrences(of: "group bankingSystem", with: "folded group bankingSystem")
            + "\nvview open {\n group bankingSystem [isFolded: false];\n}\n"
        let graph = try parse(source)
        #expect(try isFolded(graph))
        #expect(try !isFolded(graph.displaying(view: "open")))
        let exported = try VGLExporter().export(graph: graph)
        #expect(viewBlock("open", in: exported).contains("group bankingSystem [isfolded: false]"))
    }

    @Test("Given a view, when displayed, then its element and type values are what the display graph resolves")
    func viewValuesResolve() throws {
        let shown = try parse(banking + views).displaying(view: "containers")
        let db = try shown.getAttributes(node: Node(string: "db"))
        #expect(db[Attributes.Node.backgroundColor.id]?.lowercased() == "#ffd27f")
        #expect(
            try shown.getGraphAttributes()[Attributes.Group.layoutDirection.id]
                != parse(banking).getGraphAttributes()[Attributes.Group.layoutDirection.id])
    }

    @Test("Given a view the document lacks, when displayed, then the error lists the views it has")
    func unknownView() throws {
        let graph = try parse(banking + views)
        do {
            _ = try graph.displaying(view: "nope")
            Issue.record("expected an error")
        } catch {
            #expect("\(error)".contains("nope"))
            #expect("\(error)".contains("context"))
            #expect("\(error)".contains("containers"))
        }
    }

    @Test("Given views, when quality is judged, then the findings equal those without views")
    func qualityNeverSeesAView() throws {
        let app = VGraphApplication(ports: ParseOnlyPorts(logger: NoOpLogger()))
        let without = try app.analyzeQuality(banking)
        let with = try app.analyzeQuality(banking + views)
        #expect(with.messages.map { $0.message } == without.messages.map { $0.message })
    }
}

@Suite("vview blocks: rendering by name")
struct ViewRenderTests {
    private let app = VGraphApplication(ports: NativePorts(logger: NoOpLogger()))

    /// The picture carries the document's text; what is drawn is the rest.
    private func drawing(_ source: String, view: String? = nil) throws -> String {
        let svg = try app.renderGraph(source, view: view).svg
        return svg.replacingOccurrences(of: try #require(app.sourceVGL(from: svg)), with: "").lowercased()
    }

    @Test("Given the banking document, when rendered as context and as containers, then the pictures differ")
    func viewsRenderDifferently() throws {
        let source = banking + views
        let context = try drawing(source, view: "context")
        let containers = try drawing(source, view: "containers")
        #expect(context != containers)
        #expect(!context.contains("node-web"))
        #expect(containers.contains("node-web"))
        #expect(containers.contains("#ffd27f"))
        #expect(!context.contains("#ffd27f"))
    }

    @Test("Given views, when rendered without a name, then the model is shown")
    func defaultIsTheModel() throws {
        let model = try drawing(banking + views)
        #expect(model.contains("node-web"))
        #expect(!model.contains("#ffd27f"))
    }

    @Test("Given a view the document lacks, when rendered, then the error lists the views it has")
    func unknownView() throws {
        do {
            _ = try app.renderGraph(banking + views, view: "nope")
            Issue.record("expected an error")
        } catch {
            #expect("\(error)".contains("context"))
        }
    }
}
