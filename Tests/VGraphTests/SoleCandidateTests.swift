import Testing

@testable import VGraph

struct SoleCandidateTests {

    private let other = VCommandOption(id: "__break__", title: "Other type…", isBreak: true)
    private let candidate = VCommandOption(id: "supports", title: "Argument")

    @Test func oneRealCandidateIsNotAChoice() {
        #expect(VCommandOption.soleCandidate(in: [candidate, other])?.id == "supports")
    }

    @Test func theEscapeHatchIsNeverTheCandidate() {
        #expect(VCommandOption.soleCandidate(in: [other, candidate])?.id == "supports")
        #expect(VCommandOption.soleCandidate(in: [other]) == nil)
    }

    @Test func twoRealCandidatesAreAGenuineChoice() {
        let options = [
            VCommandOption(id: "supports", title: "Argument (pro)"),
            VCommandOption(id: "objects", title: "Argument (con)"),
            other,
        ]

        #expect(VCommandOption.soleCandidate(in: options) == nil)
    }

    @Test func theNodeTypeListBehindTheEscapeHatchIsNeverAutoPicked() {
        #expect(
            VCommandOption.soleCandidate(in: [VCommandOption(id: "Answer", title: "Answer")]) == nil,
            "auto-picking here would take a notation break without ever showing it")
    }

    @Test func anEmptyListHasNoSoleCandidate() {
        #expect(VCommandOption.soleCandidate(in: []) == nil)
    }
}
