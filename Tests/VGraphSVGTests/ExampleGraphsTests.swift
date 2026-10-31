import Testing

@testable import App
@testable import TestSupport
@testable import VGraph

/// The examples are VGL held as text, so nothing else notices one going stale.
/// Each runs the whole chain a user would: parse, check, lay out, render, save.
@Suite("The example graphs")
struct ExampleGraphsTests {
    private let app = VGraphTestApp()

    @Test("Given the examples, then there are some and their names are unique")
    func namesAreUnique() {
        #expect(!exampleGraphs.isEmpty)
        #expect(Set(exampleGraphs.map { $0.name }).count == exampleGraphs.count)
    }

    @Test("Given an example, when parsed, then it has nodes", arguments: exampleGraphs)
    func parses(example: ExampleGraph) throws {
        let graph = try app.parseGraph(example.vgl)
        #expect(!graph.nodes.isEmpty)
    }

    @Test("Given an example, when rendered, then it draws an SVG and its quality report is clean", arguments: exampleGraphs)
    func renders(example: ExampleGraph) throws {
        let result = try app.renderGraph(example.vgl)
        #expect(result.svg.contains("<svg"))
        #expect(result.qualityReport.isClean, "\(result.qualityReport.messages.map { $0.message })")
    }

    @Test("Given an example, when saved as VGL, then saving again changes nothing", arguments: exampleGraphs)
    func saveIsStable(example: ExampleGraph) throws {
        let once = try app.exportToVGL(example.vgl)
        #expect(try app.exportToVGL(once) == once)
    }

    @Test("Given the notation registry, then every notation has an example")
    func everyNotationHasOne() throws {
        let shown = try Set(exampleGraphs.map { try app.parseGraph($0.vgl).notationName })
        let missing = NotationRegistry.entries.map { $0.id }.filter { !shown.contains($0) }
        #expect(missing.isEmpty, "add an example graph for: \(missing)")
    }

    @Test("Given the extension registry, then every extension has an example")
    func everyExtensionHasOne() throws {
        let shown = try Set(exampleGraphs.flatMap { try app.parseGraph($0.vgl).notationDefinition.extensions })
        let missing = NotationRegistry.extensionEntries.map { $0.id }.filter { !shown.contains($0) }
        #expect(missing.isEmpty, "add an example graph for: \(missing)")
    }

    private var banking: ExampleGraph? { exampleGraphs.first { $0.name.hasPrefix("C4 — Internet Banking") } }

    private static let people = ["customer", "serviceStaff", "backOfficeStaff"]
    private static let externalSystems = ["atm", "cbs", "ses"]
    private static let containers = ["staticContent", "ui", "statementStore", "database"]
    private static let components = [
        "statementApi", "signInApi", "accountsSummaryApi", "statementComponent", "securityComponent", "emailComponent",
    ]
    private static let code = [
        "adapterInterface", "adapterImpl", "connection", "response", "request", "bankAccountsResponse",
        "bankAccountsRequest",
    ]
    private static let groups = ["bigBank", "aws", "ibs", "backend", "adapter"]

    /// The elements a view draws, by the id the renderer stamps on each.
    private func drawn(_ view: String?) throws -> Set<String> {
        let example = try #require(banking)
        let svg = try app.renderGraph(example.vgl, view: view).svg
        let nodes = Self.people + Self.externalSystems + Self.containers + Self.components + Self.code
        return Set(nodes.filter { svg.contains("id=\"node-\($0)\"") }).union(
            Self.groups.filter { svg.contains("id=\"group-\($0)\"") }.map { "group:\($0)" })
    }

    @Test("Given the C4 banking example, when its views are listed, then they are c4model.com's five, titled as there")
    func bankingViews() throws {
        let example = try #require(banking)
        let views = try app.parseGraph(example.vgl).views
        #expect(views.map { $0.name } == ["landscape", "context", "containers", "components", "code"])
        #expect(
            views.map { $0.label } == [
                "System Landscape View",
                "System Context View: Internet Banking System",
                "Container View: Internet Banking System",
                "Component View: Internet Banking System - Backend",
                "Code View: Internet Banking System - Backend - Core Banking System Adapter",
            ])
    }

    @Test("Given the C4 banking example, when the default view is rendered, then the whole model is drawn unfolded")
    func bankingModel() throws {
        let everything = Self.people + Self.externalSystems + Self.containers + Self.components + Self.code
        #expect(try drawn(nil) == Set(everything + Self.groups.map { "group:\($0)" }))
    }

    @Test(
        "Given the C4 banking example, when the landscape view is rendered, then every person and system is drawn and the banking system is one box"
    )
    func bankingLandscape() throws {
        #expect(
            try drawn("landscape")
                == Set(Self.people + Self.externalSystems + ["group:ibs", "group:bigBank", "group:aws"]))
    }

    @Test(
        "Given the C4 banking example, when the context view is rendered, then only the banking system and what it talks to are drawn"
    )
    func bankingContext() throws {
        #expect(try drawn("context") == ["customer", "cbs", "ses", "group:ibs", "group:bigBank", "group:aws"])
    }

    @Test(
        "Given the C4 banking example, when the container view is rendered, then the banking system's containers and their neighbours are drawn and the backend is one box"
    )
    func bankingContainers() throws {
        #expect(
            try drawn("containers")
                == Set(
                    Self.containers + [
                        "customer", "cbs", "ses", "group:ibs", "group:backend", "group:bigBank", "group:aws",
                    ]))
    }

    @Test(
        "Given the C4 banking example, when the component view is rendered, then the backend's components and their neighbours are drawn and the adapter is one box"
    )
    func bankingComponents() throws {
        #expect(
            try drawn("components")
                == Set(
                    Self.components + [
                        "ui", "statementStore", "database", "cbs", "ses", "group:ibs", "group:backend",
                        "group:adapter", "group:bigBank", "group:aws",
                    ]))
    }

    @Test(
        "Given the C4 banking example, when the code view is rendered, then only the adapter's code is drawn, inside its boundaries"
    )
    func bankingCode() throws {
        #expect(
            try drawn("code")
                == Set(Self.code + ["group:adapter", "group:backend", "group:ibs", "group:bigBank"]))
    }

    @Test("Given the C4 banking example, when saved as VGL, then each zoom level's view still folds its node type")
    func bankingViewsSurviveSaving() throws {
        let example = try #require(banking)
        let saved = try app.exportToVGL(example.vgl)
        for type in ["SoftwareSystem", "Container", "Component"] {
            #expect(saved.contains("folded node type: \(type)"), "\(type)")
        }
    }

    @Test("Given the C4 banking example, then each system outside the Internet Banking System has a colour of its own")
    func bankingExternalsColouredPerNode() throws {
        let example = try #require(banking)
        let graph = try app.parseGraph(example.vgl)
        let colours = try Self.externalSystems.map { id in
            let node = try #require(graph.nodes.first { $0.id == id })
            return try graph.get(node: node, attribute: Attributes.Node.backgroundColor)
        }
        #expect(Set(colours).count == Self.externalSystems.count)
    }
}
