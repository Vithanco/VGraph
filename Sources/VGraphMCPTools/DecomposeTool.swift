// Text in, text out: the assistant keeps the document, as an editor user does.
// It goes through the session so it decomposes exactly as the editor's menu.

import App
import MCP
import VGraph

public enum DecomposeTool {

    public static let name = "decompose"

    public static var definition: Tool {
        Tool(
            name: name,
            description: """
                Decompose a node into a detailed node and return the updated VGL document. \
                Only a node whose type has a detailing can be decomposed; `describe_notation` \
                lists them. The node keeps its id, type, label and attributes and becomes a \
                group holding new details, one per edge, so every edge keeps its id and label \
                and now ends at a detail. Rename and retype the new details afterwards.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "vgl": .object([
                        "type": .string("string"),
                        "description": .string("The VGL document holding the node"),
                    ]),
                    "node": .object([
                        "type": .string("string"),
                        "description": .string("Id of the node to decompose"),
                    ]),
                ]),
                "required": .array([.string("vgl"), .string("node")]),
                "additionalProperties": .bool(false),
            ])
        )
    }

    public static func handle(_ params: CallTool.Parameters) async -> CallTool.Result {
        await handle(params, logger: StderrLogger())
    }

    public static func handle(
        _ params: CallTool.Parameters, logger: StderrLogger, limits: MCPLimits = .standard
    ) async -> CallTool.Result {
        guard let vgl = params.arguments?["vgl"]?.stringValue,
            let node = params.arguments?["node"]?.stringValue
        else {
            return failure("Error: 'vgl' and 'node' parameters are required.")
        }
        if let refusal = limits.refusal(vglBytes: vgl.utf8.count) {
            return failure("Error: \(refusal)")
        }
        do {
            let app = VGraphMCPApp(logger: logger)
            // The session does not expose the parsed graph, and a parse is cheap
            // beside the layout the render tools refuse to start.
            let graph = try app.parseGraph(vgl)
            if let refusal = limits.refusal(nodes: graph.nodes.count, edges: graph.edges.count, views: graph.views.count) {
                return failure("Error: \(refusal)")
            }
            let session = try app.makeSession(vgl: vgl)
            try session.decompose(node)
            return .init(content: [.text(text: try session.exportVGL(), annotations: nil, _meta: nil)], isError: false)
        } catch {
            return failure("Error decomposing '\(node)': \(error)")
        }
    }

    private static func failure(_ text: String) -> CallTool.Result {
        .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: true)
    }
}
