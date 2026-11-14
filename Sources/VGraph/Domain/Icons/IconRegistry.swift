/// Only what the *document* declared; the built-ins are the fallback in
/// ``VGraph/artwork(forIcon:)``, so the exporter can still tell an icon the user
/// wrote from one VGraph ships (ADR-0022).
///
/// Lives in `NotationDefinition.icons` as a value, not in the attribute store (ADR-0030).
public struct IconRegistry: VProtocol {
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
}
