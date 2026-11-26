import TestSupport
import Testing

@testable import App
@testable import VGraph

@Suite("A VGL value that does not parse as its attribute's type")
struct BadlyTypedValueTests {
    private let app = VGraphTestApp()

    private func source(_ attributes: String) -> String {
        """
        vgraph g: IBIS "G" {
            node q: Question "Why?" \(attributes);
            node a: Answer "Because";
            edge q -> a;
        }
        """
    }

    @Test("Given width: abc on a node, when the document is rendered, then one warning names the node, the attribute and the type")
    func itIsWarnedAboutOnce() throws {
        let report = try app.renderGraph(source("[width: abc]")).qualityReport

        #expect(
            report.warnings.map { $0.message } == [#"Node "Why?" has width "abc", which is not a valid Double"#])
        #expect(report.warnings.first?.target == .node("q"))
    }

    @Test(
        "Given a badly typed value on a node, when it is laid out, then it is drawn as if the value were not there",
        arguments: ["[width: abc]", "[fontsize: big]"])
    func itIsIgnoredWhenDrawing(attributes: String) throws {
        let node = Node("q")
        let badly = try app.layoutGraph(source(attributes))
        let plain = try app.layoutGraph(source(""))

        #expect(
            try badly.get(node: node, attribute: Attributes.Node.layoutedSize)
                == plain.get(node: node, attribute: Attributes.Node.layoutedSize))
    }

    @Test(
        "Given a node colour that is no colour, when the document is rendered, then it loads, is warned about once and is drawn as if absent",
        arguments: [
            (attributes: "[color: notacolour]", key: "backgroundColor"),
            (attributes: "[fontColor: notacolour]", key: "fontColor"),
        ])
    func aBadNodeColourIsAWarning(attributes: String, key: String) throws {
        let badly = try app.renderGraph(source(attributes))

        #expect(
            badly.qualityReport.warnings.map { $0.message }
                == ["Node \"Why?\" has \(key) \"notacolour\", which is not a valid Color"])
        #expect(drawn(badly.svg) == drawn(try VGraphTestApp().renderGraph(source("")).svg))
    }

    @Test("Given a diagram direction that is none, when the document is rendered, then the warning names layoutDirection as the guide spells it")
    func aBadDirectionIsNamedAsTheGuideSpellsIt() throws {
        let badly = try app.renderGraph("vgraph g: IBIS \"G\" {\n    rankdir: sideways\n    node q: Question \"Why?\";\n}\n")

        #expect(
            badly.qualityReport.warnings.map { $0.message }.filter { $0.contains("not a valid") }
                == [#"The diagram has layoutDirection "sideways", which is not a valid LayoutDirection"#])
    }

    /// The SVG without the VGL source it carries, which differs by the value under
    /// test. Each render needs an app of its own, since edge ids count on across parses.
    private func drawn(_ svg: String) -> String {
        guard let start = svg.range(of: "<metadata>"), let end = svg.range(of: "</metadata>") else { return svg }
        return String(svg[..<start.lowerBound] + svg[end.upperBound...])
    }

    private let grouped = """
        vgraph g: IBIS "G" {
            group grp "Grp" {
                node q: Question "Why?";
                node a: Answer "Because";
            }
            edge q -> a;
        }
        """

    @Test("Given a view setting a Bool to something else, when the view is rendered, then it loads, is warned about once and is drawn as if absent")
    func aNonBoolInAViewIsAWarning() throws {
        let badly = try app.renderGraph(grouped + "\nvview v {\n group grp [isFolded: maybe];\n}\n", view: "v")
        let plain = try VGraphTestApp().renderGraph(grouped + "\nvview v {\n}\n", view: "v")

        #expect(
            badly.qualityReport.warnings.map { $0.message }
                == [#"Group "Grp" has isFolded "maybe" in view "v", which is not a valid Bool"#])
        #expect(drawn(badly.svg) == drawn(plain.svg))
    }
}
