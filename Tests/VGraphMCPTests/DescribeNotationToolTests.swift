import App
import Foundation
import MCP
import Testing
import VGraph
import VGraphMCPTools

@Suite("DescribeNotationTool Tests")
struct DescribeNotationToolTests {

    // MARK: - Tool definition

    @Test("Tool definition has correct name")
    func toolName() {
        #expect(DescribeNotationTool.definition.name == "describe_notation")
    }

    @Test("Tool is registered in VGraphTools.all")
    func registeredInAll() {
        let names = VGraphTools.all.map(\.definition.name)
        #expect(names.contains("describe_notation"))
    }

    // MARK: - Happy path

    @Test("IBIS returns populated Markdown")
    func ibisReturnsMarkdown() async {
        let result = await DescribeNotationTool.handle(
            makeParams(notation: "IBIS")
        )
        #expect(result.isError != true)
        let text = extractText(result)
        #expect(text.contains("# IBIS"))
        #expect(text.contains("## Purpose"))
        #expect(text.contains("## When to use"))
        #expect(text.contains("## Node types"))
        #expect(text.contains("## Edge types"))
        #expect(text.contains("## History"))
        #expect(text.contains("## References"))
    }

    @Test("Every built-in notation returns without error")
    func allNotationsSucceed() async {
        for name in DescribeNotationTool.validNotations {
            let result = await DescribeNotationTool.handle(
                makeParams(notation: name)
            )
            #expect(result.isError != true, "describe_notation failed for \(name)")
            let text = extractText(result)
            // Every notation should at least have node types and edge types tables.
            #expect(text.contains("## Node types"), "\(name) missing Node types section")
            #expect(text.contains("## Edge types"), "\(name) missing Edge types section")
        }
    }

    @Test("The tool tells an assistant it will learn the detailings")
    func definitionMentionsDetailings() {
        #expect(DescribeNotationTool.definition.description?.contains("detailings") == true)
    }

    /// Bites once a built-in notation declares detailings (C4).
    @Test("Every detailing a built-in notation declares is in its description")
    func descriptionsListDetailings() async throws {
        for entry in NotationRegistry.entries.map({ $0.entry }) {
            let text = extractText(await DescribeNotationTool.handle(makeParams(notation: entry.id.id)))
            for detailing in entry.content.detailings {
                let detailTypes = detailing.detailTypes.map { $0.id }.joined(separator: ", ")
                #expect(text.contains("| \(detailing.nodeType.id) | \(detailTypes) |"), "\(entry.id.id)")
            }
        }
    }

    // MARK: - Error cases

    @Test("Unknown notation returns error with valid names")
    func unknownNotation() async {
        let result = await DescribeNotationTool.handle(
            makeParams(notation: "NonExistent")
        )
        #expect(result.isError == true)
        let text = extractText(result)
        #expect(text.contains("unknown notation"))
        #expect(text.contains("IBIS"))  // lists valid names
    }

    @Test("Missing parameter returns error")
    func missingParameter() async {
        let params = CallTool.Parameters(name: "describe_notation", arguments: nil)
        let result = await DescribeNotationTool.handle(params)
        #expect(result.isError == true)
        let text = extractText(result)
        #expect(text.contains("'notation' parameter is required"))
    }

    // MARK: - Helpers

    private func makeParams(notation: String) -> CallTool.Parameters {
        CallTool.Parameters(
            name: "describe_notation",
            arguments: ["notation": .string(notation)]
        )
    }

    private func extractText(_ result: CallTool.Result) -> String {
        result.content.compactMap { item in
            if case .text(let text, _, _) = item { return text }
            return nil
        }.joined(separator: "\n")
    }
}
