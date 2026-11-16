import Testing

@testable import VGraph

@Suite("QualityCheckSpec")
struct QualityCheckSpecTests {

    @Test
    func aBareNameHasNoParameters() {
        let simple = QualityCheckSpec.parse("treeStructure")
        #expect(simple.name == "treeStructure")
        #expect(simple.params.isEmpty)
        #expect(simple.specString == "treeStructure")
    }

    @Test
    func parametersAreSplitAndTrimmedAndWrittenBack() {
        let withParams = QualityCheckSpec.parse("nodeCountRange(Battle, 1, 20)")
        #expect(withParams.name == "nodeCountRange")
        #expect(withParams.params == ["Battle", "1", "20"])
        #expect(withParams.specString == "nodeCountRange(Battle, 1, 20)")
    }
}
