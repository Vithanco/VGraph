/// Monochrome by design: `iconColor:` fills the icon at the point of use, so
/// artwork carrying colours of its own would make that attribute a lie (ADR-0022).
public struct IconArtwork: VProtocol {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double
    public let path: String

    public init(minX: Double = 0, minY: Double = 0, width: Double, height: Double, path: String) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.path = path
    }

    /// The exporter writes this straight back into the `vnotation` block.
    public var viewBox: String {
        "\(minX.vglSpelling) \(minY.vglSpelling) \(width.vglSpelling) \(height.vglSpelling)"
    }

    /// `"`, `<` and `&` are absent, so a document cannot express them at all —
    /// a lock at the boundary rather than one every output path has to remember.
    private static let pathCharacters: Set<Character> = Set(
        "MmLlHhVvCcSsQqTtAaZz0123456789.,+-eE \t\n\r")

    /// Twice the largest built-in and change.
    public static let maxPathLength = 4096

    /// The one place the rules live, so anything else producing artwork is held
    /// to what a document is held to.
    public static func make(viewBox: String, path: String) -> IconArtwork? {
        let numbers =
            viewBox
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" || $0 == "\n" })
            .map(String.init)
        guard numbers.count == 4 else { return nil }

        var values: [Double] = []
        for number in numbers {
            guard let value = Double(number) else { return nil }
            values.append(value)
        }
        guard values[2] > 0, values[3] > 0 else { return nil }

        let trimmed = path.trimmingCharacters(in: " \t\n\r")
        guard !trimmed.isEmpty, trimmed.count <= maxPathLength else { return nil }
        for character in trimmed where !pathCharacters.contains(character) { return nil }

        return IconArtwork(
            minX: values[0], minY: values[1], width: values[2], height: values[3], path: trimmed)
    }

    /// A dashed square drawn as filled bars, because artwork is filled and never
    /// stroked. Not a question mark: that is the `default` icon, an icon the
    /// author has yet to choose, and a mistyped name must not read as that.
    public static let missing = IconArtwork(
        width: 24,
        height: 24,
        path:
            "M2 2h7v2h-7z M15 2h7v2h-7z M2 20h7v2h-7z M15 20h7v2h-7z "
            + "M2 2h2v7h-2z M2 15h2v7h-2z M20 2h2v7h-2z M20 15h2v7h-2z"
    )
}
