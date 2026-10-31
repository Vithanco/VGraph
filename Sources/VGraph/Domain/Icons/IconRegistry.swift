/// Only what the *document* declared; the built-ins are the fallback in
/// ``VGraph/artwork(forIcon:)``, so the exporter can still tell an icon the user
/// wrote from one VGraph ships (ADR-0022).
///
/// Not a list of strings: the store's `[String]` encoding splits on commas, and
/// path data is full of them. `|` and newline are safe because the parser admits
/// neither in a path.
public struct IconRegistry: VProtocol, AttributeType {
    public private(set) var entries: [String: IconArtwork]

    public init(entries: [String: IconArtwork] = [:]) {
        self.entries = entries
    }

    public subscript(name: String) -> IconArtwork? {
        entries[name]
    }

    public func adding(name: String, artwork: IconArtwork) -> IconRegistry {
        var updated = entries
        updated[name] = artwork
        return IconRegistry(entries: updated)
    }

    public static let typeName: String = "IconRegistry"

    public static func fromString(_ string: String) throws(VError) -> IconRegistry {
        guard !string.isEmpty else { return IconRegistry() }

        var entries: [String: IconArtwork] = [:]
        for line in string.split(separator: "\n") {
            let fields = line.split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 6,
                let minX = Double(fields[1]), let minY = Double(fields[2]),
                let width = Double(fields[3]), let height = Double(fields[4])
            else {
                throw VError.conversionError(from: string, to: typeName)
            }
            entries[fields[0]] = IconArtwork(
                minX: minX, minY: minY, width: width, height: height, path: fields[5])
        }
        return IconRegistry(entries: entries)
    }

    /// Sorted by name: the store round-trips through this string, and a
    /// dictionary's own order is not one.
    public var asString: String {
        entries.keys.sorted()
            .map { name in
                let art = entries[name]!
                return "\(name)|\(art.minX)|\(art.minY)|\(art.width)|\(art.height)|\(art.path)"
            }
            .joined(separator: "\n")
    }
}
