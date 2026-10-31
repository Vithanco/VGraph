//
//  MenuAgreesWithExecutionTest.swift
//  VGraph
//
//  The menu and the thing that runs must never disagree.
//
//  This is the invariant phase 6 puts at risk. Menu construction is migrating
//  into `EditorCore` and execution into named methods on the port; they used to
//  be two views of one registry entry and are becoming two separate pieces of
//  code. Nothing else would notice them drifting — a command offered but not
//  runnable is a click that silently does nothing, and a command greyed but
//  runnable is a feature nobody can reach.
//
//  Every check runs on a fresh session, because a command that applies mutates
//  and a previous one must not skew the next.
//

import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

struct MenuAgreesWithExecutionTest {
    /// Deliberately varied: a grouped node, an edge the notation likes, a
    /// terminal node type, an edge that may not be reversed, and a pair with two
    /// edge types between them.
    private let fixtures: [(name: String, vgl: String)] = [
        (
            "ConceptMap",
            """
            vgraph demo: ConceptMap "Demo" {
              group g1 "Cluster" {
                node a: Concept "A";
              }
              node r: Relation "leads to";
              edge a -> r;
            }
            """
        ),
        (
            "DecisionTree",
            """
            vgraph dt: DecisionTree "Demo" {
              node c: Choice "Pick";
              node o: Outcome "Done";
              edge c -> o;
            }
            """
        ),
        (
            "GoalTree",
            """
            vgraph gt: GoalTree "Demo" {
              node g: Goal "Win";
              node cs: CriticalSuccessFactor "Ship";
              node n: NecessaryCondition "Test";
              edge cs -> g;
              edge n -> cs;
            }
            """
        ),
        (
            "CLD",
            """
            vgraph cld: CLD "Demo" {
              node s1: Stock "Price";
              node s2: Stock "Demand";
              edge s1 -> s2: same;
            }
            """
        ),
        (
            "Detailing",
            """
            vnotation Arch {
              node type: Person [nodeStyle: roundedBox]
              node type: System [nodeStyle: roundedBox, detailedBy: (Container, Store)]
              node type: Container [nodeStyle: roundedBox]
              node type: Store [nodeStyle: roundedBox]
              edge type: uses from: Person to: System
            }

            vgraph g: Arch "G" {
              node alice: Person "Alice";
              node bank: System "Bank";
              group core: System "Core" {
                node api: Container "API";
              }
              edge alice -> bank;
            }
            """
        ),
        (
            "WithURL",
            """
            vgraph demo: ConceptMap "Demo" {
              node a: Concept "A" [url: "https://example.com"];
              node r: Relation "leads to";
            }
            """
        ),
    ]

