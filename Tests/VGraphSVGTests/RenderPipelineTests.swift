// Unit tests for the `RenderPipeline.compose` composition primitive.
// These exercise the pipeline in isolation — no renderer involvement — to lock
// down its semantics independently of any specific renderer.

import Testing

@testable import VGraph
@testable import VGraphSVG

struct RenderPipelineTests {

    // A throwaway VGraph the passes ignore — the pipeline doesn't inspect it,
    // it just threads it through the context.
    private func makeContext(darkMode: Bool = false) -> RenderContext {
        return RenderContext(graph: VGraph(), darkMode: darkMode)
    }

    // MARK: - Empty composition

    @Test func emptyArrayReturnsEmptyString() throws {
        let pipeline = RenderPipeline.compose([])
        let result = try pipeline(makeContext())
        #expect(result == "")
    }

    @Test func emptyPassEmitsEmptyString() throws {
        let pipeline = RenderPipeline.compose([RenderPipeline.empty])
        let result = try pipeline(makeContext())
        #expect(result == "")
    }

    // MARK: - Ordering

    @Test func passesRunInDeclaredOrder() throws {
        let passes: [RenderPipeline.Pass] = [
            { _ in "A" },
            { _ in "B" },
            { _ in "C" },
        ]
        let result = try RenderPipeline.compose(passes)(makeContext())
        #expect(result == "ABC")
    }

    @Test func passesAreConcatenatedNotSeparated() throws {
        // No separators, no whitespace — strings join literally.
        let passes: [RenderPipeline.Pass] = [
            { _ in "<g>" },
            { _ in "<rect/>" },
            { _ in "</g>" },
        ]
        let result = try RenderPipeline.compose(passes)(makeContext())
        #expect(result == "<g><rect/></g>")
    }

    // MARK: - Context threading

    @Test func contextIsPassedToEveryPass() throws {
        // Each pass reads `darkMode` and emits a marker; we verify all three saw it.
        let passes: [RenderPipeline.Pass] = [
            { ctx in ctx.darkMode ? "[1:dark]" : "[1:light]" },
            { ctx in ctx.darkMode ? "[2:dark]" : "[2:light]" },
            { ctx in ctx.darkMode ? "[3:dark]" : "[3:light]" },
        ]
        let pipeline = RenderPipeline.compose(passes)
        #expect(try pipeline(makeContext(darkMode: true)) == "[1:dark][2:dark][3:dark]")
        #expect(try pipeline(makeContext(darkMode: false)) == "[1:light][2:light][3:light]")
    }

    // MARK: - Error propagation

    @Test func throwingPassPropagatesError() throws {
        // Each closure must be typed explicitly so Swift infers `throws(VError)`
        // — otherwise it falls back to `throws any Error`.
        let before: RenderPipeline.Pass = { _ in "before" }
        let boom: RenderPipeline.Pass = { _ throws(VError) in throw VError.notImplemented("boom") }
        let after: RenderPipeline.Pass = { _ in "after" }  // should not run
        let pipeline = RenderPipeline.compose([before, boom, after])
        #expect(throws: VError.self) {
            _ = try pipeline(makeContext())
        }
    }

    @Test func throwingPassStopsExecution() throws {
        // Confirm later passes do NOT execute after a throw.
        let executed = Counter()
        let before: RenderPipeline.Pass = { _ in "before" }
        let boom: RenderPipeline.Pass = { _ throws(VError) in throw VError.notImplemented("stop here") }
        let after: RenderPipeline.Pass = { _ in
            executed.increment()
            return "should-not-appear"
        }
        let pipeline = RenderPipeline.compose([before, boom, after])
        _ = try? pipeline(makeContext())
        #expect(executed.value == 0)
    }

    // MARK: - Single-element composition

    @Test func singlePassActsAsIdentity() throws {
        let pipeline = RenderPipeline.compose([{ _ in "lonely" }])
        #expect(try pipeline(makeContext()) == "lonely")
    }
}

/// Reference-counted counter so a closure can mutate a value without
/// inout / @Sendable gymnastics for these tests.
private final class Counter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}
