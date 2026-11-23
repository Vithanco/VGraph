/// What the notation says a type's nodes are detailed by, across every layer
/// that installed (ADR-0032).
extension VGraph {
    public func detailTypes(of nodeType: NodeType) -> [NodeType] {
        notationDefinition.detailTypes(of: nodeType)
    }

    /// Only those `layer` added, which is what a `vnotation` writes back.
    public func detailTypes(of nodeType: NodeType, declaredIn layer: AttributeLayer) -> [NodeType] {
        notationDefinition.detailTypes(of: nodeType, declaredIn: layer)
    }

    /// At any depth: a Component details a System through its Container.
    public func isDetailType(_ candidate: NodeType, of nodeType: NodeType) -> Bool {
        allDetailTypes(of: nodeType).contains(candidate)
    }

    public func typesDetailed(by detailType: NodeType) -> [NodeType] {
        notationDefinition.detailings.filter { $0.detailType == detailType }.map { $0.nodeType }
    }

    /// Plain groups are transparent: they arrange details, they do not detail.
    public func detailedNode(holding group: Group?) -> Group? {
        groupAncestry(from: group).first { isDetailed($0) }
    }

    /// ADR-0032's one rule for placement: what the containment check accepts.
    public func allows(_ type: NodeType, in group: Group?) -> Bool {
        guard let holder = detailedNode(holding: group), let holderType = nodeType(of: holder) else {
            let details = typesDetailed(by: type)
            return details.isEmpty || details.contains(type)
        }
        return detailTypes(of: holderType).contains(type)
    }

    /// Unlike a move, what is inside counts too: a paste brings it all, and
    /// none of it was placed under the check before.
    public func misplacement(among ids: [String], in group: Group?) -> (type: NodeType, holder: Group?)? {
        ids.lazy.compactMap { resolveCommandTarget(id: $0) }.compactMap { misplacement(of: $0, in: group) }.first
    }

    private func misplacement(of element: VCommandTarget, in group: Group?) -> (type: NodeType, holder: Group?)? {
        if let type = misplacedType(of: element, in: group) { return (type, group) }
        guard case .group(let inner) = element, let (groups, nodes) = try? groupStructure.directContent(of: inner)
        else { return nil }
        let children = groups.map { VCommandTarget.group($0) } + nodes.map { VCommandTarget.node($0) }
        return children.lazy.compactMap { misplacement(of: $0, in: inner) }.first
    }

    func misplacedType(of element: VCommandTarget, in group: Group?) -> NodeType? {
        placedTypes(of: element).first { !allows($0, in: group) }
    }

    /// A plain group is transparent, so it is judged by what it holds. Unknown
    /// types are skipped, as the check skips them.
    func placedTypes(of element: VCommandTarget) -> [NodeType] {
        switch element {
        case .edge:
            return []
        case .node(let node):
            guard let type = try? nodeType(for: node), type != NodeType.unknown else { return [] }
            return [type]
        case .group(let group):
            if let type = nodeType(of: group) { return [type] }
            guard let (childGroups, childNodes) = try? groupStructure.directContent(of: group) else { return [] }
            return childGroups.flatMap { placedTypes(of: .group($0)) } + childNodes.flatMap { placedTypes(of: .node($0)) }
        }
    }

    /// Seen through plain groups. Unknown types are left out; the unknown-type
    /// check already reports them.
    public func detailTypesHeld(by detailedNode: Group) -> [NodeType] {
        let nodeTypes = nodes.compactMap { node -> NodeType? in
            guard self.detailedNode(holding: group(of: node)) == detailedNode else { return nil }
            return try? nodeType(for: node)
        }
        let groupTypes = groups.compactMap { group -> NodeType? in
            guard group != detailedNode, self.detailedNode(holding: parentGroup(of: group)) == detailedNode
            else { return nil }
            return nodeType(of: group)
        }
        return (nodeTypes + groupTypes).filter { $0 != NodeType.unknown }
    }

    /// Over everything installed so far, so a `vnotation` is judged together with its base.
    func validateNotation() throws(VError) {
        for groupType in groupTypes where has(nodeTypeName: groupType.description) {
            throw VError.typeNameIsNodeAndGroupType(groupType.description)
        }
        let pairs = notationDefinition.detailings
        for pair in pairs {
            for type in [pair.nodeType, pair.detailType] where !has(nodeType: type) {
                throw VError.detailingNamesUnknownType(of: pair.nodeType, unknown: type)
            }
        }
        if let cycle = Self.cycle(in: pairs) {
            throw VError.detailingCycle(cycle)
        }
    }

    /// A type detailed by itself is no cycle: it is how a sub-process recurses.
    private static func cycle(in pairs: [NotationDefinition.DeclaredDetailing]) -> [NodeType]? {
        let steps = pairs.filter { $0.nodeType != $0.detailType }
        var cleared: Set<NodeType> = []
        func visit(_ type: NodeType, path: [NodeType]) -> [NodeType]? {
            if let start = path.firstIndex(of: type) { return Array(path[start...]) + [type] }
            if cleared.contains(type) { return nil }
            for step in steps where step.nodeType == type {
                if let cycle = visit(step.detailType, path: path + [type]) { return cycle }
            }
            cleared.insert(type)
            return nil
        }
        for step in steps {
            if let cycle = visit(step.nodeType, path: []) { return cycle }
        }
        return nil
    }
}

extension VGraph {
    /// Group values (fold state, layout, frame) mean nothing on a node
    /// and go; node values move across in every layer.
    func replacing(detailed group: Group, withNodeOfType type: NodeType, in parent: Group?) throws(VError) -> VGraph {
        let node = Node(group)
        let store = attributeStore.rekeying(from: ItemKey(group), to: ItemKey(node))
            .removing(for: ItemKey(node)) { $0.target == .group }
        return try updatedSelfWith(attributeStore: store)
            .deleting(group: group)
            .adding(node: node, type: type, group: parent)
            .repruning(ItemKey(node))
    }
}
