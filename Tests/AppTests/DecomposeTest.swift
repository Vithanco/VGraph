import Testing
import VGLanguage
import VGraph

@testable import App

/// Decompose turns a node into a detailed node with one detail per edge, so no
/// edge loses its end (ADR-0032).
struct DecomposeTest {
    private func session(_ body: String, extraTypes: String = "", views: String = "") throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container, Store)]
                  node type: Container [nodeStyle: roundedBox]
                  node type: Store [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                  edge type: systemToSystem from: System to: System
                \(extraTypes)}

                vgraph g: Arch "G" {
                  node alice: Person "Alice";
                \(body)
                }
                \(views)
                """)
    }

    private func members(of group: String, in s: TestSession) throws -> [Node] {
        try s.origin.groupStructure.getDirectContent(group: Group(rawValue: group)).1
    }

    @Test("Given a node with no edges, when decomposed, then it is a detailed node of the same id, type and label holding one detail")
    func aNodeWithNoEdgesGetsOneDetail() throws {
        let s = try session("  node bank: System \"Bank\";")

        try s.decompose("bank")

        let bank = Group(rawValue: "bank")
        #expect(!s.origin.has(node: Node("bank")))
        #expect(s.origin.nodeType(of: bank) == NodeType(string: "System"))
        let details = try members(of: "bank", in: s)
        try #require(details.count == 1)
        #expect(try s.origin.nodeType(for: details[0]) == NodeType(string: "Container"))
        let exported = try s.exportVGL()
        #expect(exported.contains("group bank: System \"Bank\""), "\(exported)")
        #expect(exported.contains("node \(details[0].id): Container \"\(Attributes.Node.placeholderLabel)\""), "\(exported)")
    }

    @Test("Given a node with two edges, when decomposed, then each edge ends at its own new detail and keeps its id, type, label and comment")
    func eachEdgeGetsItsOwnDetail() throws {
        let s = try session(
            """
              node bank: System "Bank";
              node mail: System "Mail";
              edge alice -> bank "logs in";
              // keep this note
              edge bank -> mail "pays";
            """)
        let before = s.origin.edges.map { $0.id.id }.sorted()

        try s.decompose("bank")

        #expect(s.origin.edges.map { $0.id.id }.sorted() == before)
        let details = try members(of: "bank", in: s)
        #expect(details.count == 2)
        let login = try #require(s.origin.edges.first { $0.from == Node("alice") })
        let payment = try #require(s.origin.edges.first { $0.to == Node("mail") })
        #expect(details.contains(login.to))
        #expect(details.contains(payment.from))
        #expect(login.to != payment.from)
        #expect(try s.origin.edgeType(for: login).id.id == "uses")
        #expect(try s.origin.edgeType(for: payment).id.id == "systemToSystem")
        let exported = try s.exportVGL()
        #expect(exported.contains("edge alice -> \(login.to.id) \"logs in\""), "\(exported)")
        #expect(exported.contains("// keep this note"), "\(exported)")
        #expect(exported.contains("edge \(payment.from.id) -> mail \"pays\""), "\(exported)")
    }

    @Test("Given a self-loop, when decomposed, then it runs between two new details and is retyped by R1")
    func aSelfLoopGetsTwoDetails() throws {
        let s = try session(
            "  node bank: System \"Bank\";\n  edge bank -> bank \"settles\";",
            extraTypes: "  edge type: containerToContainer from: Container to: Container\n")

        try s.decompose("bank")

        let details = try members(of: "bank", in: s)
        #expect(details.count == 2)
        let loop = try #require(s.origin.edges.first)
        #expect(loop.from != loop.to)
        #expect(details.contains(loop.from) && details.contains(loop.to))
        #expect(try s.origin.edgeType(for: loop).id.id == "containerToContainer")
        #expect(try s.exportVGL().contains("\"settles\""))
    }

    @Test("Given a self-loop and no type between details, when decomposed, then the edge is unknown-typed and nothing is refused")
    func noTypeBetweenDetailsMintsUnknown() throws {
        let s = try session("  node bank: System \"Bank\";\n  edge bank -> bank \"settles\";")

        try s.decompose("bank")

        let loop = try #require(s.origin.edges.first)
        #expect(try s.origin.edgeType(for: loop).id.id.hasPrefix(EdgeType.unknownPrefix))
    }

    @Test("Given an edge only one detail type keeps the type of, when decomposed, then the detail is of that type")
    func theDetailTypeKeepsTheEdgeTypeWhereItCan() throws {
        // Declared, so `uses` does not also gain Person → Container.
        let s = try session(
            "  node bank: System \"Bank\";\n  edge alice -> bank \"logs in\";",
            extraTypes: "  edge type: browses from: Person to: Container\n")

        try s.decompose("bank")

        let login = try #require(s.origin.edges.first)
        #expect(try s.origin.nodeType(for: login.to) == NodeType(string: "Store"))
        #expect(try s.origin.edgeType(for: login).id.id == "uses")
    }

    @Test("Given a node whose type has no detailing, when decompose is asked for, then it is not offered and is refused")
    func onlyTypesWithADetailing() throws {
        let s = try session("  node bank: System \"Bank\";\n  edge alice -> bank;")
        let before = try s.exportVGL()

        #expect(!s.canDecompose("alice"))
        #expect(s.canDecompose("bank"))
        #expect(throws: VError.self) { try s.decompose("alice") }
        #expect(throws: VError.self) { try s.decompose("nowhere") }
        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
    }

    @Test("Given a detailed node, when decompose is asked for, then it is not offered")
    func aDetailedNodeIsNotDecomposedAgain() throws {
        let s = try session("  group bank: System \"Bank\" {\n    node api: Container \"API\";\n  }")

        #expect(!s.canDecompose("bank"))
        #expect(throws: VError.self) { try s.decompose("bank") }
    }

    @Test("Given a decomposed node, when undone, then the document is exactly as before in one step")
    func oneUndoStep() throws {
        let s = try session(
            """
              node bank: System "Bank";
              node mail: System "Mail";
              edge alice -> bank "logs in";
              edge bank -> bank;
              edge bank -> mail "pays";
            """)
        let before = try s.exportVGL()

        try s.decompose("bank")
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
        #expect(!s.canUndo)
        #expect(s.origin.has(node: Node("bank")))
    }

    @Test("Given a node with its own values, in a group, when decomposed, then the detailed node keeps them, its group and its place")
    func theNodeKeepsItsValuesAndPlace() throws {
        let s = try session(
            """
              group bigBank "Big Bank" {
                node bank: System "Bank" [backgroundcolor: "#ffd27f"];
                group archive "Archive" {
                  node mail: System "Mail";
                }
              }
            """,
            views: """
                vview v {
                  node bank [fontsize: 16];
                }
                """)

        try s.decompose("bank")

        let bank = Group(rawValue: "bank")
        #expect(s.origin.parentGroup(of: bank) == Group(rawValue: "bigBank"))
        let exported = try s.exportVGL()
        #expect(exported.contains("group bank: System \"Bank\""), "\(exported)")
        #expect(exported.contains("backgroundcolor: \"#ffd27f\""), "\(exported)")
        let bankAt = try #require(exported.range(of: "group bank"))
        let archiveAt = try #require(exported.range(of: "group archive"))
        #expect(bankAt.lowerBound < archiveAt.lowerBound, "\(exported)")
        let inView = try s.origin.attributes(inView: "v", of: ItemKey(.group, "bank"))
        #expect(inView[Attributes.Node.fontsize.id] != nil)
    }

    @Test("Given a decomposed node, when exported and reparsed, then a second export is the same")
    func theResultRoundTrips() throws {
        let s = try session("  node bank: System \"Bank\";\n  edge alice -> bank \"logs in\";")

        try s.decompose("bank")
        let first = try s.exportVGL()
        let second = try makeTestSession(vgl: first).exportVGL()

        #expect(first == second)
    }
}
