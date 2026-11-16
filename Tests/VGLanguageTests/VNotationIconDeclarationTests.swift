// `icon <name> [viewBox: …, path: …]` — the fourth thing a vnotation body may
// say. `icon:` on a node type is unchanged, which is what keeps built-in
// notations and existing documents untouched (ADR-0022).

import Testing
import VGLanguage
import VGraph

@Suite("An icon a vnotation declares")
struct VNotationIconDeclarationTests {

    private static let flamePath = "M12 2c0.5,3.5 -4,5 -4,9 a4,4 0 0 0 8,0 c0,-2 -2,-4 -4,-7z"

    private func parse(_ vgl: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    private func notation(icons: String, nodeTypeIcon: String = "flame") -> String {
        """
        vnotation RiskMap {
        \(icons)
            node type: Risk [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "\(nodeTypeIcon)"]
            edge type: rel from: Risk to: Risk
        }

        vgraph rm: RiskMap "Risks" {
            node r1: Risk "Schedule overrun";
        }
        """
    }

    @Test("It reaches the graph as artwork under its name")
    func itReachesTheGraph() throws {
        let graph = try parse(notation(icons: "    icon flame [viewBox: \"0 0 24 24\", path: \"\(Self.flamePath)\"]"))

        let artwork = try #require(graph.declaredIcons["flame"])
        #expect(artwork.path == Self.flamePath)
        #expect(artwork.width == 24)
        #expect(artwork.height == 24)
        #expect(graph.declaredIcons.count == 1)
        #expect(graph.artwork(forIcon: "flame")?.path == Self.flamePath)
        #expect(GenericQualityChecks.unresolvableIcons(graph: graph).isEmpty)
    }

    @Test("A viewBox may have an origin of its own")
    func viewBoxCarriesItsOrigin() throws {
        let graph = try parse(
            notation(icons: "    icon flame [viewBox: \"-2 -2.5 28 30\", path: \"\(Self.flamePath)\"]"))

        let artwork = try #require(graph.declaredIcons["flame"])
        #expect(artwork.minX == -2)
        #expect(artwork.minY == -2.5)
        #expect(artwork.width == 28)
        #expect(artwork.height == 30)
    }

    @Test("It shadows a built-in of the same name")
    func itShadowsABuiltIn() throws {
        let graph = try parse(
            notation(
                icons: "    icon and [viewBox: \"0 0 24 24\", path: \"\(Self.flamePath)\"]",
                nodeTypeIcon: "and"))

        #expect(graph.artwork(forIcon: "and")?.path == Self.flamePath)
    }

    /// The charset is the defence rather than output escaping: a quote that
    /// cannot be *written* beats one every output path has to remember to escape.
    @Test(
        "A path outside the path-data charset is refused",
        arguments: [
            "M0 0\\\"/><script>alert(1)</script>",
            "M0 0 <tspan>",
            "url(#x)",
            "M0 0 &#65;",
        ])
    func aPathOutsideTheCharsetIsRefused(_ path: String) {
        // A lexer error would also refuse the document, so the message says which guard did.
        let error = #expect(throws: VError.self) {
            try parse(notation(icons: "    icon flame [viewBox: \"0 0 24 24\", path: \"\(path)\"]"))
        }
        guard case .parsingError(let message) = error else {
            Issue.record("Expected a parsingError, got \(String(describing: error))")
            return
        }
        #expect(message.contains("not drawable"), "\(message)")
    }

    @Test("A path over the size cap is refused")
    func anOversizePathIsRefused() {
        let huge = String(repeating: "M0 0h1v1h-1z ", count: 400)
        #expect(huge.count > 4096)
        #expect(throws: VError.self) {
            try parse(notation(icons: "    icon flame [viewBox: \"0 0 24 24\", path: \"\(huge)\"]"))
        }
    }

    @Test(
        "A viewBox that is not four numbers is refused",
        arguments: ["0 0 24", "0 0 24 24 24", "0 0 24 wide", ""])
    func aBadViewBoxIsRefused(_ viewBox: String) {
        #expect(throws: VError.self) {
            try parse(notation(icons: "    icon flame [viewBox: \"\(viewBox)\", path: \"M0 0h1v1h-1z\"]"))
        }
    }

    /// No default: a guessed scale renders wrong with nothing to point at, and
    /// anyone with a path to paste has the viewBox next to it.
    @Test("A declaration without a viewBox is refused")
    func aMissingViewBoxIsRefused() {
        #expect(throws: VError.self) {
            try parse(notation(icons: "    icon flame [path: \"M0 0h1v1h-1z\"]"))
        }
    }

    @Test("A declaration without a path is refused")
    func aMissingPathIsRefused() {
        #expect(throws: VError.self) {
            try parse(notation(icons: "    icon flame [viewBox: \"0 0 24 24\"]"))
        }
    }
}

@Suite("Declared artwork through export and back")
struct VNotationIconRoundTripTests {

    private static let flamePath = "M12 2c0.5,3.5 -4,5 -4,9 a4,4 0 0 0 8,0 c0,-2 -2,-4 -4,-7z"

    private static let source = """
        vnotation RiskMap {
            icon flame [viewBox: "-2 -2.5 28 30", path: "\(flamePath)"]
            icon spare [viewBox: "0 0 24 24", path: "M0 0h24v24h-24z"]

            node type: Risk [nodeStyle: iconWithText, backgroundColor: "#cc3333", icon: "flame"]
            edge type: rel from: Risk to: Risk
        }

        vgraph rm: RiskMap "Risks" {
            node r1: Risk "Schedule overrun";
        }
        """

    private func parse(_ vgl: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    @Test("A second parse yields the same artwork")
    func itSurvivesTheRoundTrip() throws {
        let once = try parse(Self.source)
        let twice = try parse(try VGLExporter().export(graph: once))

        #expect(twice.declaredIcons == once.declaredIcons)
    }

    @Test("A document declaring nothing gains no icon line")
    func nothingIsInventedForOtherDocuments() throws {
        let exported = try VGLExporter().export(
            graph: try parse(
                """
                vnotation Plain {
                    node type: Box [nodeStyle: roundedBox, backgroundColor: "#339933"]
                    edge type: rel from: Box to: Box
                }

                vgraph p: Plain "Plain" {
                    node b1: Box "B";
                }
                """))

        #expect(!exported.contains("icon "))
    }
}
