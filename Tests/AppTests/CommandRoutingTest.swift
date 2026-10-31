//
//  CommandRoutingTest.swift
//  VGraph
//
//  Every menu command starts in `EditorCore.begin`, including the ones that ask
//  nothing. They used to be dispatched by a switch in the editor, where a
//  command the menu offered but the switch forgot was a click that silently did
//  nothing — reachable only by a browser test.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct CommandRoutingTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vgraph demo: ConceptMap "Demo" {
                  group g1 "Cluster" {
                    node a: Concept "A" [url: "https://example.com"];
                  }
                  node r: Relation "leads to";
                  edge a -> r;
                }
                """)
    }

    private func step(_ command: VCommandID, on target: String) throws -> ConversationStep {
        EditorCore.begin(command, on: target, forcingChoice: false, in: try session()).step
    }

    @Test func commandsThatAskNothingPerformAtOnce() throws {
        #expect(try step(.delete, on: "a") == .perform(.delete(element: "a")))
        #expect(try step(.toggleFolding, on: "g1") == .perform(.toggleFolding(group: "g1")))
        #expect(try step(.ungroup, on: "g1") == .perform(.ungroup(group: "g1")))
        #expect(try step(.removeURL, on: "a") == .perform(.removeURL(element: "a")))
    }

    /// Neither changes the graph, but both are where the menu click ends: one
    /// in a new tab, the other in an [[Inline edit]] (ADR-0009).
    @Test func openURLAndRenameAreActionsToo() throws {
        #expect(try step(.openURL, on: "a") == .perform(.openURL(element: "a")))
        #expect(try step(.setLabel, on: "a") == .perform(.rename(element: "a")))
    }

    /// An enabled row that begins nothing is the bug this routing exists to
    /// prevent, so it is checked over everything the menu offers.
    @Test func noEnabledMenuRowBeginsWithNothing() throws {
        let probe = try session()
        var ids: [String] = [probe.rootGroupId()]
        for node in probe.origin.nodes { ids.append(node.id) }
        for edge in probe.origin.edges { ids.append(edge.id.id) }
        for group in probe.origin.groups { ids.append(group.id.id) }

        var silent: [String] = []
        for id in ids {
            for row in EditorCore.menu(for: id, in: probe, notationBreak: .forbidden) where row.enabled {
                let begun = EditorCore.begin(row.id, on: id, forcingChoice: false, in: try session())
                if begun.step == .dismiss { silent.append("\(row.id.raw) on \(id)") }
            }
        }
        #expect(silent.isEmpty, "enabled but begins nothing: \(silent)")
    }
}
