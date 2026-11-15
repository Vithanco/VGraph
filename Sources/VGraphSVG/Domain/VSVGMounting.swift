// What mounting a tree needs to know about it. See ADR-0015 F1.

import VGraph

/// One child of a mounted element, and the key that tells it from its siblings
/// across redraws (ADR-0015 F1).
public struct MountedChild: Sendable, Equatable {
    public let key: String
    public let node: VSVGNode
}

/// The children of a drawn element as the reconciler has to see them: a flat
/// list, every entry keyed.
///
/// An `id` is the key wherever there is one, because it names the same graph
/// element in the next drawing — unless the renderer gave the element a
/// ``SVGElementId/keyAttribute``, which it does where the id is not stable.
/// Without either the key is the place among siblings
/// of the *same tag* — a plain index would re-key everything behind an
/// insertion, and the reconciler would rewrite elements that did not change.
public func mountedChildren(of children: [VSVGNode]) -> [MountedChild] {
    var result: [MountedChild] = []
    var ordinals: [String: Int] = [:]
    var taken: Set<String> = []
    for child in flattened(children) {
        let wanted =
            attribute(SVGElementId.keyAttribute, of: child) ?? attribute("id", of: child)
            ?? ordinalKey(for: child, counting: &ordinals)
        var key = wanted
        var repeats = 1
        while taken.contains(key) {
            key = "\(wanted)~\(repeats)"
            repeats += 1
        }
        taken.insert(key)
        result.append(MountedChild(key: key, node: child))
    }
    return result
}

private func flattened(_ children: [VSVGNode]) -> [VSVGNode] {
    var result: [VSVGNode] = []
    for child in children {
        switch child {
        case .fragment(let inner): result += flattened(inner)
        case .element: result.append(child)
        case .text(let content): if !content.isEmpty { result.append(child) }
        case .raw, .empty: break
        }
    }
    return result
}

private func attribute(_ name: String, of node: VSVGNode) -> String? {
    guard case .element(_, let attributes, _) = node else { return nil }
    return attributes.first { $0.name == name }?.value
}

private func ordinalKey(for node: VSVGNode, counting ordinals: inout [String: Int]) -> String {
    let kind: String
    if case .element(let tag, _, _) = node { kind = tag.name } else { kind = "#text" }
    let ordinal = ordinals[kind] ?? 0
    ordinals[kind] = ordinal + 1
    return "\(kind):\(ordinal)"
}

/// A drawing's frame — its `viewBox` — as numbers, for a pane that eases from
/// one drawing's to the next's instead of letting the picture jump.
public func mountedFrame(of root: VSVGNode) -> VRect? {
    guard case .element(.svg, let attributes, _) = root,
        let viewBox = attributes.first(where: { $0.name == "viewBox" })?.value
    else { return nil }
    let numbers = viewBox.split(separator: " ").map { Double($0) }
    guard numbers.count == 4,
        let x = numbers[0], let y = numbers[1], let width = numbers[2], let height = numbers[3]
    else { return nil }
    return VRect(origin: VPoint(x: x, y: y), size: VSize(width: width, height: height))
}
