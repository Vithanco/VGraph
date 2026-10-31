import MCP
import Testing
import VGraphMCPTools

/// An assistant decomposes a node the way an editor user does.
struct DecomposeToolTests {
    private let document = """
        vnotation Arch {
          node type: Person [nodeStyle: roundedBox]
          node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
          node type: Container [nodeStyle: roundedBox]
          edge type: uses from: Person to: System
        }

        vgraph g: Arch "G" {
          node alice: Person "Alice";
          node bank: System "Bank";
          edge alice -> bank "logs in";
        }
        """

    @Test("The tool is offered to assistants")
    func registered() {
        #expect(VGraphTools.all.map { $0.definition.name }.contains("decompose"))
    }

    @Test("Given a node whose type has a detailing, when decomposed, then the updated document holds it as a detailed node")
    func decomposesTheNode() async {
        let result = await DecomposeTool.handle(params(vgl: document, node: "bank"))

        #expect(result.isError != true)
        let vgl = text(result)
        #expect(vgl.contains("group bank: System \"Bank\""), "\(vgl)")
        #expect(vgl.contains(": Container \"Change Me\""), "\(vgl)")
        #expect(vgl.contains("\"logs in\""), "\(vgl)")
    }

    @Test("Given a node whose type has no detailing, when decomposed, then the tool reports an error")
    func refusesATypeWithoutDetailing() async {
        let result = await DecomposeTool.handle(params(vgl: document, node: "alice"))

        #expect(result.isError == true)
        #expect(text(result).contains("'decompose' is not available on 'alice'"), "\(text(result))")
    }

    private func params(vgl: String, node: String) -> CallTool.Parameters {
        CallTool.Parameters(name: "decompose", arguments: ["vgl": .string(vgl), "node": .string(node)])
    }

    private func text(_ result: CallTool.Result) -> String {
        result.content.compactMap { item in
            if case .text(let text, _, _) = item { return text }
            return nil
        }.joined(separator: "\n")
    }
}
