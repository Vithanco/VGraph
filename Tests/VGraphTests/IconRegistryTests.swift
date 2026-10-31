// The renderer is handed a laid-out graph and never a notation, so the graph is
// the only thing that can answer what a name means. ADR-0022 has why it carries
// the document's declarations and not the built-ins.

import Testing
import VGraph

@Suite("The artwork a graph carries")
struct IconRegistryTests {

    private static let flame = IconArtwork(
        width: 24, height: 24, path: "M12 2c0.5,3.5 -4,5 -4,9 a4,4 0 0 0 8,0 c0,-2 -2,-4 -4,-7z")

    @Test("A declared name resolves to its artwork")
    func aDeclaredNameResolves() throws {
        let graph = try VGraph().add(icon: "flame", artwork: Self.flame)

        #expect(graph.artwork(forIcon: "flame") == Self.flame)
    }

    /// The store's `[String]` encoding splits on commas and path data is full of
    /// them, so this is the encoding's real test rather than a formality.
    @Test("Punctuation in path data survives the store")
    func pathDataSurvivesTheStore() throws {
        let awkward = IconArtwork(
            minX: -2, minY: -2.5, width: 28, height: 30,
            path: "M 1,2 L 3.5,-4 C 0,0 1e2,3 4,5 Z")
        let graph = try VGraph().add(icon: "awkward", artwork: awkward)

        #expect(graph.artwork(forIcon: "awkward") == awkward)
    }

    @Test("A name nobody declared falls through to the built-in set")
    func builtInsAreTheFallback() throws {
        let graph = try VGraph().add(icon: "flame", artwork: Self.flame)

        #expect(graph.artwork(forIcon: "and") == BuiltinIcons.artwork(for: "and"))
    }

    /// A built-in added in a later release must not change a document that
    /// already draws its own icon under that name.
    @Test("A declared name shadows a built-in of the same name")
    func declaredShadowsBuiltIn() throws {
        let graph = try VGraph().add(icon: "and", artwork: Self.flame)

        #expect(graph.artwork(forIcon: "and") == Self.flame)
        #expect(BuiltinIcons.artwork(for: "and") != Self.flame, "the built-in itself is untouched")
    }

    @Test("A name in neither resolves to nothing, for the caller to substitute")
    func anUnknownNameResolvesToNothing() throws {
        let graph = try VGraph().add(icon: "flame", artwork: Self.flame)

        #expect(graph.artwork(forIcon: "no.such.mark") == nil)
    }

    @Test("The graph carries only what the document declared")
    func onlyDeclaredArtworkIsCarried() throws {
        let graph = try VGraph().add(icon: "flame", artwork: Self.flame)

        #expect(graph.declaredIcons.count == 1)
        #expect(graph.declaredIcons["flame"] == Self.flame)
        #expect(graph.declaredIcons["and"] == nil, "the built-ins are not seeded into it")
    }

    @Test("Declaring the same name twice keeps the later artwork")
    func redeclaringReplaces() throws {
        let other = IconArtwork(width: 10, height: 10, path: "M0 0h10v10h-10z")
        let graph = try VGraph()
            .add(icon: "flame", artwork: Self.flame)
            .add(icon: "flame", artwork: other)

        #expect(graph.artwork(forIcon: "flame") == other)
        #expect(graph.declaredIcons.count == 1)
    }
}
