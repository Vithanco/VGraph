// Protocol and default implementations for VGraph MCP tools.
// Change shared phrasing (e.g. output format) here — all tools pick it up.

import App
import Foundation
import MCP
import VGraph

// MARK: - Protocol

/// Each notation tool provides these five properties; everything else is derived.
public protocol VGraphTool {
    /// MCP tool name, e.g. "create_concept_map"
    static var name: String { get }
    /// Noun for error messages, e.g. "concept map"
    static var errorNoun: String { get }
    /// Notation name used in VGL, e.g. "ConceptMap"
    static var notationName: String { get }
    /// One-sentence purpose (appears right after "Create a … diagram as SVG image.")
    static var purposeSentence: String { get }
    /// Description of the `vgl` parameter for the JSON schema
    static var vglParameterDescription: String { get }
    /// Notation-specific markdown (node types, edges, examples, rules)
    static var descriptionBody: String { get }
}

// MARK: - Shared defaults

/// Change this to update all tool descriptions at once.
private let sharedOutputFormat = "PNG image"

extension VGraphTool {

    public static var description: String {
        """
        Create a \(notationName) diagram as \(sharedOutputFormat). \(purposeSentence)

        You provide VGL (Vithanco Graph Language) code using the \(notationName) notation and the \
        tool renders it to an \(sharedOutputFormat).

        \(descriptionBody)
        """
    }

    public static var definition: Tool {
        Tool(
            name: name,
            description: description,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "vgl": .object([
                        "type": .string("string"),
                        "description": .string(vglParameterDescription),
                    ])
                ]),
                "required": .array([.string("vgl")]),
                "additionalProperties": .bool(false),
            ])
        )
    }

    private static func pngFailure(_ result: PNGResult, noun: String) -> String {
        switch result {
        case .timedOut: "converting the \(noun) to PNG timed out; reduce the diagram's size."
        case .outputTooLarge: "the PNG of the \(noun) would be too large; reduce the diagram's size."
        default: "failed to render \(noun) to PNG (rsvg-convert unavailable or conversion failed)."
        }
    }

    public static func handle(_ params: CallTool.Parameters) async -> CallTool.Result {
        await handle(params, logger: StderrLogger())
    }

    public static func handle(
        _ params: CallTool.Parameters,
        logger: StderrLogger,
        limits: MCPLimits = .standard,
        png: PNGConverter = .shared
    ) async -> CallTool.Result {
        guard let vgl = params.arguments?["vgl"]?.stringValue else {
            return .init(
                content: [.text(text: "Error: 'vgl' parameter is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        if let refusal = limits.refusal(vglBytes: vgl.utf8.count) {
            return .init(content: [.text(text: "Error: \(refusal)", annotations: nil, _meta: nil)], isError: true)
        }

        let renderStart = Date()
        let app = VGraphMCPApp(logger: logger)
        let graph: VGraph
        let renderings: [(caption: String?, result: RenderResult)]
        do {
            graph = try app.parseGraph(vgl)
            if let refusal = limits.refusal(nodes: graph.nodes.count, edges: graph.edges.count, views: graph.views.count) {
                return .init(content: [.text(text: "Error: \(refusal)", annotations: nil, _meta: nil)], isError: true)
            }
            // The default view first, then each declared view; captions only when views exist.
            let shown: [(caption: String?, view: String?)] =
                graph.views.isEmpty
                ? [(nil, nil)]
                : [("default", nil)] + graph.views.map { ("\($0.name)\($0.label.map { ": \($0)" } ?? "")", $0.name) }
            renderings = try shown.map { (caption: $0.caption, result: try app.renderGraph(graph: graph, sourceVGL: vgl, view: $0.view)) }
        } catch {
            return .init(
                content: [.text(text: "Error rendering \(errorNoun): \(error)", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        let renderElapsed = Date().timeIntervalSince(renderStart)
        let graphvizTimeoutSeconds = 30
        var content: [Tool.Content] = []
        // Findings are the model's, so every view carries the same report.
        if let qualityText = renderings[0].result.qualityReport.formatted() {
            content.append(.text(text: qualityText, annotations: nil, _meta: nil))
        }
        if renderElapsed > 5.0 {
            let secs = Int(renderElapsed.rounded())
            content.append(
                .text(
                    text: "⚠️ Render took \(secs)s of \(graphvizTimeoutSeconds)s limit — reduce diagram complexity to avoid timeouts.",
                    annotations: nil, _meta: nil)
            )
        }
        for (caption, result) in renderings {
            let converted = await png.convert(result.svg, logger: logger)
            guard case .png(let pngData) = converted else {
                return .init(
                    content: [.text(text: "Error: \(Self.pngFailure(converted, noun: errorNoun))", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            if let caption { content.append(.text(text: caption, annotations: nil, _meta: nil)) }
            content.append(.image(data: pngData.base64EncodedString(), mimeType: "image/png", annotations: nil, _meta: nil))
        }
        return .init(content: content, isError: false)
    }
}

// MARK: - Tool Registry

/// All available VGraph tools. Add new tools here — no server changes needed.
public enum VGraphTools {
    public static let all: [(definition: Tool, handle: @Sendable (CallTool.Parameters) async -> CallTool.Result)] = [
        (CLDTool.definition, CLDTool.handle),
        (ConceptMapTool.definition, ConceptMapTool.handle),
        (DecomposeTool.definition, DecomposeTool.handle),
        (DescribeNotationTool.definition, DescribeNotationTool.handle),
        (IBISTool.definition, IBISTool.handle),
        (TimelineTool.definition, TimelineTool.handle),
    ]
}

// MARK: - rsvg-convert failures

enum RSVGFailure {
    case launch
    case exited(status: Int32, stderr: String)
}

/// rsvg-convert's own stderr quotes the SVG it choked on, labels included, so the
/// text is debug-only; the default level keeps the status.
func logRSVGFailure(_ failure: RSVGFailure, logger: StderrLogger) {
    switch failure {
    case .launch:
        logger.warn("rsvg-convert failed to launch")
    case .exited(let status, let stderr):
        logger.warn("rsvg-convert exited \(status)")
        logger.debug("rsvg-convert stderr: \(stderr)")
    }
}