    /// Did it run, rather than throw?
    ///
    /// Not `(try? call()) != nil`: `try?` flattens, so for a method returning an
    /// optional — `setLabel`, `addSuccessor` — that cannot tell "threw" from
    /// "succeeded and had nothing to return".
    private func didRun(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            return false
        }
    }

    /// Every addressable element: nodes, edges and groups alike — including the
    /// [[Root group]], which `origin.groups` filters out of the *public* list but
    /// which a click on blank canvas resolves to. It is where the menu and the
    /// commands are least alike (one live row out of seven), so it is the last
    /// place this invariant should be blind (ADR-0016).
    private func elementIds(_ session: TestSession) -> [String] {
        var ids: [String] = [session.rootGroupId()]
        for node in session.origin.nodes { ids.append(node.id) }
        for edge in session.origin.edges { ids.append(edge.id.id) }
        for group in session.origin.groups { ids.append(group.id.id) }
        return ids
    }

    /// The invariant, over every command × every element of five fixtures: a
    /// named method must refuse exactly when the menu greys its entry.
    ///
    /// This used to run twice — once through `attempt` and once through the
    /// named methods. The generic path is gone, so this is the whole check now,
    /// and the `continue`s below are where a command needs an argument only the
    /// editor's picker can supply. Those are covered by their own suites.
    @Test func namedCommandsRefuseExactlyWhenTheMenuGreysThem() throws {
        var mismatches: [String] = []

        for (name, vgl) in fixtures {
            let probe = try makeTestSession(vgl: vgl)

            for elementId in elementIds(probe) {
                for entry in EditorCore.menu(for: elementId, in: probe, notationBreak: .forbidden) {
                    let session = try makeTestSession(vgl: vgl)
                    var ran = true

                    switch entry.id {
                    case .toggleFolding:
                        ran = didRun { try session.toggleFolding(of: elementId) }
                    case .loopMarkers:
                        ran = didRun { try session.setLoopMarkers(.independent) }
                    case .delete:
                        ran = didRun { try session.delete(elementId) }
                    case .decompose:
                        ran = didRun { try session.decompose(elementId) }
                    case .removeURL:
                        ran = didRun { try session.removeURL(from: elementId) }
                    case .setLabel:
                        ran = didRun { _ = try session.setLabel(of: elementId, to: "x") }
                    case .setURL:
                        ran = didRun { try session.setURL(of: elementId, to: "https://example.com") }
                    case .addNode:
                        // Driven the way the editor will: ask for the options,
                        // and fall back to the only type when there is no
                        // question to put.
                        let options = EditorCore.addNodeOptions(on: elementId, in: session)
                        let chosen = options.first.map { NodeType(string: $0.id) }
                        guard let type = chosen ?? session.nodeTypes(placeableIn: elementId).first else { continue }
                        ran = didRun { _ = try session.addNode(in: elementId, ofType: type) }
                    case .addSuccessor, .addPredecessor:
                        // The editor always shows a list here — the break entry
                        // is unconditional — so drive it the way the editor
                        // would, through the first real option.
                        let outgoing = entry.id == .addSuccessor
                        let options = EditorCore.relatedOptions(
                            from: elementId, outgoing: outgoing, in: session)
                        guard let real = options.first(where: { !$0.isBreak }) else {
                            continue  // only the break on offer; ⌥ is the way in
                        }
                        let edge = EdgeType.Id(string: real.id)
                        ran = didRun {
                            if outgoing {
                                _ = try session.addSuccessor(from: elementId, using: edge)
                            } else {
                                _ = try session.addPredecessor(to: elementId, using: edge)
                            }
                        }
                    case .split:
                        // As the editor does it: ask whether there is a question,
                        // and answer it from what is offered.
                        let options = EditorCore.splitOptions(
                            for: elementId, notationBreak: .forbidden, in: session)
                        if let real = options.first(where: { !$0.isBreak }) {
                            var candidate: VSplitCandidate? = nil
                            for c in session.splitCandidates(for: elementId) where c.id == real.id {
                                candidate = c
                            }
                            guard let candidate else { continue }
                            ran = didRun { _ = try session.split(elementId, with: candidate) }
                        } else {
                            guard let only = session.splitCandidates(for: elementId).first else {
                                continue  // nothing to insert; ⌥ is the way in
                            }
                            ran = didRun { _ = try session.split(elementId, with: only) }
                        }
                    case .changeType:
                        // A group answers from a different list and takes a
                        // different argument, so drive it the way the editor
                        // does rather than skipping it — the node query returns
                        // nothing for a group, which is how this arm used to
                        // pass a menu item that did nothing.
                        if session.kind(of: elementId) == .group, session.nodeType(of: elementId) == nil {
                            let options = EditorCore.groupRetypeOptions(for: elementId, in: session)
                            guard let first = options.first else {
                                continue  // no boundary kinds; the item is greyed
                            }
                            let to: GroupType? =
                                first.id == EditorCore.plainGroupOption.id
                                ? nil : GroupType(string: first.id)
                            ran = didRun { try session.changeType(of: elementId, to: to) }
                        } else if session.kind(of: elementId) == .edge {
                            // As the editor does it: ask whether there is a
                            // question, and answer it from what is offered.
                            let options = EditorCore.edgeRetypeOptions(for: elementId, in: session)
                            if let first = options.first {
                                ran = didRun {
                                    try session.changeType(
                                        of: elementId, using: EdgeType.Id(string: first.id))
                                }
                            } else {
                                guard !session.retypeCandidates(edge: elementId).isEmpty else {
                                    continue  // nothing to become, and no break to reach
                                }
                                ran = didRun { try session.changeType(of: elementId, using: nil) }
                            }
                        } else {
                            guard let to = session.retypeCandidates(for: elementId).first else {
                                continue  // nothing to become; ⌥ is the way in
                            }
                            ran = didRun { try session.changeType(of: elementId, to: to) }
                        }
                    case .openURL:
                        // A query, not a command — "enabled" means it yields a link.
                        ran = session.urlToOpen(of: elementId) != nil
                    case .changeDirection:
                        // As the editor does it: ask EditorCore whether there is
                        // a question, and answer it if so. Passing `nil` blindly
                        // fails on a CLD edge, where two reversals exist and the
                        // command is right to insist on one.
                        let options = EditorCore.reversalOptions(for: elementId, in: session)
                        if let first = options.first {
                            ran = didRun {
                                try session.changeDirection(
                                    of: elementId, to: EdgeType.Id(string: first.id))
                            }
                        } else {
                            ran = didRun { try session.changeDirection(of: elementId, to: nil) }
                        }
                    default:
                        // The rest need an argument chosen from a picker, and
                        // driving that here would re-implement the editor rather
                        // than check it. TypedCommandsTest covers them against
                        // the generic path instead.
                        continue
                    }

                    if ran != entry.enabled {
                        mismatches.append(
                            "\(name)/\(elementId)/\(entry.id.raw): menu says "
                                + "\(entry.enabled ? "enabled" : "greyed"), method "
                                + "\(ran ? "ran" : "refused")")
                    }
                }
            }
        }

        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    /// `openURL` is the odd one: it is a query now, and the menu greys it for a
    /// link that is stored but not safe to follow. So "enabled" must mean
    /// "`urlToOpen` gives something", not merely "a URL exists".
    @Test func openURLIsOfferedExactlyWhenThereIsSomethingToOpen() throws {
        for (name, vgl) in fixtures {
            let session = try makeTestSession(vgl: vgl)
            for elementId in elementIds(session) {
                guard
                    let entry = EditorCore.menu(for: elementId, in: session, notationBreak: .forbidden)
                        .first(where: { $0.id == .openURL })
                else { continue }

                #expect(
                    entry.enabled == (session.urlToOpen(of: elementId) != nil),
                    "\(name)/\(elementId): menu and urlToOpen disagree")
            }
        }
    }
}
