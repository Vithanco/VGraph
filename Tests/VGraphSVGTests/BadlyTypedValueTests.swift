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
}
