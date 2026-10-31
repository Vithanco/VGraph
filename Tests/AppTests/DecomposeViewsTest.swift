import Testing
import VGraph

@testable import App

/// Decomposing changes no other view (ADR-0032).
struct DecomposeViewsTest {
    private func session(views: String, body: String = "") throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                }

                vgraph g: Arch "G" {
                  node alice: Person "Alice";
                  node bank: System "Bank";
                  edge alice -> bank "logs in";
                \(body)
                }

                \(views)
                """)
    }

    private func viewBlock(_ name: String, in text: String) -> String {
        guard let start = text.range(of: "vview \(name)") else { return "" }
        let rest = text[start.lowerBound...]
        guard let end = rest.range(of: "\n}") else { return String(rest) }
        return String(rest[..<end.upperBound])
    }

    @Test("Given view rules naming node bank, when bank is decomposed, then they name group bank and keep the other names and the reach")
    func rulesNamingTheNodeNameTheGroup() throws {
        let s = try session(
            views: """
                vview v {
                  include node alice, bank downstream 1;
                  exclude node bank;
                }

                vview w {
                  include node bank;
                }
                """)

        try s.decompose("bank")

        let exported = try s.exportVGL()
        let v = viewBlock("v", in: exported)
        #expect(v.contains("include node alice downstream 1\n"), "\(v)")
        #expect(v.contains("include group bank downstream 1\n"), "\(v)")
        #expect(v.contains("exclude group bank\n"), "\(v)")
        #expect(!v.contains("node bank"), "\(v)")
        let w = viewBlock("w", in: exported)
        #expect(w.contains("include group bank\n"), "\(w)")
        #expect(!w.contains("node bank"), "\(w)")
    }

    @Test("Given view v shown, when bank is decomposed, then it is unfolded in v and folded in view w and in the default view")
    func unfoldedInTheActiveViewOnly() throws {
        let s = try session(views: "vview v {\n}\n\nvview w {\n}")
        try s.selectView("v")

        try s.decompose("bank")

        #expect(!s.isFolded("bank"))
        try s.selectView("w")
        #expect(s.isFolded("bank"))
        try s.selectView(nil)
        #expect(s.isFolded("bank"))
    }

    @Test("Given the default view shown, when bank is decomposed, then it is unfolded there and every declared view still shows it folded")
    func unfoldedInTheDefaultViewOnly() throws {
        let s = try session(views: "vview v {\n}\n\nvview w {\n}")

        try s.decompose("bank")

        #expect(!s.isFolded("bank"))
        try s.selectView("v")
        #expect(s.isFolded("bank"))
        try s.selectView("w")
        #expect(s.isFolded("bank"))
    }

    @Test(
        "Given the default view shown and a view unfolding every System, when bank is decomposed, then that view shows it unfolded, as it would any System"
    )
    func aViewThatUnfoldsTheTypeKeepsDoingSo() throws {
        // Another detailed System, so the view's value differs from the type's default and is kept.
        let s = try session(
            views: "vview open {\n  node type: System [isfolded: false];\n}",
            body: "  group mail: System \"Mail\" {\n    node smtp: Container \"SMTP\";\n  }")

        try s.decompose("bank")

        try s.selectView("open")
        #expect(!s.isFolded("bank"))
    }

    @Test(
        "Given no detailed System yet and a view unfolding every System, when bank is decomposed, then that view shows it unfolded and keeps saying so"
    )
    func aViewThatUnfoldsTheTypeBeforeAnyIsDetailed() throws {
        let s = try session(views: "vview open {\n  node type: System [isfolded: false];\n}")

        try s.decompose("bank")

        try s.selectView("open")
        #expect(!s.isFolded("bank"))
        #expect(viewBlock("open", in: try s.exportVGL()).contains("node type: System [isfolded: false]"))
    }

    @Test(
        "Given view closed shown, saying folded node type: System, when bank is decomposed, then bank is unfolded there and every other view and System is unchanged"
    )
    func decomposingUnderAFoldedTypeUnfoldsOnlyThatNode() throws {
        // `mail` unfolded in the model is what keeps the view's type value from being pruned.
        let s = try session(
            views: "vview closed {\n  folded node type: System;\n}\n\nvview w {\n}",
            body: "  group mail: System \"Mail\" {\n    isfolded: false;\n    node smtp: Container \"SMTP\";\n  }")
        try s.selectView("closed")

        try s.decompose("bank")

        #expect(!s.isFolded("bank"))
        #expect(s.isFolded("mail"))
        try s.selectView("w")
        #expect(s.isFolded("bank"))
        #expect(!s.isFolded("mail"))
        try s.selectView(nil)
        #expect(s.isFolded("bank"))
        #expect(!s.isFolded("mail"))

        let first = try s.exportVGL()
        #expect(viewBlock("closed", in: first).contains("folded node type: System"), "\(first)")
        let reparsed = try makeTestSession(vgl: first)
        #expect(try reparsed.exportVGL() == first)
        try reparsed.selectView("closed")
        #expect(!reparsed.isFolded("bank"))
        #expect(reparsed.isFolded("mail"))
    }

    private let namingViews = """
        vview v {
          include node alice, bank;
          node bank [fontsize: 16];
        }

        vview w {
          exclude node bank downstream 1;
        }
        """

    @Test("Given views naming bank, when bank is decomposed and undone, then the document and its views are exactly as before in one step")
    func oneUndoStep() throws {
        let s = try session(views: namingViews)
        try s.selectView("v")
        let before = try s.exportVGL()

        try s.decompose("bank")
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
    }

    @Test("Given views naming bank, from the default view and from a view, when decomposed and exported, then the export reparses to the same text")
    func theExportReparses() throws {
        for shown in [nil, "v", "w"] as [String?] {
            let s = try session(views: namingViews)
            try s.selectView(shown)

            try s.decompose("bank")
            let first = try s.exportVGL()
            let reparsed = try makeTestSession(vgl: first)

            #expect(try reparsed.exportVGL() == first, "shown: \(shown ?? "default")")
            #expect(first.contains("group bank [fontsize: 16"), "\(first)")
        }
    }
}
