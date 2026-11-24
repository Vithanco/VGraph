import Testing

@testable import VGraph

@Suite("OneToManyLookup Tests")
struct OneToManyLookupTests {

    @Test
    func addAndRemoveOne() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.adding(many: "node1", one: "type1")
        #expect(lookup.getOne(many: "node1") == "type1")
        #expect(lookup.getMany(one: "type1") == ["node1"])

        lookup = lookup.removing(many: "node1")
        #expect(lookup == OneToManyLookup<String, String>())
    }

    @Test
    func addAndRemoveTwo() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.adding(many: "node1", one: "type1")
        lookup = lookup.adding(many: "node2", one: "type1")
        #expect(lookup.getOne(many: "node1") == "type1")
        #expect(lookup.getMany(one: "type1") == ["node1", "node2"])

        lookup = lookup.removing(many: "node1")
        #expect(lookup.getOne(many: "node1") == nil)
        #expect(lookup.getMany(one: "type1") == ["node2"])

        lookup = lookup.removing(many: "node2")
        #expect(lookup == OneToManyLookup<String, String>())
    }

    @Test
    func addAndRemoveTwoOthers() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.adding(many: "node1", one: "type1")
        lookup = lookup.adding(many: "node2", one: "type1")

        lookup = lookup.removing(one: "type1")
        #expect(lookup == OneToManyLookup<String, String>())
    }

    @Test
    func lookupWorks() throws(VError) {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.adding(many: "node1", one: "type1")
        lookup = lookup.adding(many: "node2", one: "type1")

        #expect(lookup.getMany(one: "type2") == nil)
        #expect(lookup.getOne(many: "node3") == nil)
    }

    @Test
    func addingAManyToAnotherOneMovesIt() {
        var lookup = OneToManyLookup<String, String>()

        lookup = lookup.adding(many: "node1", one: "type1")
        lookup = lookup.adding(many: "node1", one: "type2")

        #expect(lookup.getOne(many: "node1") == "type2")
        #expect(lookup.getMany(one: "type2") == ["node1"])
        #expect(lookup.getMany(one: "type1") == nil)
    }

    @Test
    func addingTheSamePairTwiceChangesNothing() {
        let once = OneToManyLookup<String, String>().adding(many: "node1", one: "type1")

        #expect(once.adding(many: "node1", one: "type1") == once)
    }

    @Test
    func removingWhatIsNotThereChangesNothing() {
        let lookup = OneToManyLookup<String, String>().adding(many: "node1", one: "type1")

        #expect(lookup.removing(many: "node2") == lookup)
        #expect(lookup.removing(one: "type2") == lookup)
    }

    /// Equality is by content, so the order things were added in must not matter.
    @Test
    func equalContentIsEqualAndHashesEqually() {
        let a = OneToManyLookup<String, String>()
            .adding(many: "node1", one: "type1")
            .adding(many: "node2", one: "type2")
        let b = OneToManyLookup<String, String>()
            .adding(many: "node2", one: "type2")
            .adding(many: "node3", one: "type1")
            .adding(many: "node1", one: "type1")
            .removing(many: "node3")

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != a.adding(many: "node1", one: "type2"))
    }
}
