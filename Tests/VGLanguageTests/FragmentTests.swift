//
//  FragmentTests.swift
//  VGraph
//
//  VGL fragments, the clipboard's format: the body of a document without its
//  header, and such text parsed into a document's context (Vithanco/VGraph-archive#112).
//

import Testing

@testable import VGLanguage
@testable import VGraph

/// One node type joined to itself, so every edge's type is inferred and no
/// `: type` clutters the expected text.
private let clipNotation = """
    vnotation Clip {
      node type: Thing [nodeStyle: roundedBox]
      edge type: leads_to from: Thing to: Thing
    }
    """

private func document(_ body: String) throws -> VGraph {
    try VGraphParser(logger: NoOpLogger()).parse(
        source: """
            \(clipNotation)
            vgraph doc: Clip "Doc" {
            \(body)
            }
            """)
}

private var fragments: VGLFragments<NoOpLogger> { VGLFragments(logger: NoOpLogger()) }

private func nodes(_ graph: VGraph) -> Set<String> { Set(graph.nodes.map { $0.id }) }
private func edges(_ graph: VGraph) -> Set<String> {
    Set(graph.edges.map { "\($0.from.id)->\($0.to.id)" })
}

@Suite("Fragment export")
struct FragmentExportTests {

    private let source = """
        // first
        node a: Thing "A";
        node b: Thing "B";
        node c: Thing "C";
        group g "G" {
          node d: Thing "D";
        }
        edge a -> b;
        edge b -> c;
        """

    @Test(
        "Given an excerpt of a → b, when exported, then the text is the two node statements and the edge statement, with no vgraph header"
    )
    func nodesAndEdgeWithoutHeader() throws {
        let excerpt = try document("node a: Thing \"A\";\nnode b: Thing \"B\";\nedge a -> b;").excerpt(of: ["a", "b"])

        #expect(
            try fragments.export(fragment: excerpt) == """
                node a: Thing "A"
                node b: Thing "B"
                edge a -> b

                """)
    }

    @Test("Given an excerpt of a document with its own vnotation, when exported, then no vnotation block is written")
    func noNotationBlock() throws {
        let excerpt = try document(source).excerpt(of: ["a"])

        #expect(!(try fragments.export(fragment: excerpt)).contains("vnotation"))
    }

    @Test("Given an excerpt holding g, when exported, then g's members are nested inside its group statement")
    func groupMembersNest() throws {
        let excerpt = try document(source).excerpt(of: ["g"])

        #expect(
            try fragments.export(fragment: excerpt) == """
                group g "G" {
                \tnode d: Thing "D"
                }

                """)
    }

    @Test("Given an excerpt with a commented node, when exported, then the comment stands above that node")
    func commentsTravel() throws {
        let excerpt = try document(source).excerpt(of: ["a"])

        #expect(try fragments.export(fragment: excerpt).contains("// first\nnode a: Thing \"A\""))
    }

    @Test(
        "Given a fragment with nodes, a group and edges, when parsed into an empty document of the same notation, then exporting that document's body gives the same fragment back"
    )
    func roundTrip() throws {
        let fragment = try fragments.export(fragment: try document(source).excerpt(of: ["a", "b", "c", "g"]))

        let pasted = try fragments.parse(fragment: fragment, into: try document(""), under: nil)

        #expect(try fragments.export(fragment: pasted.graph) == fragment)
    }
}

@Suite("Fragment parse in context")
struct FragmentParseTests {

    private func pasting(_ fragment: String, into body: String = "node a: Thing;\nnode b: Thing;\nedge a -> b;", under group: String? = nil)
        throws -> (graph: VGraph, pasted: [String])
    {
        try fragments.parse(
            fragment: fragment, into: try document(body), under: group.map { Group(rawValue: $0) })
    }

    @Test("Given a fragment declaring c, when parsed in, then c is added at the top level and a and b are unchanged")
    func aNewNodeJoinsTheTopLevel() throws {
        let result = try pasting("node c: Thing;").graph

        #expect(nodes(result) == ["a", "b", "c"])
        #expect(edges(result) == ["a->b"])
        #expect(result.group(of: Node("c")) == Group(rawValue: rootGroup))
    }

    @Test("Given a fragment declaring a, when parsed in, then the pasted node is named a_2")
    func aCollidingIdGetsASuffix() throws {
        #expect(nodes(try pasting("node a: Thing;").graph) == ["a", "b", "a_2"])
    }

