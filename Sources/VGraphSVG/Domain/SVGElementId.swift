// The id and class vocabulary the renderer stamps on graph elements, and the
// inverse an interactive host needs to get from a clicked element back to an
// OriginGraph id. Mint and parse live together so they cannot drift.

import VGraph

public enum SVGElementId {
    public static let nodePrefix = "node-"
    public static let edgePrefix = "edge-"
    public static let groupPrefix = "group-"

    public static let nodeClass = "vgraph-node"
    public static let edgeClass = "vgraph-edge"
    public static let groupClass = "vgraph-group"
    public static let groupLabelClass = "vgraph-group-label"
    /// Alongside `nodeClass` on a folded group's box, which is drawn like a node.
    public static let foldedGroupClass = "vgraph-folded-group"
    /// Alongside `edgeClass` on an [[Edge bundle]], which offers no edge action.
    public static let edgeBundleClass = "vgraph-edge-bundle"
    /// On a bundle: the folded groups at its ends, space-separated — what its
    /// right-click offers to unfold.
    public static let unfoldsAttribute = "data-unfolds"

    /// The handle a [[Reattach]] drag is grabbed by. **No prefix and no id**: an
    /// [[Edge end]] is a position on an edge rather than an element, so it names
    /// the pair (edge, end) through these two data attributes and never enters
    /// the origin-id keyspace `originId(fromDomId:)` parses. The URL badge is
    /// the same shape of chrome (ADR-0021).
    public static let edgeEndClass = "vgraph-edge-end"
    public static let edgeEndEdgeAttribute = "data-edge"
    public static let edgeEndSideAttribute = "data-end"

    /// What `data-end` holds. Spelled here so the mint and the parse cannot
    /// drift, as everything else in this file is.
    public static func edgeEndSide(_ end: VEdgeEnd) -> String {
        switch end {
        case .from: return "from"
        case .to: return "to"
        }
    }

    public static func edgeEnd(fromSide side: String) -> VEdgeEnd? {
        switch side {
        case "from": return .from
        case "to": return .to
        default: return nil
        }
    }

    public static func node(_ id: String) -> String { nodePrefix + id }
    public static func edge(_ id: String) -> String { edgePrefix + id }
    public static func group(_ id: String) -> String { groupPrefix + id }

    /// The element a display-graph node is drawn as. A folded group's stand-in is
    /// drawn as that group: the SVG is stamped with what an element represents, not
    /// with what the display graph needed in order to draw it (ADR-0027).
    public static func displayNode(_ node: Node, in graph: VGraph) -> String {
        isFoldedGroup(node, in: graph) ? group(node.id) : SVGElementId.node(node.id)
    }

    public static func isFoldedGroup(_ node: Node, in graph: VGraph) -> Bool {
        graph.isFoldedStandIn(node)
    }

    public static func domId(for target: VCommandTarget) -> String {
        domId(kind: target.kind, elementId: target.elementId)
    }

    /// The kind and the id are all a dom id needs, so an adapter holding those
    /// two — rather than a resolved `VCommandTarget` — can still find the
    /// element. `ForEditAGraphVisually.kind(of:)` is where the kind comes from.
    public static func domId(kind: VElementKind, elementId: String) -> String {
        switch kind {
        case .node: return node(elementId)
        case .edge: return edge(elementId)
        case .group: return group(elementId)
        }
    }

    public static func originId(fromDomId domId: String) -> String? {
        for prefix in [nodePrefix, edgePrefix, groupPrefix] where domId.hasPrefix(prefix) {
            let id = String(domId.dropFirst(prefix.count))
            return id.isEmpty ? nil : id
        }
        return nil
    }

    public static var contextMenuSelector: String {
        ".\(groupClass),.\(nodeClass),.\(edgeClass)"
    }

    public static func doubleClickSelector(insideGroupLabel: Bool) -> String {
        insideGroupLabel ? ".\(groupClass)" : ".\(nodeClass),.\(edgeClass)"
    }
}
