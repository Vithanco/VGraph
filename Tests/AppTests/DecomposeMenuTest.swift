import EditorCore
import Testing
import VGLanguage
import VGraph

@testable import App

/// Decompose is reached from a node's right-click menu, and only where it can
/// run: absent rather than greyed elsewhere, since no notation break reaches it.
struct DecomposeMenuTest {
    private func session() throws -> TestSession {
        try makeTestSession(
            vgl: """
                vnotation Arch {
                  node type: Person [nodeStyle: roundedBox]
                  node type: System [nodeStyle: roundedBox, detailedBy: (Container, Store)]
                  node type: Container [nodeStyle: roundedBox]
                  node type: Store [nodeStyle: roundedBox]
                  edge type: uses from: Person to: System
                  edge type: systemToSystem from: System to: System
                }

                vgraph g: Arch "G" {
                  node alice: Person "Alice";
                  node bank: System "Bank";
                  node mail: System "Mail";
                  group core: System "Core" {
                    node api: Container "API";
                  }
                  edge alice -> bank;
                  edge bank -> mail;
                }
                """)
    }

    private func titles(_ elementId: String, in s: TestSession) -> [String] {
        EditorCore.menu(for: elementId, in: s).map { $0.title }
    }

    @Test("Given a node whose type has a detailing, when right-clicked, then Decompose is offered and enabled")
    func offeredWhereTheTypeHasADetailing() throws {
        let s = try session()

        let row = try #require(EditorCore.menu(for: "bank", in: s).first { $0.id == .decompose })

        #expect(row.title == "Decompose")
        #expect(row.enabled)
    }

    @Test("Given a node whose type has no detailing, when right-clicked, then Decompose is not in the menu")
    func absentWhereTheTypeHasNone() throws {
        #expect(!titles("alice", in: try session()).contains("Decompose"))
    }

    @Test("Given a detailed node, when right-clicked, then Decompose is not in the menu")
    func absentOnADetailedNode() throws {
        #expect(!titles("core", in: try session()).contains("Decompose"))
    }

    @Test("Given Decompose chosen, when the conversation begins, then it performs at once")
    func asksNothing() throws {
        let begun = EditorCore.begin(.decompose, on: "bank", forcingChoice: false, in: try session())

        #expect(begun.step == .perform(.decompose(node: "bank")))
    }
}
