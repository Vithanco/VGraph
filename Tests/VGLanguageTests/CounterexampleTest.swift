// A reader is shown each [[Counterexample]] to watch its warning appear, so the
// document shown must be the one proven to break its rule, and only that rule.

import Testing

@testable import VGLanguage
@testable import VGraph

private func checks(of entry: NotationEntry) -> [QualityCheck] {
    entry.namedQualityChecks.filter { !GenericQualityChecks.runsAlways($0) }.compactMap {
        try? QualityCheckRegistry.resolve($0)
    } + entry.qualityChecks
}

/// Keyed by registry id and check name.
private let counterexamples: [String] = NotationRegistry.entries.flatMap { id, entry in
    entry.counterexamples.map { "\(id)/\($0.check)" }
}

@Suite
struct CounterexampleTest {

    @Test
    func everyCheckANotationRunsHasACounterexampleOrSaysWhyNot() {
        for (id, entry) in NotationRegistry.entries {
            let wanted = checks(of: entry).filter { $0.noCounterexampleBecause == nil }.map { $0.name }
            #expect(entry.counterexamples.map { $0.check }.sorted() == wanted.sorted(), "\(id)")
        }
    }

    @Test
    func aCheckWithoutACounterexampleSaysWhy() {
        for (id, entry) in NotationRegistry.entries {
            for check in checks(of: entry) {
                guard let reason = check.noCounterexampleBecause else { continue }
                #expect(reason.hasSuffix(".") && reason.count > 20, "\(id)/\(check.name): \"\(reason)\"")
            }
        }
    }

    @Test(arguments: counterexamples)
    func aCounterexampleBreaksItsRuleAndNoOther(key: String) throws {
        let parts = key.split(separator: "/").map(String.init)
        let entry = try #require(NotationRegistry.entry(for: parts[0]))
        let source = try #require(entry.counterexamples.first { $0.check == parts[1] }).source
        let check = try #require(checks(of: entry).first { $0.name == parts[1] })
        let graph = try VGraphParser(logger: NoOpLogger()).parse(source: source)
        #expect(NotationRegistry.entry(for: graph.notationName)?.id == entry.id, "\(key) is not written in its notation")

        let findings = check(graph)
        let metrics = entry.metrics.flatMap { $0(graph) }
        let others = Notations.analyzeQuality(graph: graph).messages.filter {
            !findings.contains($0) && !metrics.contains($0)
        }
        #expect(!findings.isEmpty, "\(key) does not break: \(check.rule)")
        #expect(others.isEmpty, "\(key) also trips: \(others.map { $0.message })")
    }
}
