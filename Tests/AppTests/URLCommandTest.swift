//
//  URLCommandTest.swift
//  VGraph
//
//  The URL commands: attach a link to any element, change it, remove it, and
//  open it.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct URLCommandTest {
    let vgl = """
        vgraph demo: ConceptMap "Demo" {
          group g1 "Cluster" {
            node a: Concept "A";
          }
          node r: Relation "leads to";
          edge a -> r;
        }
        """

    private func session() throws -> TestSession {
        try makeTestSession(vgl: vgl)
    }

    private func edgeId(_ s: TestSession) -> String {
        s.origin.edges.first!.id.id
    }

    // MARK: - Setting

    /// With no answer the command asks for the text; with one it commits. Same two
    /// arities as `setLabel` (ADR-0009), but the text cannot be typed on the
    /// element — a URL is not what the element displays.
    @Test func asksForTheURLThenStoresIt() throws {
        let s = try session()

        // Nothing stored, so the editor seeds the field with nothing.
        #expect(s.storedURL(of: "a") == nil)

        try s.setURL(of: "a", to: "https://vithanco.com")

        let exported = try s.exportVGL()
        #expect(exported.contains("url: \"https://vithanco.com\""))
        // Survives a reparse — the attribute is declared, not invented on export.
        try s.replaceDocument(vgl: exported)
        #expect(s.origin.url(of: .node(Node(string: "a"))) == "https://vithanco.com")
    }

    /// Add and change are one command: the difference is only what it is seeded
    /// with and what the menu calls it.
    @Test func changingSeedsTheEditorWithTheCurrentURL() throws {
        let s = try session()
        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .setURL }?.title == "Add URL…")

        try s.setURL(of: "a", to: "https://vithanco.com")

        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .setURL }?.title == "Change URL…")
        // What the editor seeds the field with the second time round.
        #expect(s.storedURL(of: "a") == "https://vithanco.com")

        try s.setURL(of: "a", to: "https://vithanco.com/docs")
        #expect(try s.exportVGL().contains("url: \"https://vithanco.com/docs\""))
    }

    /// Edges and groups carry links too — the same three commands reach all three
    /// kinds, as `setLabel` does.
    @Test func attachesToEdgesAndGroups() throws {
        let s = try session()

        try s.setURL(of: edgeId(s), to: "https://vithanco.com/edge")
        try s.setURL(of: "g1", to: "https://vithanco.com/group")

        let exported = try s.exportVGL()
        try s.replaceDocument(vgl: exported)
        #expect(s.origin.url(of: .edge(s.origin.edges.first!.id)) == "https://vithanco.com/edge")
        #expect(s.origin.url(of: .group(Group(rawValue: "g1"))) == "https://vithanco.com/group")
    }

    /// Rather than reporting an error the command simply asks again, seeded with
    /// what was typed. The named method refuses instead of storing it, and the
    /// editor catches that and re-opens the field holding the text — where the
    /// replay loop used to re-consume and re-reject the bad answer.
    @Test func refusesTextThatIsNotALink() throws {
        let s = try session()
        let before = try s.exportVGL()

        #expect(throws: VError.urlRefused(target: "a", url: "javascript:alert(1)")) {
            try s.setURL(of: "a", to: "javascript:alert(1)")
        }
        #expect(try s.exportVGL() == before)
        #expect(s.canUndo == false, "a refused link left an undo step")

        try s.setURL(of: "a", to: "https://vithanco.com")
        #expect(try s.exportVGL().contains("url: \"https://vithanco.com\""))
    }

    /// The two ways `setURL` fails are not the same failure, and the editor acts
    /// on the difference: a rejected link re-opens the field holding what was
    /// typed, while a target that is no longer there has nothing to re-ask about
    /// and closes the menu. Both were `VError` before, so the editor re-asked
    /// forever on a stale id.
    @Test func aRefusedLinkAndAStaleTargetAreDifferentFailures() throws {
        let s = try session()

        #expect(throws: VError.urlRefused(target: "a", url: "not a link")) {
            try s.setURL(of: "a", to: "not a link")
        }
        #expect(throws: VError.commandUnavailable(.setURL, target: "ghost")) {
            try s.setURL(of: "ghost", to: "https://vithanco.com")
        }
    }

    /// Clearing the field is the other way to say "no link" — the user has the
    /// dialog open already, so sending them to `removeURL` for it would be silly.
    @Test func clearingTheFieldRemovesTheLink() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://vithanco.com")

        try s.setURL(of: "a", to: "  ")

        #expect(s.origin.url(of: .node(Node(string: "a"))) == nil)
        #expect(!(try s.exportVGL().contains("url:")))
    }

    @Test func completesABareHostToHttps() throws {
        let s = try session()

        try s.setURL(of: "a", to: "vithanco.com/docs")

        #expect(try s.exportVGL().contains("url: \"https://vithanco.com/docs\""))
    }

    // MARK: - Opening

    /// Opening is a side effect, not a graph change: the command hands the URL back
    /// and the adapter does the opening. Nothing is recorded, so undo does not step
    /// over an "edit" that never happened.
    @Test func opensTheStoredURLWithoutTouchingHistory() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://vithanco.com")
        let version = s.currentVersion

        #expect(s.urlToOpen(of: "a") == "https://vithanco.com")

        #expect(s.currentVersion == version)
    }

    /// A link can also be typed straight into the VGL, where nothing checked it.
    /// Opening greys out rather than silently doing nothing; removing stays live,
    /// because a link too dangerous to follow is one you especially want gone.
    @Test func aDangerousLinkInTheDocumentCanBeRemovedButNotFollowed() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A" [url: "javascript:alert(1)"];
                }
                """)

        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .openURL }?.enabled == false)
        #expect(s.urlToOpen(of: "a") == nil)

        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .removeURL }?.enabled == true)
        try s.removeURL(from: "a")
        #expect(!(try s.exportVGL().contains("javascript:")))
    }

    /// Nothing to open, nothing to remove — both grey out until a link is there.
    @Test func openAndRemoveNeedALinkToExist() throws {
        let s = try session()

        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .openURL }?.enabled == false)
        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .removeURL }?.enabled == false)
        #expect(s.urlToOpen(of: "a") == nil)

        try s.setURL(of: "a", to: "https://vithanco.com")

        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .openURL }?.enabled == true)
        #expect(EditorCore.menu(for: "a", in: s).first { $0.id == .removeURL }?.enabled == true)
    }

    // MARK: - Removing

    @Test func removesTheLinkFromTheDocument() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://vithanco.com")

        try s.removeURL(from: "a")

        let exported = try s.exportVGL()
        #expect(!exported.contains("url:"))
        #expect(s.origin.url(of: .node(Node(string: "a"))) == nil)
        try s.replaceDocument(vgl: exported)
    }

    /// A link is an ordinary attribute, so undo restores it like any other edit.
    @Test func undoBringsARemovedLinkBack() throws {
        let s = try session()
        try s.setURL(of: "a", to: "https://vithanco.com")
        try s.removeURL(from: "a")

        _ = try s.undo()

        #expect(s.origin.url(of: .node(Node(string: "a"))) == "https://vithanco.com")
    }
}
