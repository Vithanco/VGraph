import Testing

@testable import VGraph

/// What a label may be, so the name derived from it is a VGL identifier the
/// parser reads back. A label the rule cannot use is refused, not repaired.
@Suite("A view's name from its label")
struct ViewNameTests {
    private func name(_ label: String, taken: [String] = []) -> String? {
        VGraph.viewName(forLabel: label, taken: taken)
    }

    @Test("Given the label Containers, then the name is containers; System Context gives system-context")
    func lowercasedWithHyphens() {
        #expect(name("Containers") == "containers")
        #expect(name("System Context") == "system-context")
    }

    @Test("Given a taken name, then a number follows: containers2, then containers3")
    func numbered() {
        #expect(name("Containers", taken: ["containers"]) == "containers2")
        #expect(name("Containers", taken: ["containers", "containers2"]) == "containers3")
    }

    @Test("Given a label with a symbol, an accent or nothing usable, or one that starts with a digit, then it is refused")
    func refused() {
        #expect(name("Context (C4)") == nil)
        #expect(name("Übersicht") == nil)
        #expect(name("!!!") == nil)
        #expect(name("") == nil)
        #expect(name("   ") == nil)
        #expect(name("3D") == nil)
    }

    @Test("Given a label that is a VGL keyword, then it is refused")
    func keywordRefused() {
        #expect(name("node") == nil)
        #expect(name("Group") == nil)
    }
}
