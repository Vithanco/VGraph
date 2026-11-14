// Artwork VGraph ships is held to what a document is held to: an icon that
// cannot be expressed in VGL cannot be round-tripped through a `vnotation` that
// overrides it either.

import Foundation
import Testing

@testable import VGraph

@Suite("Built-in icons")
struct BuiltinIconsTests {

    @Test("Every icon is artwork a document could equally have declared")
    func everyMarkIsExpressibleInVGL() throws {
        let names = BuiltinIcons.names
        #expect(!names.isEmpty)

        for name in names {
            let artwork = try #require(BuiltinIcons.artwork(for: name), "\(name) resolves to nothing")
            let remade = IconArtwork.make(viewBox: artwork.viewBox, path: artwork.path)
            #expect(remade != nil, "\(name) would be refused by the parser")
            #expect(remade?.path == artwork.path, "\(name) does not survive a round trip through make")
        }
    }

    @Test("Given the VGL guide, when its list of built-in icons is read, then it names every built-in icon")
    func theVGLGuideListsEveryBuiltInIcon() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let guide = try String(contentsOf: repo.appendingPathComponent("docs/VGL_GUIDE.md"), encoding: .utf8)
        let unlisted = BuiltinIcons.names.filter { !guide.contains("`\($0)`") }
        #expect(unlisted.isEmpty, "the VGL guide does not list \(unlisted.sorted())")
    }
}
