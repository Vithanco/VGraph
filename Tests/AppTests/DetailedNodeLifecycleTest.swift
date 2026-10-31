// A detailed node is a node that has details, not a separate state: with its
// last detail gone it is a plain node again (ADR-0032).

import EditorCore
import Testing
import VGraph

@testable import App

struct DetailedNodeLifecycleTest {

    let vgl = """
        vgraph arch: C4 "Architecture" {
          node customer: Person "Customer";
          group ibs: SoftwareSystem "Internet Banking System" {
            node web: Container "Web App";
          }
        }
        """

    @Test func deletingTheLastDetailLeavesANodeOfTheSameIdAndType() throws {
        let s = try makeTestSession(vgl: vgl)

        try s.delete("web")

        #expect(!s.origin.has(group: Group(rawValue: "ibs")))
        #expect(s.origin.has(node: Node("ibs")))
        #expect(try s.origin.nodeType(for: Node("ibs")) == Notations.C4.NodeTypes.softwareSystem)
    }

    @Test func theNodeKeepsItsPlaceInTheDocument() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph arch: C4 "Architecture" {
                  node customer: Person "Customer";
                  group ibs: SoftwareSystem "Internet Banking System" {
                    node web: Container "Web App";
                  }
                  node mainframe: SoftwareSystem "Mainframe";
                }
                """)

        try s.delete("web")

        let vgl = try s.exportVGL()
        let ibs = try #require(vgl.range(of: "node ibs: SoftwareSystem"))
        let mainframe = try #require(vgl.range(of: "node mainframe"))
        #expect(ibs.lowerBound < mainframe.lowerBound)
    }

    @Test func aViewNamingTheDetailedNodeNamesTheNode() throws {
        let s = try makeTestSession(
            vgl: vgl + """


                vview v {
                  include group ibs;
                }
                """)

        try s.delete("web")

        let vgl = try s.exportVGL()
        #expect(vgl.contains("include node ibs"))
        #expect(!vgl.contains("group ibs"))
    }

    @Test func aViewListingItBesideGroupsNamesItAsANodeOnItsOwn() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph arch: C4 "Architecture" {
                  group ibs: SoftwareSystem "Internet Banking System" {
                    node web: Container "Web App";
                  }
                  group bank "Big Bank" {
                    node customer: Person "Customer";
                  }
                }

                vview v {
                  include group bank, ibs downstream 1;
                }
                """)

        try s.delete("web")

        let vgl = try s.exportVGL()
        #expect(vgl.contains("include group bank downstream 1"))
        #expect(vgl.contains("include node ibs downstream 1"))
    }

    @Test func theNodeKeepsItsLabel() throws {
        let s = try makeTestSession(vgl: vgl)

        try s.delete("web")
        let exported = try s.exportVGL()

        #expect(exported.contains("node ibs: SoftwareSystem \"Internet Banking System\""))
    }

    @Test func ungroupIsNotOfferedOnADetailedNode() throws {
        let s = try makeTestSession(vgl: vgl)

        let row = try #require(menu(for: "ibs", in: s).first { $0.id == .ungroup })

        #expect(row.availability == .notApplicable)
        #expect(!row.enabled)
        #expect(!menu(for: "ibs", in: s, notationBreak: .permitted).contains { $0.id == .ungroup && $0.enabled })
    }

    @Test func ungroupingADetailedNodeIsRefused() throws {
        let s = try makeTestSession(vgl: vgl)
        let before = try s.exportVGL()

        #expect(throws: VError.self) { try s.ungroup("ibs") }
        #expect(try s.exportVGL() == before)
    }

    @Test func aPlainGroupStillOffersUngroup() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "G1" {
                    node c: Concept "C";
                  }
                }
                """)

        let row = try #require(menu(for: "g1", in: s).first { $0.id == .ungroup })

        #expect(row.enabled)
    }

    @Test func undoRestoresTheDetailedNode() throws {
        let s = try makeTestSession(vgl: vgl)
        let before = try s.exportVGL()

        try s.delete("web")
        _ = try s.undo()

        #expect(try s.exportVGL() == before)
        #expect(s.origin.nodeType(of: Group(rawValue: "ibs")) == Notations.C4.NodeTypes.softwareSystem)
    }
}
