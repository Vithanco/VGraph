import Foundation

/// Every bound on what one request may cost, in one place.
///
/// The hosted server is open to anyone, and in-process Graphviz layout cannot be
/// cancelled, so the worst case is bounded by bounding the input; a deadline can
/// only abandon work, not stop it.
public struct MCPLimits: Sendable {
    public var maxBodyBytes = 1 << 20
    public var maxVGLBytes = 256 << 10
    public var maxNodes = 500
    public var maxEdges = 1000
    public var maxViews = 8

    public var maxPixels = 25_000_000
    public var maxPNGBytes = 32 << 20
    public var pngTimeoutSeconds = 20.0
    public var pngConcurrency = 4

    public var idleTimeoutSeconds = 60.0
    public var readTimeoutSeconds = 15.0
    /// Shorter than the Cloud Run `--timeout`, so the client gets an answer.
    public var requestDeadlineSeconds = 120.0

    public init() {}

    public static let standard = MCPLimits()

    /// The first limit a document breaks, checked cheapest first: its length
    /// before it is parsed, its size once it is.
    func refusal(vglBytes: Int) -> String? {
        vglBytes > maxVGLBytes
            ? "VGL length limit exceeded: \(vglBytes) bytes, the limit is \(maxVGLBytes)." : nil
    }

    func refusal(nodes: Int, edges: Int, views: Int) -> String? {
        if nodes > maxNodes { return "node limit exceeded: \(nodes) nodes, the limit is \(maxNodes)." }
        if edges > maxEdges { return "edge limit exceeded: \(edges) edges, the limit is \(maxEdges)." }
        if views > maxViews { return "view limit exceeded: \(views) views, the limit is \(maxViews)." }
        return nil
    }
}