    @Test("Given a document also holding a_2, when a fragment declaring a is parsed in, then the pasted node is named a_3")
    func aTakenSuffixIsSkipped() throws {
        let result = try pasting("node a: Thing;", into: "node a: Thing;\nnode a_2: Thing;").graph

        #expect(nodes(result) == ["a", "a_2", "a_3"])
    }

    @Test("Given a document with a node named g, when a fragment declaring group g is parsed in, then the group is named g_2")
    func nodesAndGroupsShareTheIds() throws {
        let result = try pasting("group g \"G\" {\n  node x: Thing;\n}", into: "node g: Thing;").graph

        #expect(result.has(group: Group(rawValue: "g_2")))
        #expect(result.group(of: Node("x")) == Group(rawValue: "g_2"))
    }

    @Test("Given a fragment declaring a and x with an edge a → x, when parsed in, then the edge joins a_2 to x")
    func anEdgeFollowsItsRenamedEnd() throws {
        let result = try pasting("node a: Thing;\nnode x: Thing;\nedge a -> x;").graph

        #expect(edges(result) == ["a->b", "a_2->x"])
    }

    @Test(
        "Given a fragment declaring b and c with an edge c → b, when parsed in, then the edge ends at the pasted b_2, not the document's b"
    )
    func theFragmentsOwnNodesWin() throws {
        let result = try pasting("node b: Thing;\nnode c: Thing;\nedge c -> b;").graph

        #expect(edges(result) == ["a->b", "c->b_2"])
    }

    @Test("Given a fragment declaring c with an edge c → b, when parsed in, then c is joined to the document's b")
    func anEdgeMayEndInTheDocument() throws {
        let result = try pasting("node c: Thing;\nedge c -> b;").graph

        #expect(edges(result) == ["a->b", "c->b"])
    }

    @Test(
        "Given a fragment with an edge a → b, when parsed in, then the document holds two edges from a node a to a node b, none lost to a shared id"
    )
    func pastedEdgesGetTheirOwnIds() throws {
        let result = try pasting("node a: Thing;\nnode b: Thing;\nedge a -> b;").graph

        #expect(edges(result) == ["a->b", "a_2->b_2"])
    }

    @Test("Given a fragment with an untyped edge, when parsed in, then its type is inferred from the pair, as in a document")
    func edgeTypesAreInferred() throws {
        let result = try pasting("node c: Thing;\nedge c -> a;").graph

        let edge = try #require(result.edges.first { $0.from.id == "c" })
        #expect(try result.edgeType(for: edge.id).id.id == "leads_to")
    }

    @Test("Given a fragment parsed in under group g, then its top-level elements are members of g")
    func aPasteUnderAGroupLandsInIt() throws {
        let result = try pasting("node c: Thing;", into: "group g \"G\" {\n  node a: Thing;\n}", under: "g").graph

        #expect(result.group(of: Node("c")) == Group(rawValue: "g"))
    }

    @Test("Given a fragment declaring a and c, when parsed in, then the pasted elements are reported as a_2 and c")
    func thePastedIdsAreReported() throws {
        #expect(try pasting("node a: Thing;\nnode c: Thing;").pasted == ["a_2", "c"])
    }

    @Test("Given a fragment with a node type the notation lacks, when parsed in, then the paste is refused, naming that type")
    func anUnknownNodeTypeIsRefused() throws {
        #expect(throws: VError.fragmentNamesUnknownTypes(["Actor"])) {
            try pasting("node c: Actor;")
        }
    }

    @Test("Given a fragment with an unknown group type and an unknown node type, when parsed in, then the refusal names both")
    func everyUnknownTypeIsNamed() throws {
        #expect(throws: VError.fragmentNamesUnknownTypes(["Actor", "Zone"])) {
            try pasting("group z: Zone \"Z\" {\n  node c: Actor;\n}")
        }
    }

    @Test("Given a fragment whose top level sets an attribute, when parsed in, then the paste is refused")
    func topLevelAttributesAreRefused() throws {
        #expect(throws: VError.parsingError("Syntax error: A pasted fragment holds elements, not attributes (line 2)")) {
            try pasting("node c: Thing;\nrankdir: LR;")
        }
    }

    @Test("Given text that is not VGL, when parsed in, then the paste is refused, with where the text went wrong")
    func notVGLIsRefusedWithItsLine() throws {
        #expect(throws: VError.parsingError("Syntax error: Expected ':' after node id (line 2)")) {
            try pasting("node c: Thing;\nnode d Thing;")
        }
    }
}
