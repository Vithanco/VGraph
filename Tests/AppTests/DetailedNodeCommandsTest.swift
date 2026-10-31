// The element commands reach a detailed node as they reach a node.

import Testing
import VGLanguage
import VGraph

@testable import App

struct DetailedNodeCommandsTest {
    let vgl = """
        vgraph arch: C4 "Architecture" {
            node customer: Person "Customer";
            group ibs: SoftwareSystem "Internet Banking System" {
                node web: Container "Web App";
            }
            edge customer -> web "uses";
        }
        """

    @Test func setLabelRenamesADetailedNode() throws {
        let s = try makeTestSession(vgl: vgl)

        try s.setLabel(of: "ibs", to: "Online Banking")

        #expect(try s.exportVGL().contains("group ibs: SoftwareSystem \"Online Banking\" {"))
        #expect(s.origin.label(of: .group(Group(rawValue: "ibs"))) == "Online Banking")
    }

    @Test func setURLLinksADetailedNode() throws {
        let s = try makeTestSession(vgl: vgl)

        try s.setURL(of: "ibs", to: "https://bank.example")

        #expect(s.storedURL(of: "ibs") == "https://bank.example")
        let exported = try s.exportVGL()
        try s.replaceDocument(vgl: exported)
        #expect(s.storedURL(of: "ibs") == "https://bank.example")
    }

    /// As for a node: a type that shows no text of its own has nothing to rename.
    @Test func aDetailedNodeWhoseTypeShowsNoTextCannotBeRenamed() throws {
        let s = try makeTestSession(
            vgl: """
                vgraph crt: CRT "Demo" {
                  group j: AndJunctor "and" {
                    node u: UndesirableEffect "Sales are falling";
                  }
                }
                """)

        #expect(s.canRename("j") == false)
        #expect(throws: VError.self) { try s.setLabel(of: "j", to: "nope") }
    }
}
