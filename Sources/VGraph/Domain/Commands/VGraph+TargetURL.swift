//
//  VGraph+TargetURL.swift
//  VGraph
//
//  Reading and writing an element's link regardless of its kind.
//

extension VGraph {
    /// The link attached to an element, or nil when there is none — including the
    /// empty string, which is what removal leaves behind.
    public func url(of target: VCommandTarget) -> String? {
        let stored: String?
        switch target {
        case .node(let node):
            stored = try? get(node: node, attribute: Attributes.Node.url)
        case .edge(let edge):
            stored = try? get(edge: edge, attribute: Attributes.Edge.url)
        case .group(let group) where isDetailed(group):
            stored = try? get(group: group, attribute: Attributes.Node.url)
        case .group(let group):
            stored = try? get(group: group, attribute: Attributes.Group.url)
        }
        guard let stored, !stored.isEmpty else { return nil }
        return stored
    }

    /// Attach `url` to an element, or detach it by passing "".
    public func set(url: String, on target: VCommandTarget) throws(VError) -> VGraph {
        switch target {
        case .node(let node):
            return try set(node: node, attribute: Attributes.Node.url.attribute(url))
        case .edge(let edge):
            return try set(edge: edge, attribute: Attributes.Edge.url.attribute(url))
        case .group(let group) where isDetailed(group):
            return try set(group: group, attribute: Attributes.Node.url.attribute(url))
        case .group(let group):
            return try set(group: group, attribute: Attributes.Group.url.attribute(url))
        }
    }
}
