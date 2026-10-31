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
        let store = try ads.addLayer(Self.layer(ofView: view.name), parent: .model, admission: .view)
        return VGraph(base: self, ads: store, views: views + [view])
    }

    public func removing(view name: String) throws(VError) -> VGraph {
        let layer = try viewLayer(name)
        return VGraph(base: self, ads: try ads.removeLayer(layer), views: views.filter { $0.name != name })
    }

    /// The same values under a new name; the source stays as it was.
    public func duplicating(view name: String, as copy: ViewDeclaration) throws(VError) -> VGraph {
        let source = try viewLayer(name)
        let rules = views.first { $0.name == name }?.rules ?? []
        var result = try declaring(view: ViewDeclaration(name: copy.name, label: copy.label, rules: rules))
        var values: [(key: ItemKey, attribute: Attribute)] = []
        for key in ads.keys(in: source) {
            for (id, value) in try ads.values(in: source, for: key) {
                guard let definition = ads.definitions[id] else { continue }
                values.append((key: key, attribute: try definition.attribute(fromString: value)))
            }
        }
        result = result.updatedSelfWith(
            ads: try result.ads.merging(values, into: Self.layer(ofView: copy.name), chains: result))
        return result
    }

    public func relabelling(view name: String, as label: String?) throws(VError) -> VGraph {
        _ = try viewLayer(name)
        return VGraph(
            base: self, ads: ads,
            views: views.map { $0.name == name ? ViewDeclaration(name: name, label: label, rules: $0.rules) : $0 })
    }

    /// A command deleted these elements, so no view's rule names them any more.
    /// Only what was deleted goes: a name the author wrote that never existed stays.
    public func removingFromViews(nodes: Set<String>, groups: Set<String>) -> VGraph {
        VGraph(
            base: self, ads: ads,
            views: views.map {
                ViewDeclaration(
                    name: $0.name, label: $0.label,
                    rules: $0.rules.compactMap { $0.removing(nodes: nodes, groups: groups) })
            })
    }

    /// The element is still there under another kind, so views keep naming it.
    func renamingInViews(_ id: String, from old: NamedAs, to new: NamedAs) -> VGraph {
        VGraph(
            base: self, ads: ads,
            views: views.map {
                ViewDeclaration(
                    name: $0.name, label: $0.label, rules: $0.rules.flatMap { $0.renaming(id, from: old, to: new) })
            })
    }

    /// The name a view takes from its label, or `nil` when the label cannot give one.
    ///
    /// Refused, not repaired: the label is what the author reads, and silently
    /// dropping a character would give a name they did not choose. The lexer reads
    /// an identifier as alphanumerics plus `_`, `.` and `-`; the first character
    /// must not look like a number.
    public static func viewName(forLabel label: String, taken: [String]) -> String? {
        var base = ""
        var gap = false
        for character in label {
            if character == " " {
                gap = !base.isEmpty
                continue
            }
            guard character.isASCII, character.isLetter || character.isNumber || "_.-".contains(character) else {
                return nil
            }
            if gap { base += "-" }
            gap = false
            base += String(character).lowercased()
        }
        guard let first = base.first, first.isLetter || first == "_" else { return nil }
        guard !isKeyword(base) else { return nil }
        var name = base
        var number = 2
        while taken.contains(name) {
            name = "\(base)\(number)"
            number += 1
        }
        return name
    }

    /// A value equal to what the model gives along the same chain is not stored.
    public func settingInView(_ name: String, _ attribute: Attribute, for key: ItemKey) throws(VError) -> VGraph {
        let layer = try viewLayer(name)
        return updatedSelfWith(ads: try ads.set(attribute, for: key, in: layer, chains: self))
    }

    public func attributes(inView name: String, of key: ItemKey) throws(VError) -> AttributeContainer {
        try ads.values(in: try viewLayer(name), for: key)
    }

    /// A fixed order, so an export does not depend on dictionary order.
    public func keys(inView name: String) throws(VError) -> [ItemKey] {
        let layer = try viewLayer(name)
        let order: [ItemKind] = [.root, .node, .group, .nodeType, .groupType, .edge, .edgeType]
        return ads.keys(in: layer).sorted { left, right in
            let l = order.firstIndex(of: left.kind) ?? order.count
            let r = order.firstIndex(of: right.kind) ?? order.count
            return l != r ? l < r : left.id < right.id
        }
    }

    /// The display graph: what the Display pipeline reads and writes. It reads
    /// through the named view, or through the model when none is named — the
    /// default view, shown even in a document that declares views. The origin
    /// graph keeps reading through the model, so judging never sees a view.
    public func displaying(view name: String?) throws(VError) -> VGraph {
        guard let name else { return VGraph(base: self, readLayer: .model) }
        let shown = try selection(of: name)
        var view = VGraph(base: self, readLayer: try viewLayer(name))
        // Recorded before hiding: a loop with a hidden stretch keeps its marker on the edges that survive.
        if view.marksLoops { view = try TLoop.recordStep(view) }
        let kept = try view.keeping(nodes: shown.nodes, groups: shown.groups)
        return view.drawsDerivedEdges ? try kept.addingDerivedEdges(of: self, visible: shown.nodes) : kept
    }
}
