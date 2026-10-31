//
//  VCommandID.swift
//  VGraph
//
//  A [[VCommand]]'s identity, as a type rather than a string.
//

/// Names one command. An **open set**, not an enum: `init(_:)` is public, so a
/// command this build has never heard of is still representable — which is what
/// keeps the catalogue extensible and lets a caller name a deliberately unknown
/// id (a stale click, a test).
///
/// The point is the static members below. An adapter reaching for a command by
/// name writes `.setLabel`, so a misspelling is a compile error rather than a
/// silent `.unavailable` that looks exactly like a disabled command.
public struct VCommandID: Hashable, Sendable {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }
}

extension VCommandID {
    public static let toggleFolding = VCommandID("toggleFolding")
    public static let addNode = VCommandID("addNode")
    public static let addSuccessor = VCommandID("addSuccessor")
    public static let addPredecessor = VCommandID("addPredecessor")
    public static let changeType = VCommandID("changeType")
    public static let changeDirection = VCommandID("changeDirection")
    public static let split = VCommandID("split")
    public static let setLabel = VCommandID("setLabel")
    public static let openURL = VCommandID("openURL")
    public static let setURL = VCommandID("setURL")
    public static let removeURL = VCommandID("removeURL")
    public static let delete = VCommandID("delete")

    /// Which loops a Causal Loop Diagram marks: a setting of the whole diagram,
    /// offered on the canvas menu (ADR-0028).
    public static let loopMarkers = VCommandID("loopMarkers")

    /// A setting of the whole diagram, written to the shown view (or the model).
    public static let layoutDirection = VCommandID("layoutDirection")

    /// The View menu's rows. Not element commands: their subject is a view.
    public static let newView = VCommandID("newView")
    public static let duplicateView = VCommandID("duplicateView")
    public static let renameView = VCommandID("renameView")
    public static let deleteView = VCommandID("deleteView")

    /// Makes a group of the [[Effective selection]]. Named once for both the
    /// strict and the detaching form: they are one row in the menu, whose title
    /// says which of the two it would run (ADR-0018).
    public static let addGroup = VCommandID("addGroup")

    /// Changes which group elements belong to. A [[Gesture]] with no menu entry,
    /// as `connect` is, so every adapter that wants it implements it by name
    /// (ADR-0019).
    public static let move = VCommandID("move")

    /// Takes a group apart and leaves its contents behind — grouping's inverse.
    /// Distinct from `delete`, which takes the contents with it (ADR-0018).
    public static let ungroup = VCommandID("ungroup")

    /// Makes a node a detailed node with its first details (ADR-0032). A model
    /// command: unfolding never decomposes.
    public static let decompose = VCommandID("decompose")

    /// The only [[Gesture]], and the one command with no menu entry — an adapter
    /// that wants it must know it by name (ADR-0012).
    public static let connect = VCommandID("connect")

    /// Moves one [[Edge end]] to another node. A [[Gesture]] too, and the first
    /// command whose subject is not an element: its target is an edge *and a
    /// side*, which `VCommandTarget` cannot express (ADR-0021).
    public static let reattach = VCommandID("reattach")
}
