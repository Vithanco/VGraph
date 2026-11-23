//
//  ExcerptTests.swift
//  VGraph
//
//  What a copy contains (Vithanco/VGraph-archive#112).
//

import Testing
import VGLanguage

@testable import VGraph

@Suite("VGraph.excerpt(of:)")
struct ExcerptTests {

    ///     root ── a → b → c
    ///          └─ g ── d → e
    ///                └─ h ── f
    private func graph(folded: Bool = false) throws -> VGraph {
        let vgl = """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A";
              node b: Concept "B";
              node c: Concept "C";
              \(folded ? "folded " : "")group g "G" {
                node d: Concept "D";
                node e: Concept "E";
                group h "H" {
                  node f: Concept "F";
                }
                edge d -> e;
              }
              edge a -> b;
              edge b -> c;
            }
            """
        return try VGraphParser(logger: NoOpLogger()).parse(source: vgl)
    }

    private func nodes(_ graph: VGraph) -> Set<String> { Set(graph.nodes.map { $0.id }) }
    private func groups(_ graph: VGraph) -> Set<String> { Set(graph.groups.map { $0.id.id }) }
    private func edges(_ graph: VGraph) -> Set<String> {
        Set(graph.edges.map { "\($0.from.id)->\($0.to.id)" })
    }

    @Test("Given a and b selected, when excerpted, then a, b and the edge a → b are in it")
    func theSelectedNodesAndTheirEdge() throws {
        let excerpt = try graph().excerpt(of: ["a", "b"])

        #expect(nodes(excerpt) == ["a", "b"])
        #expect(edges(excerpt).contains("a->b"))
    }

    @Test("Given a and b selected, when excerpted, then the edge b → c to the unselected c is not")
    func anEdgeLeavingTheSelectionIsLeftOut() throws {
        let excerpt = try graph().excerpt(of: ["a", "b"])

        #expect(edges(excerpt) == ["a->b"])
    }

    @Test("Given g selected, when excerpted, then d, e, h and f are in it, at their depths")
    func aGroupTakesItsContents() throws {
        let excerpt = try graph().excerpt(of: ["g"])

        #expect(nodes(excerpt) == ["d", "e", "f"])
        #expect(excerpt.group(of: Node("d")) == Group(rawValue: "g"))
        #expect(excerpt.parentGroup(of: Group(rawValue: "h")) == Group(rawValue: "g"))
        #expect(excerpt.group(of: Node("f")) == Group(rawValue: "h"))
    }

    @Test("Given d, e and h selected, when excerpted, then g is in it, since its members promote it")
    func membersPromoteTheirGroup() throws {
        let excerpt = try graph().excerpt(of: ["d", "e", "h"])

        #expect(groups(excerpt) == ["g", "h"])
    }

    @Test("Given only d selected, when excerpted, then d stands at the top level, without g")
    func aMemberComesWithoutItsGroup() throws {
        let excerpt = try graph().excerpt(of: ["d"])

        #expect(groups(excerpt).isEmpty)
        #expect(excerpt.group(of: Node("d")) == Group.root)
    }

    @Test("Given a folded g selected, when excerpted, then g is folded in the excerpt")
    func foldStateTravels() throws {
        let excerpt = try graph(folded: true).excerpt(of: ["g"])

        #expect(try excerpt.get(group: Group(rawValue: "g"), attribute: Attributes.Group.isFolded))
    }

    @Test("Given a document with a view, when excerpted, then the excerpt has no views")
    func viewsStayBehind() throws {
        let withView = try graph().declaring(view: ViewDeclaration(name: "v", label: "V"))

        let excerpt = try withView.excerpt(of: ["a"])

        #expect(excerpt.views.isEmpty)
    }

    @Test(
        "Given a document with a label, a leading comment and a root attribute, when excerpted, then the excerpt has none of them"
    )
    func theDocumentsOwnSettingsStayBehind() throws {
        let vgl = """
            // About the whole thing
            vgraph demo: ConceptMap "Demo" {
              rankdir: LR;
              node a: Concept "A";
            }
            """
        let source = try VGraphParser(logger: NoOpLogger()).parse(source: vgl)

        let excerpt = try source.excerpt(of: ["a"])

        let root = try excerpt.attributes(in: .model, of: .root)
        #expect(root[Attributes.Group.label.id] == nil)
        #expect(root[Attributes.Group.comment.id] == nil)
        #expect(root[Attributes.Group.layoutDirection.id] == nil)
    }
}
