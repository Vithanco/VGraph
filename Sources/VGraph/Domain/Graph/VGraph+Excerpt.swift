extension VGraph {
    /// What a copy carries. Label, comments, root values and views belong
    /// to the document, not to the elements, so they stay behind.
    public func excerpt(of ids: [String]) throws(VError) -> VGraph {
        let copied = outermostElements(of: ids).compactMap { resolveCommandTarget(id: $0) }
        let atTopLevel = try copied.folding(self) { (graph, element) throws(VError) in
            try graph.adding(element, to: Group.root)
        }
        let elementsOnly = try atTopLevel.keeping(try copiedSubset(copied))
        let withoutViews = try elementsOnly.views.folding(elementsOnly) { (graph, view) throws(VError) in
            try graph.removing(view: view.name)
        }
        return withoutViews.updatedSelfWith(attributeStore: withoutViews.attributeStore.removingKey(.root))
    }

    /// A copied group brings everything inside it.
    private func copiedSubset(_ copied: [VCommandTarget]) throws(VError) -> Subset {
        var kept = try subset(containing: copied.compactMap { if case .group(let group) = $0 { group } else { nil } })
        kept.nodes.formUnion(copied.compactMap { if case .node(let node) = $0 { node.id } else { nil } })
        return kept
    }
}
