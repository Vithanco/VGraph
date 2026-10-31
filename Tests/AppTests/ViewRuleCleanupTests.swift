import Testing
import VGraph

@testable import App

private func document(_ rules: String) -> String {
    """
    vgraph banking: C4 "Internet Banking" {
        node customer: Person "Customer";
        group ibs "Internet Banking System" {
            node web: Container "Web";
            node api: Container "API";
            node db: Database "DB";
        }
        edge customer -> web;
        edge web -> api;
        edge api -> db;
    }

    vview v {
    \(rules)
    }
    """
}

private func viewBlock(_ name: String, in text: String) -> String {
    guard let start = text.range(of: "vview \(name)") else { return "" }
    let rest = text[start.lowerBound...]
    guard let end = rest.range(of: "\n}\n") else { return String(rest) }
    return String(rest[..<end.upperBound])
}

@Suite("Deleting an element drops it from views' rules")
struct ViewRuleCleanupTests {

    @Test("Given include node web, api, when web is deleted, then the rule reads include node api")
    func deletedNameLeavesTheList() throws {
        let s = try makeTestSession(vgl: document("include node web, api;"))
        try s.delete("web")
        let block = viewBlock("v", in: try s.exportVGL())
        #expect(block.contains("include node api\n"))
        #expect(!block.contains("web"))
    }

    @Test("Given include node web, when web is deleted, then the rule is gone")
    func emptiedRuleGoes() throws {
        let s = try makeTestSession(vgl: document("include node web;"))
        try s.delete("web")
        #expect(!viewBlock("v", in: try s.exportVGL()).contains("include"))
    }

    @Test("Given include node customer, web downstream 1, when customer is deleted, then the rule reads include node web downstream 1")
    func reachStaysOnTheRest() throws {
        let s = try makeTestSession(vgl: document("include node customer, web downstream 1;"))
        try s.delete("customer")
        #expect(viewBlock("v", in: try s.exportVGL()).contains("include node web downstream 1\n"))
    }

    @Test("Given exclude group ibs, when ibs is deleted with its contents, then the rule is gone")
    func deletedGroupLeavesTheRule() throws {
        let s = try makeTestSession(vgl: document("exclude group ibs;"))
        try s.delete("ibs")
        #expect(!viewBlock("v", in: try s.exportVGL()).contains("exclude"))
    }

    @Test("Given include node type: Container, when web is deleted, then the rule is unchanged")
    func typeRulesStay() throws {
        let s = try makeTestSession(vgl: document("include node type: Container;"))
        try s.delete("web")
        #expect(viewBlock("v", in: try s.exportVGL()).contains("include node type: Container\n"))
    }

    @Test("Given include node nothere, when an unrelated node is deleted, then the rule is unchanged")
    func unknownNamesStay() throws {
        let s = try makeTestSession(vgl: document("include node nothere;"))
        try s.delete("web")
        #expect(viewBlock("v", in: try s.exportVGL()).contains("include node nothere\n"))
    }

    @Test("Given two views naming web, when web is deleted, then both rules lose it")
    func everyViewIsCleaned() throws {
        let source = document("include node web, api;") + "\n\nvview w {\n exclude node web, db;\n}\n"
        let s = try makeTestSession(vgl: source)
        try s.delete("web")
        let text = try s.exportVGL()
        #expect(viewBlock("v", in: text).contains("include node api\n"))
        #expect(viewBlock("w", in: text).contains("exclude node db\n"))
    }

    @Test("Given web deleted, when undone, then the rule names web again")
    func undoBringsTheNameBack() throws {
        let s = try makeTestSession(vgl: document("include node web, api;"))
        try s.delete("web")
        _ = try s.undo()
        #expect(viewBlock("v", in: try s.exportVGL()).contains("include node web, api\n"))
    }

    @Test("Given expand 1, when a node is deleted, then the rule is unchanged")
    func expandStays() throws {
        let s = try makeTestSession(vgl: document("include node api;\nexpand 1;"))
        try s.delete("web")
        #expect(viewBlock("v", in: try s.exportVGL()).contains("expand 1\n"))
    }

    @Test("Given a view naming web, when web's line is removed by a text edit, then the rule still names web")
    func textEditsLeaveRulesAlone() throws {
        let source = document("include node web, api;")
        let s = try makeTestSession(vgl: source)
        let without = source.replacingOccurrences(of: "    node web: Container \"Web\";\n", with: "")
            .replacingOccurrences(of: "    edge customer -> web;\n    edge web -> api;\n", with: "")
        try s.textEdited(vgl: without)
        #expect(viewBlock("v", in: try s.exportVGL()).contains("include node web, api\n"))
    }
}
