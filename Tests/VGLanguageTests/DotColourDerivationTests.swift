import Testing
import VGraph
import VGraphvizLib

@testable import VGLanguage

@Suite("DOT colour is derived, not stored")
struct DotColourDerivationTests {

    private func dot(_ vgl: String) throws -> String {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
        return try DotExporter().export(graph: graph)
    }

    private func graph(_ vgl: String) throws -> VGraph {
        try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    private func nodeLine(_ dot: String, _ id: String) throws -> String {
        try #require(dot.split(separator: "\n").first { $0.contains("\t\(id) [") }).description
    }

    private func color(_ line: String) -> String? {
        guard let r = line.range(of: "color=\"") else { return nil }
        let rest = line[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    @Test(arguments: [
        ("IBIS", "Question"), ("IBIS", "Answer"), ("IBIS", "Pro"),
        ("C4", "Container"), ("C4", "Person"), ("C4", "SoftwareSystem"),
        ("ConceptMap", "Concept"),
        ("GoalTree", "Goal"),
        ("ImpactMapping", "Actor"),
        ("BBS", "Benefit"),
        ("Timeline", "Event"),
    ])
    func dotColourEqualsRenderedFill(notation: String, typeName: String) throws {
        let vgl = """
            vgraph t: \(notation) "T" {
                node n1: \(typeName) "N"
            }
            """
        let g = try graph(vgl)
        let fill = try #require(
            g.effectiveNodeLayout(for: NodeType(string: typeName))?.backgroundFill,
            "\(notation).\(typeName) should have a fill")
        let exported = try #require(color(try nodeLine(try dot(vgl), "n1")))
        #expect(exported.hasPrefix(fill.hexString), "\(notation).\(typeName): \(exported) vs \(fill.hexString)")
    }

    @Test func siblingTypesKeepDistinctColours() throws {
        let vgl = """
            vgraph t: IBIS "T" {
                node q: Question "Q"
                node a: Answer "A"
                node p: Pro "P"
                node c: Con "C"
                edge q -> a
                edge a -> p
                edge a -> c
            }
            """
        let d = try dot(vgl)
        let colors = try ["q", "a", "p", "c"].map { try #require(color(try nodeLine(d, $0))) }
        #expect(Set(colors).count == 4)
    }

    /// What licenses deriving the colour at all.
    @Test func colourDoesNotAffectLayout() throws {
        func positions(_ colour: String) throws -> [String] {
            let vgl = """
                vgraph t: IBIS "T" {
                    node q: Question "Q" [color: "\(colour)"]
                    node a: Answer "A"
                    edge q -> a
                }
                """
            let d = try dot(vgl)
            return d.split(separator: "\n")
                .filter { $0.contains("width=") || $0.contains("height=") }
                .map { line in
                    line.split(separator: ",")
                        .filter { $0.contains("width=") || $0.contains("height=") || $0.contains("shape=") }
                        .joined(separator: ",")
                }
        }
        #expect(try positions("#ff0000") == positions("#00ff00"))
    }

    @Test func nodeColourOverridesItsType() throws {
        let vgl = """
            vgraph t: C4 "T" {
                node p: Person "Op"
                group s "Sys" {
                    node plain: Container "Plain"
                    node tinted: Container "Tinted" [color: "#b6e6bd"]
                }
                edge p -> plain "Uses"
                edge p -> tinted "Uses"
            }
            """
        let d = try dot(vgl)
        #expect(try color(nodeLine(d, "tinted"))?.hasPrefix("#b6e6bd") == true)
        #expect(try color(nodeLine(d, "plain"))?.hasPrefix("#438dd5") == true)
    }
}

@Suite("A colour name survives export")
struct ColourNameRoundTripTests {

    private func roundTrip(_ vgl: String) throws -> String {
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
        return try VGLExporter().export(graph: graph)
    }

    /// Why the name needs no field of its own: the store keeps what was written,
    /// not what it parsed to.
    @Test func nameIsPreservedNotNormalisedToHex() throws {
        let exported = try roundTrip(
            """
            vgraph t: IBIS "T" {
                node q: Question "Q" [color: cornflowerblue]
                node a: Answer "A" [color: "#b6e6bd"]
                edge q -> a
            }
            """)
        #expect(exported.contains("cornflowerblue"))
        #expect(!exported.contains("#6495ed"), "the name must not be normalised away")
        #expect(exported.contains("#b6e6bd"), "hex stays hex")
    }

    /// One colour, two names — so nothing may derive a name back from a value.
    @Test func synonymsBothSurvive() throws {
        for name in ["grey", "gray"] {
            let exported = try roundTrip(
                """
                vgraph t: IBIS "T" {
                    node q: Question "Q" [color: \(name)]
                    node a: Answer "A"
                    edge q -> a
                }
                """)
            #expect(exported.contains(name))
        }
    }
}
