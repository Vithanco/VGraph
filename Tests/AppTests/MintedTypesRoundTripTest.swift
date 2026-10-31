//
//  MintedTypesRoundTripTest.swift
//  VGraph
//
//  The guard rail behind ADR-0024: whatever a command writes, the parser must
//  read back.
//
//  This is the property the editor broke for as long as unknown edge types have
//  existed. `EdgeType.unknown` built an id containing `:` and `->`, the exporter
//  names a type wherever a declared one also joins the pair, and the parser then
//  refused the document — costing the whole diagram on reopening, from a command
//  that looked like it had worked. No test held the property, because the two
//  browser specs that touched it asserted the broken string as *expected output*.
//
//  One loop over every command that can mint, rather than a case each: a seventh
//  mint site added later is caught by the same test only if the test enumerates
//  the commands in one place.
//

import Testing
import VGLanguage
import VGraph

@testable import App

struct MintedTypesRoundTripTest {
    /// Step → Gate is the only relationship declared, so Step → Step, the
    /// reversal Gate → Step, and a retyped endpoint all leave the notation with
    /// nothing to offer — which is what makes each command mint.
    private func flow() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Flow {
                  node type: Step [nodeStyle: roundedBox, color: "#3366cc"]
                  node type: Gate [nodeStyle: roundedBox, color: "#cc3366"]
                  edge type: next from: Step to: Gate
                }

                vgraph f: Flow "Demo" {
                  node s1: Step "One";
                  node g1: Gate "Gate";
                  edge s1 -> g1;
                }
                """)
    }

    private let step = NodeType(string: "Step")

    /// Run a minting command, then put its own export back through the parser.
    private func survivesAReparse(
        _ name: String, _ mint: (TestSession) throws -> Void
    ) throws -> String? {
        let s = try flow()
        try mint(s)

        // It minted, or the case is not exercising what it claims to.
        guard !GenericQualityChecks.unknownEdgeTypes(graph: s.origin).isEmpty else {
            return "\(name): minted nothing, so it proves nothing"
        }

        let exported = try s.exportVGL()
        do {
            try s.replaceDocument(vgl: exported)
        } catch {
            return "\(name): its own export does not parse — \(error)\n\(exported)"
        }
        return nil
    }

    @Test("Every command that can mint writes a document the parser reads back")
    func mintedTypesSurviveTheirOwnExport() throws {
        var failures: [String] = []

        failures.append(
            contentsOf: [
                try survivesAReparse("addSuccessor(ofType:)") { s in
                    _ = try s.addSuccessor(from: "s1", ofType: self.step)
                },
                try survivesAReparse("addPredecessor(ofType:)") { s in
                    _ = try s.addPredecessor(to: "g1", ofType: NodeType(string: "Gate"))
                },
                try survivesAReparse("split(_:ofType:)") { s in
                    _ = try s.split(s.origin.edges.first!.id.id, ofType: self.step)
                },
                try survivesAReparse("changeDirection(notationBreak:)") { s in
                    try s.changeDirection(
                        of: s.origin.edges.first!.id.id, to: nil, notationBreak: .permitted)
                },
                try survivesAReparse("changeType(node:notationBreak:)") { s in
                    try s.changeType(of: "g1", to: self.step, notationBreak: .permitted)
                },
            ].compactMap { $0 })

        #expect(failures.isEmpty, "\(failures)")
    }

    /// The shape the id has to keep. A colon or an arrow in it is what made the
    /// export unreadable, and nothing but this test says so.
    @Test("A minted edge type's id lexes as a VGL identifier")
    func theMintedIdIsAnIdentifier() throws {
        let s = try flow()
        _ = try s.addSuccessor(from: "s1", ofType: step)

        let minted = s.origin.edgeTypes.map { $0.id.id }
            .filter { $0.hasPrefix(EdgeType.unknownPrefix) }
        #expect(!minted.isEmpty)
        for id in minted {
            #expect(id.first?.isLetter == true || id.first == "_")
            for character in id.dropFirst() {
                #expect(
                    character.isLetter || character.isNumber || character == "_"
                        || character == "." || character == "-",
                    "\(id) carries \(character), which the lexer will not read")
            }
        }
    }
}
