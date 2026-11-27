import Foundation
import Testing
import VGraph

@testable import vgraph_cli

@Suite("describe --format json")
struct DescribeJSONTests {
    @Test("Each rule is an object; check and counterexample appear only when there is one")
    func rulesAsJSON() throws {
        let json = try Describe.json(of: [
            StatedRule(rule: "Every Question has at least one Answer.", check: "unansweredQuestions", counterexample: "vgraph g: IBIS \"Q\" {}"),
            StatedRule(rule: "A Container belongs inside a SoftwareSystem.", check: nil, counterexample: nil),
        ])
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let rules = try #require(object["rules"] as? [[String: String]])
        #expect(
            rules == [
                [
                    "rule": "Every Question has at least one Answer.", "check": "unansweredQuestions",
                    "counterexample": "vgraph g: IBIS \"Q\" {}",
                ],
                ["rule": "A Container belongs inside a SoftwareSystem."],
            ])
    }
}
