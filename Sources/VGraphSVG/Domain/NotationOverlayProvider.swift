////
////  NotationOverlayProvider.swift
////  VGraphSVG
////
////  Plug-in point for notation-specific visual layers that draw outside the
////  standard groups/edges/nodes pipeline. Used today by Timeline (axis + guides)
////  and CLD (loop indicators — migrated in a follow-up commit).
////
////  The protocol is a pure presentation contract: every method has a default
////  no-op implementation, so a provider only overrides what it actually
////  contributes. Pre-render analysis lives in the layout pipeline (e.g.,
////  `Notations.notationTransform(for:)`) and stamps its results onto the graph
////  as attributes — the provider reads what it needs at render time.
////

import VGraph

/// A notation-specific overlay contributor.
///
/// The renderer looks up a provider by notation name (with extension-chain
/// fallback) and invokes its slot methods at fixed positions in the render
/// pipeline. The slot methods, the bounds contribution, and the node/edge
/// filters all default to "contribute nothing" — providers override only the
/// pieces they care about.
public protocol NotationOverlayProvider: Sendable {

    /// Notation name this provider applies to. Compared against
    /// the graph's notation (and each of its extensions, for
    /// `vnotation … extends …` graphs).
    var notationName: String { get }

    // MARK: - Render slot methods (four symmetric extension points)

    /// SVG drawn beneath the groups layer (after defs, before groups).
    /// Used by Timeline for descending column guides.
    func renderBetweenDefsAndGroups(ctx: RenderContext) throws(VError) -> VSVGNode

    /// SVG drawn above groups, beneath edges.
    /// Used by Timeline for the axis baseline + dots + year labels.
    func renderBetweenGroupsAndEdges(ctx: RenderContext) throws(VError) -> VSVGNode

    /// SVG drawn above edges, beneath nodes.
    /// No current consumer; reserved for future overlays that need to sit under
    /// nodes (e.g. selection highlights, annotation underlays).
    func renderBetweenEdgesAndNodes(ctx: RenderContext) throws(VError) -> VSVGNode

    /// SVG drawn above nodes, beneath the graph label.
    /// Used (after the CLD migration) for loop indicators.
    func renderBetweenNodesAndLabel(ctx: RenderContext) throws(VError) -> VSVGNode

    // MARK: - Bounds contribution

    /// Rectangles to fold into the SVG viewbox so overlay drawings extending
    /// past the natural graph bbox don't clip. Used by CLD for the 40-px
    /// footprint around loop-indicator centroids; Timeline returns empty (its
    /// drawings stay inside the bbox).
    func boundsContributions(graph: VGraph) -> [VRect]

    // MARK: - Standard-pipeline filters

    /// Given all nodes about to render, return the subset to keep.
    /// Used by Timeline to drop `TimePoint` nodes (replaced by the axis chrome).
    func filterNodes(_ nodes: Set<Node>, graph: VGraph) -> Set<Node>

    /// Given all edges about to render, return the subset to keep.
    /// Used by Timeline to drop `sequence` edges (redundant with the axis line).
    func filterEdges(_ edges: Set<Edge>, graph: VGraph) -> Set<Edge>

    // MARK: - Hover contribution

    /// Extra CSS rules appended inside the neighbour-hover `<style>` block. Returned
    /// as a string (not structured data) so only a `String` crosses the overlay
    /// boundary — CSS is additive, so these stack on the generic per-node rules.
    /// Used by CLD to make a whole styled feedback loop a single hover unit.
    func hoverStyleRules(graph: VGraph) -> String
}

extension NotationOverlayProvider {
    public func renderBetweenDefsAndGroups(ctx: RenderContext) throws(VError) -> VSVGNode { .empty }
    public func renderBetweenGroupsAndEdges(ctx: RenderContext) throws(VError) -> VSVGNode { .empty }
    public func renderBetweenEdgesAndNodes(ctx: RenderContext) throws(VError) -> VSVGNode { .empty }
    public func renderBetweenNodesAndLabel(ctx: RenderContext) throws(VError) -> VSVGNode { .empty }
    public func boundsContributions(graph: VGraph) -> [VRect] { [] }
    public func filterNodes(_ nodes: Set<Node>, graph: VGraph) -> Set<Node> { nodes }
    public func filterEdges(_ edges: Set<Edge>, graph: VGraph) -> Set<Edge> { edges }
    public func hoverStyleRules(graph: VGraph) -> String { "" }
}

/// Value-type snapshot of a `NotationOverlayProvider` for use in the registry.
/// Mirrors `NotationEntry` in the core domain — Embedded Swift can't store
/// values of protocol type in a Dictionary, so dispatch goes through closure
/// fields here instead of `any NotationOverlayProvider`.
public struct NotationOverlayEntry: @unchecked Sendable {
    public let notationName: String
    public let renderBetweenDefsAndGroups: (RenderContext) throws(VError) -> VSVGNode
    public let renderBetweenGroupsAndEdges: (RenderContext) throws(VError) -> VSVGNode
    public let renderBetweenEdgesAndNodes: (RenderContext) throws(VError) -> VSVGNode
    public let renderBetweenNodesAndLabel: (RenderContext) throws(VError) -> VSVGNode
    public let boundsContributions: (VGraph) -> [VRect]
    public let filterNodes: (Set<Node>, VGraph) -> Set<Node>
    public let filterEdges: (Set<Edge>, VGraph) -> Set<Edge>
    public let hoverStyleRules: (VGraph) -> String
}

extension NotationOverlayProvider {
    public var overlayEntry: NotationOverlayEntry {
        NotationOverlayEntry(
            notationName: notationName,
            renderBetweenDefsAndGroups: self.renderBetweenDefsAndGroups(ctx:),
            renderBetweenGroupsAndEdges: self.renderBetweenGroupsAndEdges(ctx:),
            renderBetweenEdgesAndNodes: self.renderBetweenEdgesAndNodes(ctx:),
            renderBetweenNodesAndLabel: self.renderBetweenNodesAndLabel(ctx:),
            boundsContributions: self.boundsContributions(graph:),
            filterNodes: self.filterNodes,
            filterEdges: self.filterEdges,
            hoverStyleRules: self.hoverStyleRules(graph:)
        )
    }
}

/// Built-in overlay providers keyed by notation name. The renderer uses this
/// as the default registry but accepts an override via its initializer for tests.
public enum NotationOverlayRegistry {

    /// Walk the notation name first, then the `extensions` chain. First match wins.
    /// A graph declared `vnotation MyTimeline extends Timeline` resolves to the
    /// Timeline provider via the chain.
    public static func resolve(
        graph: VGraph,
        in providers: [String: NotationOverlayEntry]
    ) -> NotationOverlayEntry? {
        if let p = providers[graph.notationName] { return p }
        for name in graph.notationDefinition.extensions {
            if let p = providers[name] { return p }
        }
        return nil
    }

    /// Default registry of built-in overlay providers. Keyed by notation
    /// name (matches `VGraph.notationName`).
    public static let `default`: [String: NotationOverlayEntry] = [
        Notations.Timeline.id.id: TimelineOverlayProvider().overlayEntry,
        Notations.CausalLoopDiagram.id.id: CLDOverlayProvider().overlayEntry,
    ]
}
