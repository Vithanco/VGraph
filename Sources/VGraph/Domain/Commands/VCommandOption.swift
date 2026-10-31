//
//  VCommandOption.swift
//  VGraph
//
//  What a picker shows. The domain decides the entries — their ids, their
//  titles, and which one is the way past the notation — because every one of
//  those is a notation fact. An adapter draws the list and hands back the id.
//

/// One entry in a list an adapter puts on screen — a candidate the notation
/// offered, or the escape hatch past it.
public struct VCommandOption: Sendable, Equatable {
    public let id: String
    public let title: String
    /// The "Other type…" entry: the escape hatch that opens the full type list,
    /// allowing a [[Notation break]]. Not a candidate the notation offered, so
    /// it is marked rather than being recognised by a reserved id.
    public let isBreak: Bool

    public init(id: String, title: String, isBreak: Bool = false) {
        self.id = id
        self.title = title
        self.isBreak = isBreak
    }

    /// The only real candidate, or nil when there is a genuine choice — or when
    /// `options` is not a candidate list at all, recognised by the escape hatch
    /// only a candidate list carries. An adapter uses this to skip a menu nobody
    /// needs to see (ADR-0009).
    public static func soleCandidate(in options: [VCommandOption]) -> VCommandOption? {
        var candidate: VCommandOption? = nil
        var count = 0
        var hasEscapeHatch = false
        for option in options {
            if option.isBreak {
                hasEscapeHatch = true
            } else {
                candidate = option
                count += 1
            }
        }
        return (hasEscapeHatch && count == 1) ? candidate : nil
    }
}
