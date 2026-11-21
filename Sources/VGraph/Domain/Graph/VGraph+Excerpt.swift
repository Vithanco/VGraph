extension VGraph {
    /// What a copy carries. Label, comments, root values and views belong
    /// to the document, not to the elements, so they stay behind.
    public func excerpt(of ids: [String]) throws(VError) -> VGraph {
        let root = Group(rawValue: rootGroup)
        var keptNodes: Set<String> = []
        var keptGroups: Set<String> = []
        var result = self
        for id in outermostElements(of: ids) {
            switch resolveCommandTarget(id: id) {
            case .node(let node)?:
                keptNodes.insert(node.id)
                result = try result.addTo(group: root, node: node)
            case .group(let group)?:
                keptGroups.insert(group.id.id)
                let (groups, nodes) = try groupStructure.getAllContent(group: group)
                for inner in groups { keptGroups.insert(inner.id.id) }
                for node in nodes { keptNodes.insert(node.id) }
                result = try result.addTo(group: root, childGroup: group)
            case .edge?, nil:
                continue
            }
        }
        result = try result.keeping(nodes: keptNodes, groups: keptGroups)
        for view in result.views {
            result = try result.removing(view: view.name)
        }
        return result.updatedSelfWith(ads: result.ads.removeKey(.root))
    }
}
