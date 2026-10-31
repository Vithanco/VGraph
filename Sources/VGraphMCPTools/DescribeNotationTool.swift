// MCP tool that returns the self-describing Markdown document for a built-in notation.
// Unlike the rendering tools this does not take VGL input or produce an image — it takes
// a notation name and returns Markdown text (purpose, when-to-use, node/edge/group types,
// detailings, history, references).

import App
import Foundation
import MCP
import VGraph

public enum DescribeNotationTool {

    public static let name = "describe_notation"

    /// Every registered notation, in registry order. `metadescription` resolves
    /// against the same registry, so an allowlist here could only ever go stale —
    /// as it did, offering IBIS alone while fifteen others answered perfectly well.
    public static var validNotations: [String] { NotationRegistry.entries.map(\.id) }

    public static var definition: Tool {
        Tool(
            name: name,
            description: """
                Return the self-describing Markdown document for a built-in VGraph notation. \
                The document includes the notation's purpose, when to use it, node types, \
                edge types, group types, detailings (which node types can be decomposed and \
                what goes inside them), history, and references.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "notation": .object([
                        "type": .string("string"),
                        "description": .string("Name of the built-in notation"),
                        "enum": .array(validNotations.map { .string($0) }),
                    ])
                ]),
                "required": .array([.string("notation")]),
                "additionalProperties": .bool(false),
            ])
        )
    }

    public static func handle(_ params: CallTool.Parameters) async -> CallTool.Result {
        guard let notation = params.arguments?["notation"]?.stringValue else {
            return .init(
                content: [.text(text: "Error: 'notation' parameter is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        // Validate against known names before hitting the parser — gives a better error.
        guard validNotations.contains(notation) else {
            return .init(
                content: [
                    .text(
                        text: "Error: unknown notation '\(notation)'. Valid notations: \(validNotations.joined(separator: ", "))",
                        annotations: nil, _meta: nil
                    )
                ],
                isError: true
            )
        }

        guard let markdown = VGraphMCPApp().describeNotation(notation) else {
            return .init(
                content: [
                    .text(
                        text: "Error: notation '\(notation)' has no self-description content yet.",
                        annotations: nil, _meta: nil
                    )
                ],
                isError: true
            )
        }
        return .init(
            content: [.text(text: markdown, annotations: nil, _meta: nil)],
            isError: false
        )
    }
}
