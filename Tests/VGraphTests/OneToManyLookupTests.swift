import Testing

@testable import VGraph

@Suite("OneToManyLookup Tests")
struct OneToManyLookupTests {

    func testInvariants<S, T>(_ lookup: OneToManyLookup<S, T>) {
        #expect(lookup._oneToMany.keys.count == lookup._manyToOne.values.asSet.count)
        #expect(lookup._manyToOne.keys.count == lookup._oneToMany.values.reduce(0) { $0 + $1.count })
    }

    @Test
    func addAndRemoveOne() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.add(many: "node1", one: "type1")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 1, manys: 1))
        testInvariants(lookup)
        #expect(lookup.getOne(many: "node1") == "type1")
        #expect(lookup.getMany(one: "type1") == ["node1"])

        lookup = lookup.remove(many: "node1")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 0, manys: 0))
        testInvariants(lookup)
    }

    @Test
    func addAndRemoveTwo() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.add(many: "node1", one: "type1")
        lookup = lookup.add(many: "node2", one: "type1")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 1, manys: 2))
        testInvariants(lookup)
        #expect(lookup.getOne(many: "node1") == "type1")
        #expect(lookup.getMany(one: "type1") == ["node1", "node2"])

        lookup = lookup.remove(many: "node1")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 1, manys: 1))
        testInvariants(lookup)

        lookup = lookup.remove(many: "node2")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 0, manys: 0))
        testInvariants(lookup)
    }

    @Test
    func addAndRemoveTwoOthers() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.add(many: "node1", one: "type1")
        lookup = lookup.add(many: "node2", one: "type1")

        lookup = lookup.remove(one: "type1")
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 0, manys: 0))
        testInvariants(lookup)
    }

    @Test
    func lookupWorks() async throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.add(many: "node1", one: "type1")
        lookup = lookup.add(many: "node2", one: "type1")

        #expect(lookup.getMany(one: "type2") == nil)
        #expect(lookup.getOne(many: "node3") == nil)
    }

    /// Undo keeps old versions around, so a change must never reach back into one.
    @Test
    func changingANewValueLeavesTheOldOneAlone() {
        let old = OneToManyLookup<String, String>()
            .add(many: "node1", one: "type1")
            .add(many: "node2", one: "type1")

        let new = old.add(many: "node3", one: "type1").remove(many: "node1").remove(one: "type1")

        #expect(new.counts() == OneToManyLookup.Counts(ones: 0, manys: 0))
        #expect(old.getMany(one: "type1") == ["node1", "node2"])
        #expect(old.getOne(many: "node1") == "type1")
        #expect(old.getOne(many: "node3") == nil)
    }

    @Test
    func addingAManyToAnotherOneMovesIt() {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.add(many: "node1", one: "type1")
        lookup = lookup.add(many: "node1", one: "type2")

        #expect(lookup.getOne(many: "node1") == "type2")
        #expect(lookup.getMany(one: "type2") == ["node1"])
        #expect(lookup.getMany(one: "type1") == nil)
        #expect(lookup.counts() == OneToManyLookup.Counts(ones: 1, manys: 1))
        testInvariants(lookup)
    }

    @Test
    func addingTheSamePairTwiceChangesNothing() {
        let once = OneToManyLookup<String, String>().add(many: "node1", one: "type1")

        #expect(once.add(many: "node1", one: "type1") == once)
    }

    @Test
    func removingWhatIsNotThereChangesNothing() {
        let lookup = OneToManyLookup<String, String>().add(many: "node1", one: "type1")

        #expect(lookup.remove(many: "node2") == lookup)
        #expect(lookup.remove(one: "type2") == lookup)
    }

    @Test
    func listsAllOnesAndAllManys() {
        let lookup = OneToManyLookup<String, String>()
            .add(many: "node1", one: "type1")
            .add(many: "node2", one: "type1")
            .add(many: "node3", one: "type2")

        #expect(lookup.getAllOnes.asSet == ["type1", "type2"])
        #expect(lookup.getAllManys == ["node1", "node2", "node3"])
    }

    /// Equality is by content, so the order things were added in must not matter.
    @Test
    func equalContentIsEqualAndHashesEqually() {
        let a = OneToManyLookup<String, String>()
            .add(many: "node1", one: "type1")
            .add(many: "node2", one: "type2")
        let b = OneToManyLookup<String, String>()
            .add(many: "node2", one: "type2")
            .add(many: "node3", one: "type1")
            .add(many: "node1", one: "type1")
            .remove(many: "node3")

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != a.add(many: "node1", one: "type2"))
    }
}
