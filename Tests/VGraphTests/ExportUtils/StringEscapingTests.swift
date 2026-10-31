import Testing

@testable import VGraph

struct StringEscapingTests {
    @Test func testEscapeQuotes() {
        let input = "Hello \"World\""
        let expected = "Hello \\\"World\\\""
        #expect(StringEscaping.escape(input) == expected)
    }

    @Test func testEscapeBackslashes() {
        let input = "C:\\Users\\file"
        let expected = "C:\\\\Users\\\\file"
        #expect(StringEscaping.escape(input) == expected)
    }

    @Test func testEscapeBoth() {
        let input = "Path: \"C:\\data\""
        let expected = "Path: \\\"C:\\\\data\\\""
        #expect(StringEscaping.escape(input) == expected)
    }

    @Test func testNoEscapeNeeded() {
        let input = "Hello World"
        #expect(StringEscaping.escape(input) == input)
    }

    @Test func testEmptyString() {
        let input = ""
        #expect(StringEscaping.escape(input) == "")
    }

    @Test func testMultipleQuotes() {
        let input = "\"Hello\" \"World\""
        let expected = "\\\"Hello\\\" \\\"World\\\""
        #expect(StringEscaping.escape(input) == expected)
    }

    @Test func testMultipleBackslashes() {
        let input = "C:\\\\Users\\\\file"
        let expected = "C:\\\\\\\\Users\\\\\\\\file"
        #expect(StringEscaping.escape(input) == expected)
    }
}
