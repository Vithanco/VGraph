/// What a rule talks about. Edges are never selected: one shows when both its ends do.
public struct Selector: VProtocol {
    public enum Subject: VProtocol {
        case nodes([String])
        case groups([String])
        case nodeTypes([String])
        case groupTypes([String])
        case everything
    }

    /// Steps along edges, counted from what the subject names.
    public enum Reach: VProtocol {
        case downstream(Int)
        case upstream(Int)
        case around(Int)
    }

    public let subject: Subject
    public let reach: Reach?

    public init(_ subject: Subject, reach: Reach? = nil) {
        self.subject = subject
        self.reach = reach
    }
}

/// A view chooses elements by ordered rules; each is applied to what the rules
/// before it left.
public enum ViewRule: VProtocol {
    case include(Selector)
    case exclude(Selector)
    case expand(Int)
}

extension ViewRule {
    /// The rule without the named elements, or `nil` when nothing it names is left.
    func removing(nodes: Set<String>, groups: Set<String>) -> ViewRule? {
        switch self {
        case .expand:
            return self
        case .include(let selector):
            return selector.removing(nodes: nodes, groups: groups).map { .include($0) }
        case .exclude(let selector):
            return selector.removing(nodes: nodes, groups: groups).map { .exclude($0) }
        }
    }
}

extension Selector {
    fileprivate func removing(nodes: Set<String>, groups: Set<String>) -> Selector? {
        switch subject {
        case .nodes(let names):
            let kept = names.filter { !nodes.contains($0) }
            return kept.isEmpty ? nil : Selector(.nodes(kept), reach: reach)
        case .groups(let names):
            let kept = names.filter { !groups.contains($0) }
            return kept.isEmpty ? nil : Selector(.groups(kept), reach: reach)
        case .nodeTypes, .groupTypes, .everything:
            return self
        }
    }
}

/// The list a selector names an element in. Decompose and its inverse keep the
/// id and move it from one list to the other.
enum NamedAs {
    case node
    case group

    fileprivate func subject(_ names: [String]) -> Selector.Subject {
        switch self {
        case .node: return .nodes(names)
        case .group: return .groups(names)
        }
    }

    fileprivate func names(in subject: Selector.Subject) -> [String]? {
        switch (self, subject) {
        case (.node, .nodes(let names)), (.group, .groups(let names)): return names
        default: return nil
        }
    }
}

extension ViewRule {
    /// A list naming the element alongside others splits in two, as one
    /// selector names one kind.
    func renaming(_ id: String, from old: NamedAs, to new: NamedAs) -> [ViewRule] {
        switch self {
        case .expand:
            return [self]
        case .include(let selector):
            return selector.renaming(id, from: old, to: new).map { .include($0) }
        case .exclude(let selector):
            return selector.renaming(id, from: old, to: new).map { .exclude($0) }
        }
    }
}

extension Selector {
    fileprivate func renaming(_ id: String, from old: NamedAs, to new: NamedAs) -> [Selector] {
        guard let names = old.names(in: subject), names.contains(id) else { return [self] }
        let others = names.filter { $0 != id }
        let renamed = Selector(new.subject([id]), reach: reach)
        return others.isEmpty ? [renamed] : [Selector(old.subject(others), reach: reach), renamed]
    }
}
