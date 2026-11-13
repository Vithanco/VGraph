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
        #expect(try step(.decompose, on: "a") == .perform(.decompose(node: "a")))
        #expect(try step(.removeURL, on: "a") == .perform(.removeURL(element: "a")))
    }

    /// Neither changes the graph, but both are where the menu click ends: one
    /// in a new tab, the other in an [[Inline edit]] (ADR-0009).
    @Test func openURLAndRenameAreActionsToo() throws {
        #expect(try step(.openURL, on: "a") == .perform(.openURL(element: "a")))
        #expect(try step(.setLabel, on: "a") == .perform(.rename(element: "a")))
    }
}
