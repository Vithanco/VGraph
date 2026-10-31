import MCP
import Testing
import VGraphMCPTools

@Suite("MCP render tools show every view")
struct ViewsRenderTests {
    private func call(_ vgl: String) async -> CallTool.Result {
        await ConceptMapTool.handle(.init(name: ConceptMapTool.name, arguments: ["vgl": .string(vgl)]))
    }

    private func texts(_ result: CallTool.Result) -> [String] {
        result.content.compactMap { if case .text(let text, _, _) = $0 { text } else { nil } }
    }

    private func imageCount(_ result: CallTool.Result) -> Int {
        result.content.filter { if case .image = $0 { true } else { false } }.count
    }

    // Four words in a concept label draw a quality warning.
    private let body = """
        vgraph test: ConceptMap "Test?" {
            node a: Concept "A Very Long Concept Name"
            node b: Concept "Cat"
            node r1: Relation "is a"
            edge a -> r1
            edge r1 -> b
        }
        """

    private var twoViews: String {
        body + """


            vview first "First View" {
                node b [fontsize: 16];
            }

            vview second "Second View" {
                node b [fontsize: 20];
            }
            """
    }

    @Test("Given two views, when rendered, then default and both views are captioned pictures after one report")
    func threePicturesOneReport() async {
        let result = await call(twoViews)
        #expect(result.isError != true)
        #expect(imageCount(result) == 3)

        let kinds = result.content.map { item -> String in
            switch item {
            case .image: "image"
            case .text(let text, _, _): text
            default: "other"
            }
        }
        #expect(kinds.count == 7)
        #expect(kinds[0].contains("Concepts:"))
        #expect(Array(kinds[1...]) == ["default", "image", "first: First View", "image", "second: Second View", "image"])
    }

    @Test("Given no views, when rendered, then it is the report and one uncaptioned picture")
    func noViewsUnchanged() async {
        let result = await call(body)
        #expect(imageCount(result) == 1)
        #expect(texts(result).count == 1)
        #expect(!texts(result).contains("default"))
    }
}
