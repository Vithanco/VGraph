import MCP
import Testing

@testable import VGraphMCPTools

@Suite("Decompose limits")
struct DecomposeLimitTests {
    private let standard = MCPLimits.standard
    private let logger = StderrLogger(environment: [:], sink: { _ in })

    private let notation = """
        vnotation Arch {
          node type: Person [nodeStyle: roundedBox]
          node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
          node type: Container [nodeStyle: roundedBox]
          edge type: uses from: Person to: System
        }
        """

    /// `bank` plus `people` more nodes, `edges` edges into `bank`, and `views` views.
    private func document(people: Int = 1, edges: Int = 1, views: Int = 0) -> String {
        var vgl = notation + "\n\nvgraph g: Arch \"G\" {\n  node bank: System \"Bank\";\n"
        for i in 0..<people { vgl += "  node p\(i): Person \"P\(i)\";\n" }
        for i in 0..<edges { vgl += "  edge p\(i % max(1, people)) -> bank;\n" }
        vgl += "}\n"
        for v in 0..<views { vgl += "\nvview v\(v) \"View \(v)\" {\n  node bank [fontsize: 1\(v)];\n}\n" }
        return vgl
    }

    private func padded(_ vgl: String, to bytes: Int) -> String {
        vgl + String(repeating: " ", count: max(0, bytes - vgl.utf8.count))
    }

    private func decompose(_ vgl: String, limits: MCPLimits? = nil) async -> CallTool.Result {
        await DecomposeTool.handle(
            .init(name: "decompose", arguments: ["vgl": .string(vgl), "node": .string("bank")]),
            logger: logger, limits: limits ?? standard)
    }

    private func text(_ result: CallTool.Result) -> String {
        result.content.compactMap { if case .text(let text, _, _) = $0 { text } else { nil } }.joined(separator: "\n")
    }

    @Test("Given VGL one byte over the length limit, when a node is decomposed, then it is refused with an error naming the VGL length limit")
    func tooLong() async {
        let result = await decompose(padded(document(), to: standard.maxVGLBytes + 1))
        #expect(result.isError == true)
        #expect(text(result).contains("VGL length limit"))
    }

    @Test("Given unparseable VGL one byte over the length limit, when decomposed, then the answer is the limit error and not a parse error")
    func tooLongAndUnparseable() async {
        let result = await decompose(padded("this is not VGL", to: standard.maxVGLBytes + 1))
        #expect(text(result).contains("VGL length limit"))
    }

    @Test("Given a decomposable document padded to exactly the length limit, when its node is decomposed, then it decomposes")
    func atLengthLimit() async {
        let result = await decompose(padded(document(), to: standard.maxVGLBytes))
        #expect(result.isError != true)
        #expect(text(result).contains("group bank: System"))
    }

    @Test("Given 501 nodes, when a node is decomposed, then it is refused with an error naming the node limit, the count and the limit")
    func tooManyNodes() async {
        let result = await decompose(document(people: standard.maxNodes))
        #expect(result.isError == true)
        #expect(text(result).contains("node limit"))
        #expect(text(result).contains("501"))
        #expect(text(result).contains("500"))
    }

    @Test("Given 1001 edges, when a node is decomposed, then it is refused with an error naming the edge limit")
    func tooManyEdges() async {
        let result = await decompose(document(people: 400, edges: standard.maxEdges + 1))
        #expect(result.isError == true)
        #expect(text(result).contains("edge limit"))
    }

    @Test("Given 9 views, when a node is decomposed, then it is refused with an error naming the view limit")
    func tooManyViews() async {
        let result = await decompose(document(views: standard.maxViews + 1))
        #expect(result.isError == true)
        #expect(text(result).contains("view limit"))
    }

    @Test("Given a decomposable document at every limit at once, when its node is decomposed, then it decomposes")
    func atEveryLimit() async {
        var small = MCPLimits.standard
        small.maxNodes = 4
        small.maxEdges = 3
        small.maxViews = 2
        let vgl = document(people: 3, edges: 3, views: 2)
        small.maxVGLBytes = vgl.utf8.count
        let result = await decompose(vgl, limits: small)
        #expect(result.isError != true)
        #expect(text(result).contains("group bank: System"))
    }

    @Test("Given the same over-limit document, when sent to a render tool and to decompose, then both give the same error text")
    func sameWordingAsRenderTools() async {
        let nodes = (0...standard.maxNodes).map { "  node n\($0): Concept \"C\($0)\"" }.joined(separator: "\n")
        let render = await ConceptMapTool.handle(
            .init(name: ConceptMapTool.name, arguments: ["vgl": .string("vgraph t: ConceptMap \"T\" {\n\(nodes)\n}\n")]),
            logger: logger)
        let decomposed = await decompose(document(people: standard.maxNodes))
        #expect(text(render) == text(decomposed))
    }
}
