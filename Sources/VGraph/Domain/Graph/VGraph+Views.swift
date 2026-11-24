/// A view is a layer of the store (ADR-0030); the graph keeps what a layer cannot:
/// the declaration order the exporter follows, and the label.
public struct ViewDeclaration: VProtocol {
    public let name: String
    public let label: String?
    public let rules: [ViewRule]

    public init(name: String, label: String? = nil, rules: [ViewRule] = []) {
        self.name = name
        self.label = label
        self.rules = rules
    }
}

extension VGraph {
    /// Prefixed so a view can never take the name of a layer the engine owns.
    public static func layer(ofView name: String) -> AttributeLayer { AttributeLayer("view:\(name)") }

    private func viewLayer(_ name: String) throws(VError) -> AttributeLayer {
        guard views.contains(where: { $0.name == name }) else {
            throw VError.unknownView(name, available: views.map { $0.name })
        }
        return Self.layer(ofView: name)
    }

    public func declaring(view: ViewDeclaration) throws(VError) -> VGraph {
        guard !views.contains(where: { $0.name == view.name }) else { throw VError.duplicateView(view.name) }
        let store = try attributeStore.addingLayer(Self.layer(ofView: view.name), parent: .model, admission: .view)
        return VGraph(base: self, attributeStore: store, views: views + [view])
    }

    public func removing(view name: String) throws(VError) -> VGraph {
        let layer = try viewLayer(name)
        return VGraph(base: self, attributeStore: try attributeStore.removingLayer(layer), views: views.filter { $0.name != name })
    }

    /// The same values under a new name; the source stays as it was.
    public func duplicating(view name: String, as copy: ViewDeclaration) throws(VError) -> VGraph {
        let source = try viewLayer(name)
        let rules = views.first { $0.name == name }?.rules ?? []
        let declared = try declaring(view: ViewDeclaration(name: copy.name, label: copy.label, rules: rules))
        let values = try attributeStore.attributes(in: source)
        return declared.updatedSelfWith(
            attributeStore: try declared.attributeStore.merging(values, into: Self.layer(ofView: copy.name), chains: declared))
    }

    public func relabeling(view name: String, as label: String?) throws(VError) -> VGraph {
        _ = try viewLayer(name)
        return VGraph(
            base: self, attributeStore: attributeStore,
            views: views.map { $0.name == name ? ViewDeclaration(name: name, label: label, rules: $0.rules) : $0 })
    }

    /// A command deleted these elements, so no view's rule names them any more.
    /// Only what was deleted goes: a name the author wrote that never existed stays.
    public func removingFromViews(nodes: Set<String>, groups: Set<String>) -> VGraph {
        VGraph(
            base: self, attributeStore: attributeStore,
            views: views.map {
                ViewDeclaration(
                    name: $0.name, label: $0.label,
                    rules: $0.rules.compactMap { $0.removing(nodes: nodes, groups: groups) })
            })
    }

    /// The element is still there under another kind, so views keep naming it.
    func renamingInViews(_ id: String, from old: NamedAs, to new: NamedAs) -> VGraph {
        VGraph(
            base: self, attributeStore: attributeStore,
            views: views.map {
                ViewDeclaration(
                    name: $0.name, label: $0.label, rules: $0.rules.flatMap { $0.renaming(id, from: old, to: new) })
            })
    }

    /// The name a view takes from its label, or `nil` when the label cannot give one.
    ///
    /// Refused, not repaired: the label is what the author reads, and silently
    /// dropping a character would give a name they did not choose.
    public static func viewName(forLabel label: String, taken: [String]) -> String? {
        let words = label.split(separator: " ")
        guard words.allSatisfy({ $0.allSatisfy { isVGLIdentifierCharacter($0) } }) else { return nil }
        let base = words.joined(separator: "-").lowercased()
        guard isVGLIdentifier(base), !isVGLKeyword(base) else { return nil }
        guard taken.contains(base) else { return base }
        return (2...).lazy.map { "\(base)\($0)" }.first { !taken.contains($0) }
    }

    /// A value equal to what the model gives along the same chain is not stored.
    public func settingInView(_ name: String, _ attribute: Attribute, for key: ItemKey) throws(VError) -> VGraph {
        let layer = try viewLayer(name)
        return updatedSelfWith(attributeStore: try attributeStore.setting(attribute, for: key, in: layer, chains: self))
    }

    /// All at once, so what is pruned does not depend on the order the values
    /// arrive in: an element set back to its model value survives its type
    /// being recoloured in the same view.
    public func mergingInView(_ name: String, _ values: [(key: ItemKey, attribute: Attribute)]) throws(VError) -> VGraph {
        let layer = try viewLayer(name)
        return updatedSelfWith(attributeStore: try attributeStore.merging(values, into: layer, chains: self))
    }

    public func attributes(inView name: String, of key: ItemKey) throws(VError) -> AttributeContainer {
        try attributeStore.values(in: try viewLayer(name), for: key)
    }

    /// A fixed order, so an export does not depend on dictionary order.
    public func keys(inView name: String) throws(VError) -> [ItemKey] {
        let layer = try viewLayer(name)
        let order: [ItemKind] = [.root, .node, .group, .nodeType, .groupType, .edge, .edgeType]
        return attributeStore.keys(in: layer).sorted { left, right in
            let leftRank = order.firstIndex(of: left.kind) ?? order.count
            let rightRank = order.firstIndex(of: right.kind) ?? order.count
            return leftRank != rightRank ? leftRank < rightRank : left.id < right.id
        }
    }

    /// The view graph: what the Display pipeline reads and writes. It reads
    /// through the named view, or through the model when none is named — the
    /// default view, shown even in a document that declares views. The origin
    /// graph keeps reading through the model, so judging never sees a view.
    public func displaying(view name: String?) throws(VError) -> VGraph {
        guard let name else { return VGraph(base: self, readLayer: .model) }
        let shown = try subset(of: name)
        let unrecorded = VGraph(base: self, readLayer: try viewLayer(name))
        // Recorded before hiding: a loop with a hidden stretch keeps its marker on the edges that survive.
        let view = unrecorded.marksLoops ? try FeedbackLoop.recordStep(unrecorded) : unrecorded
        let kept = try view.keeping(shown)
        return view.drawsDerivedEdges ? try kept.addingDerivedEdges(of: self, visible: shown.nodes) : kept
    }
}
