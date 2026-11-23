/// The visual style of a group, holding both faces a group can present:
/// - `folded`: how the group looks when collapsed into a single box (a node layout).
/// - `unfolded`: the frame drawn round the group's contents.
///
/// This is the group-level counterpart of a node's `NodeStyleLayout`. A group's
/// `GroupType` (or a per-group override) carries a `GroupStyle`; folding uses the
/// `folded` face for the collapsed proxy, and frame rendering uses `unfolded`.
public struct GroupStyle: VProtocol, AttributeType {
    public let folded: NodeStyleLayout
    public let unfolded: GroupFrame

    public init(folded: NodeStyleLayout, unfolded: GroupFrame) {
        self.folded = folded
        self.unfolded = unfolded
    }

    public static let `default` = GroupStyle(folded: .empty, unfolded: .default)

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "GroupStyle"
    }

    /// Length-prefixed encoding so the (brace-nested) folded layout survives
    /// round-trip without a delimiter collision: "<n>:<folded><unfolded>".
    public var asString: String {
        let foldedText = folded.asString
        return "\(foldedText.count):\(foldedText)\(unfolded.asString)"
    }

    public static func fromString(_ string: String) throws(VError) -> GroupStyle {
        guard let colon = string.firstIndex(of: ":") else {
            throw VError.parsingError("GroupStyle: missing length prefix")
        }
        let countString = String(string[string.startIndex..<colon])
        let count = try Int.fromString(countString)
        let chars = Array(string[string.index(after: colon)...])
        guard count >= 0, count <= chars.count else {
            throw VError.parsingError("GroupStyle: length prefix out of range")
        }
        let foldedString = String(chars[0..<count])
        let unfoldedString = String(chars[count...])
        let folded = try NodeStyleLayout.fromString(foldedString)
        let unfolded = try GroupFrame.fromString(unfoldedString)
        return GroupStyle(folded: folded, unfolded: unfolded)
    }
}

/// The frame drawn round an unfolded group: the dashed border, its colour, and
/// the fill. A C4 group type registers a distinct frame (muted dashed
/// border, transparent fill) so it reads differently from a plain group;
/// `applyGroupFrameStep` stamps these onto the group's loose `Attributes.Group.*`
/// so the SVG renderer draws them without special-casing group types.
public struct GroupFrame: VProtocol, AttributeType {
    public let cornerRadius: Double
    /// SVG `stroke-dasharray` (empty = solid).
    public let borderDash: String
    public let borderColor: SemanticColor
    /// Usually clear/transparent for a C4 group (`#00000000`).
    public let fill: SemanticColor

    public init(
        cornerRadius: Double = 8,
        borderDash: String = "6,3",
        borderColor: SemanticColor = SemanticColor.groupBorder,
        fill: SemanticColor = SemanticColor.groupFill
    ) {
        self.cornerRadius = cornerRadius
        self.borderDash = borderDash
        self.borderColor = borderColor
        self.fill = fill
    }

    public static let `default` = GroupFrame()

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "GroupFrame"
    }

    /// Four `|`-separated fields. Colours serialise to `#rrggbbaa` and `borderDash`
    /// (e.g. `6,3`) carries no `|`, so the delimiter never collides.
    public var asString: String {
        return "\(cornerRadius)|\(borderDash)|\(borderColor.asString)|\(fill.asString)"
    }

    public static func fromString(_ string: String) throws(VError) -> GroupFrame {
        // The `String` separator form keeps empty fields: a solid frame has an
        // empty borderDash, which `split` and the `Character` form would drop.
        let separator: String = "|"
        let fields = string.components(separatedBy: separator)

        guard fields.count == 4 else {
            throw VError.parsingError("GroupFrame: expected 4 fields, got \(fields.count)")
        }
        let cornerRadius = try Double.fromString(fields[0])
        let borderDash = fields[1]
        let borderColor = try SemanticColor.fromString(fields[2])
        let fill = try SemanticColor.fromString(fields[3])
        return GroupFrame(
            cornerRadius: cornerRadius, borderDash: borderDash,
            borderColor: borderColor, fill: fill)
    }
}
