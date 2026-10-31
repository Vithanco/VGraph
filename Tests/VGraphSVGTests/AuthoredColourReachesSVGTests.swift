// One case per path that resolves an authored colour. A new path needs a new
// case here: each of these once dropped the colour silently.

import TestSupport
import Testing
import VGraph

@testable import App

@Suite("An authored colour reaches the SVG")
struct AuthoredColourReachesSVGTests {

    private func svg(_ vgl: String) throws -> String {
        let app = VGraphTestApp()
        return try app.renderGraph(graph: try app.parseGraph(vgl), sourceVGL: vgl).svg
    }

    @Test func namedFontColourOnTheGraphLabel() throws {
        let out = try svg(
            """
            vgraph t: IBIS "Titled" {
                fontcolor: darkblue;
                node q: Question "Q";
                node a: Answer "A";
                edge q -> a;
            }
            """)
        #expect(out.contains("#00008b"))
    }

    @Test func namedColourOnAnEdge() throws {
        let out = try svg(
            """
            vgraph t: IBIS "T" {
                node q: Question "Q";
                node a: Answer "A";
                edge q -> a [color: crimson];
            }
            """)
        #expect(out.contains("#dc143c"))
    }

    @Test func hexOnAnEdgeStillWorks() throws {
        let out = try svg(
            """
            vgraph t: IBIS "T" {
                node q: Question "Q";
                node a: Answer "A";
                edge q -> a [color: "#b6e6bd"];
            }
            """)
        #expect(out.contains("#b6e6bd"))
    }

    /// `color` is the older spelling; `backgroundColor` is what a document
    /// exports. Both reach the same fill, whatever the casing.
    @Test(arguments: ["color", "backgroundColor", "backgroundcolor", "COLOR"])
    func eitherSpellingOfAVNotationColourKey(key: String) throws {
        let out = try svg(
            """
            vnotation Q {
                node type: A [nodeStyle: simpleRoundedText, \(key): "#2e8b57"]
                edge type: rel from: A to: A
            }
            vgraph g: Q "G" {
                node x: A "X";
                node y: A "Y";
                edge x -> y;
            }
            """)
        #expect(out.contains("#2e8b57"))
    }

    @Test func namedColourOnAVNotationNodeType() throws {
        let out = try svg(
            """
            vnotation Q {
                node type: A [nodeStyle: simpleRoundedText, color: seagreen]
                edge type: rel from: A to: A
            }
            vgraph g: Q "G" {
                node x: A "X";
                node y: A "Y";
                edge x -> y;
            }
            """)
        #expect(out.contains("#2e8b57"))
    }
}
