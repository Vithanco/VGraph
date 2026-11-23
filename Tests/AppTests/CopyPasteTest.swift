// Copy and paste as VGL: what the session adds — history, refusal, and where a
// paste lands (Vithanco/VGraph-archive#112).

import Testing
import VGraph

@testable import App

struct CopyPasteTest {
    ///     root ── a → b
    ///          └─ g (empty)
    private func session(folded: Bool = false, views: String = "") throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  node a: Concept "A";
                  node b: Relation "B";
                  edge a -> b;
                  \(folded ? "folded " : "")group g "G" {
                  }
                }
                \(views)
                """)
    }

    private func edges(_ graph: VGraph) -> Set<String> {
        Set(graph.edges.map { "\($0.from.id)->\($0.to.id)" })
    }

    @Test("Given an active view that hides b, when a and b are copied, then b is in the copy")
    func aCopyReadsTheModelNotTheView() throws {
        let s = try session(views: "vview v \"V\" {\n  exclude node b;\n}")
        try s.selectView("v")

        #expect(try s.vglFragment(of: ["a", "b"]).contains("node b: Relation"))
    }

    @Test("Given nothing selected, when copying, then the copy is refused")
    func copyingNothingIsRefused() throws {
        let s = try session()

        #expect(throws: VError.commandUnavailable(.copy, target: "")) {
            try s.vglFragment(of: [])
        }
    }

    @Test("Given a and b copied and pasted back, then the document holds a_2 → b_2 beside a → b")
    func pastingBackDuplicates() throws {
        let s = try session()

        try s.paste(fragment: try s.vglFragment(of: ["a", "b"]), into: nil)

        #expect(edges(s.origin) == ["a->b", "a_2->b_2"])
    }

    @Test("Given a paste, when undone once, then the document is as it was before the paste")
    func aPasteIsOneUndoStep() throws {
        let s = try session()
        let before = try s.exportVGL()

        try s.paste(fragment: try s.vglFragment(of: ["a", "b"]), into: nil)
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
    }

    @Test("Given a paste refused for an unknown type, then the document and its history are unchanged")
    func aRefusedPasteLeavesNoTrace() throws {
        let s = try session()
        let before = try s.exportVGL()

        #expect(throws: VError.fragmentNamesUnknownTypes(["Actor"])) {
            try s.paste(fragment: "node c: Actor;", into: nil)
        }

        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
    }

    @Test("Given an empty clipboard, when pasting, then the paste is refused")
    func pastingNothingIsRefused() throws {
        let s = try session()

        #expect(throws: VError.commandUnavailable(.paste, target: "")) {
            try s.paste(fragment: "", into: nil)
        }
    }

    @Test("Given a paste into a folded g, then g stays folded")
    func aFoldedDestinationStaysFolded() throws {
        let s = try session(folded: true)

        try s.paste(fragment: "node c: Concept \"C\";", into: "g")

        #expect(s.isFolded("g"))
    }

    @Test("Given a copy from one document, when pasted into another document of the same notation, then it appears there")
    func pastingIntoAnotherDocument() throws {
        let other = try makeTestSession(
            vgl: """
                vgraph other: ConceptMap "Other" {
                  node z: Concept "Z";
                }
                """)

        try other.paste(fragment: try session().vglFragment(of: ["a", "b"]), into: nil)

        #expect(edges(other.origin) == ["a->b"])
    }

    @Test(
        "Given a copy from a document with its own vnotation, when pasted into another document with the same vnotation, then its types are kept"
    )
    func customTypesSurviveTheTrip() throws {
        func riskMap(_ body: String) throws -> TestSession {
            try makeTestSession(vgl: "\(riskMapNotation)\nvgraph risks: RiskMap \"Risks\" {\n\(body)\n}")
        }
        let source = try riskMap("node r: Risk \"R\";")
        let target = try riskMap("node c: Control \"C\";")

        try target.paste(fragment: try source.vglFragment(of: ["r"]), into: nil)

        #expect(target.nodeType(of: "r")?.id == "Risk")
    }

    // MARK: - The containment check (ADR-0032)

    ///     root ── p (Person)
    ///          └─ s (System) ── c1, c2, c3 (Container)
    private func architecture() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container)]
                  node type: Container [nodeStyle: roundedBox]
                  node type: Person [nodeStyle: roundedBox]
                }
                vgraph arch: Arch "Arch" {
                  node p: Person "P";
                  group s: System "S" {
                    node c1: Container "C1";
                    node c2: Container "C2";
                    node c3: Container "C3";
                  }
                }
                """)
    }

    @Test("Given two Containers copied out of s, when pasted at the top level, then the paste is refused by the containment check")
    func detailsMayNotStandAtTheTopLevel() throws {
        let s = try architecture()
        let copy = try s.vglFragment(of: ["c1", "c2"])

        #expect(throws: VError.commandOptionNotOffered(.paste, target: s.rootGroupId(), option: "Container")) {
            try s.paste(fragment: copy, into: nil)
        }
    }

    @Test("Given two Containers copied out of s, when pasted into s, then they become its details")
    func detailsPasteIntoTheirHolder() throws {
        let s = try architecture()

        let pasted = try s.paste(fragment: try s.vglFragment(of: ["c1", "c2"]), into: "s")

        #expect(pasted.map { s.origin.group(of: Node(rawValue: $0)) } == [Group(rawValue: "s"), Group(rawValue: "s")])
    }

    @Test("Given a System holding a Person pasted at the top level, then the paste is refused by the containment check")
    func whatArrivesInsideIsCheckedToo() throws {
        let s = try architecture()

        #expect(throws: VError.commandOptionNotOffered(.paste, target: "t", option: "Person")) {
            try s.paste(fragment: "group t: System \"T\" {\n  node q: Person \"Q\";\n}", into: nil)
        }
    }

    @Test("Given a detailed node selected, when copied and pasted, then its details come with it")
    func aDetailedNodeTravelsWithItsDetails() throws {
        let s = try architecture()

        try s.paste(fragment: try s.vglFragment(of: ["s"]), into: nil)

        #expect(
            ["c1_2", "c2_2", "c3_2"].map { s.origin.group(of: Node(rawValue: $0)) }
                == Array(repeating: Group(rawValue: "s_2"), count: 3))
    }

    @Test("Given a Person copied, when pasted into s, then the paste is refused by the containment check")
    func aHolderTakesOnlyItsDetailTypes() throws {
        let s = try architecture()
        let copy = try s.vglFragment(of: ["p"])

        #expect(throws: VError.commandOptionNotOffered(.paste, target: "s", option: "Person")) {
            try s.paste(fragment: copy, into: "s")
        }
    }
}
