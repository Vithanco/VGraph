// Folded, a detailed node looks like any node of its type (ADR-0032), so only
// the editor tells the reader there is more inside.

import EditorCore
import Testing
import VGraph

@testable import App

struct DetailsMarkerTest {

    let vgl = """
        vgraph arch: C4 "Architecture" {
          node customer: Person "Customer";
          group ibs: SoftwareSystem "Internet Banking System" {
            node web: Container "Web App";
          }
          group mainframe: SoftwareSystem "Mainframe" {
            node api: Container "API";
            node batch: Container "Batch";
            group db: Container "Ledger" {
              node ledger: Component "Ledger";
            }
          }
          group bank "Big Bank" {
            node teller: Person "Teller";
          }
        }
        """

    private func session(folding ids: [String] = [], unfolding unfolded: [String] = []) throws -> TestSession {
        let s = try makeTestSession(vgl: vgl)
        for id in ids where !s.isFolded(id) { try s.toggleFolding(of: id) }
        for id in unfolded where s.isFolded(id) { try s.toggleFolding(of: id) }
        return s
    }

    @Test func aFoldedDetailedNodeIsMarkedWithItsDetailCount() throws {
        let s = try session(folding: ["ibs"])

        #expect(detailsMarker("ibs", in: s) == "+1")
    }

    /// What unfolding would reveal: a nested detailed node is one detail, however
    /// much it holds.
    @Test func theCountIsTheDirectDetails() throws {
        let s = try session(folding: ["mainframe"])

        #expect(detailsMarker("mainframe", in: s) == "+3")
    }

    @Test func anUnfoldedDetailedNodeShowsItsDetailsAndIsNotMarked() throws {
        let s = try session(unfolding: ["ibs"])

        #expect(detailsMarker("ibs", in: s) == nil)
    }

    @Test func aFoldedPlainGroupIsNotMarked() throws {
        let s = try session(folding: ["bank"])

        #expect(detailsMarker("bank", in: s) == nil)
    }

    @Test func aPlainNodeIsNotMarked() throws {
        let s = try session()

        #expect(detailsMarker("customer", in: s) == nil)
        #expect(detailsMarker("nowhere", in: s) == nil)
    }
}
