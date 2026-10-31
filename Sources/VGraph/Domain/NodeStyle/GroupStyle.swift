/// The visual style of a group, holding both faces a group can present:
/// - `folded`: how the group looks when collapsed into a single box (a node layout).
/// - `unfolded`: the boundary chrome drawn around the group's contents.
///
/// This is the group-level counterpart of a node's `NodeStyleLayout`. A group's
/// `GroupType` (or a per-group override) carries a `GroupStyle`; folding uses the
/// `folded` face for the collapsed proxy, and boundary rendering uses `unfolded`.
public struct GroupStyle: VProtocol, AttributeType {
    public let folded: NodeStyleLayout
    public let unfolded: BoundaryChrome

    public init(folded: NodeStyleLayout, unfolded: BoundaryChrome) {
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
        let f = folded.asString
        return "\(f.count):\(f)\(unfolded.asString)"
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
        let unfolded = try BoundaryChrome.fromString(unfoldedString)
        return GroupStyle(folded: folded, unfolded: unfolded)
    }
}

/// The chrome drawn around an unfolded group (its boundary box): the dashed border,
/// its colour, and the fill. A C4 boundary registers a distinct chrome (muted dashed
/// border, transparent fill) so it reads differently from a generic cluster; the
/// unfolded-boundary transform stamps these onto the group's loose `Attributes.Group.*`
/// so the SVG renderer draws them without special-casing group types.
public struct BoundaryChrome: VProtocol, AttributeType {
    public let cornerRadius: Double
    /// SVG `stroke-dasharray` (empty = solid).
    public let borderDash: String
    public let borderColor: SemanticColor
    /// Usually clear/transparent for a boundary (`#00000000`).
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

    public static let `default` = BoundaryChrome()

    // MARK: - AttributeType Conformance

    public static var typeName: String {
        return "BoundaryChrome"
    }

    /// Four `|`-separated fields. Colours serialise to `#rrggbbaa` and `borderDash`
    /// (e.g. `6,3`) carries no `|`, so the delimiter never collides.
    public var asString: String {
        return "\(cornerRadius)|\(borderDash)|\(borderColor.asString)|\(fill.asString)"
    }

    public static func fromString(_ string: String) throws(VError) -> BoundaryChrome {
        // Hand-rolled split preserving empty fields (a solid boundary has an empty
        // borderDash) — `String.split` omits empties, and this stays Embedded-safe.
        var fields: [String] = []
        var current = ""
        for ch in string {
            if ch == "|" {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)

        guard fields.count == 4 else {
            throw VError.parsingError("BoundaryChrome: expected 4 fields, got \(fields.count)")
        }
        let cornerRadius = try Double.fromString(fields[0])
        let borderDash = fields[1]
        let borderColor = try SemanticColor.fromString(fields[2])
        let fill = try SemanticColor.fromString(fields[3])
        return BoundaryChrome(
            cornerRadius: cornerRadius, borderDash: borderDash,
            borderColor: borderColor, fill: fill)
    }
}
