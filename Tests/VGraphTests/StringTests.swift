import Testing

@testable import VGraph

@Suite
struct StringTests {

    @Test
    func example() throws {
        #expect("Hello.test".removeTrailing(trail: ".test") == "Hello")
        #expect("Hello.test".removeTrailing(trail: ".other") == "Hello.test")
        #expect("".removeTrailing(trail: ".test") == "")
        #expect("Hello.test".removeTrailing(trail: "") == "Hello.test")
    }
}
