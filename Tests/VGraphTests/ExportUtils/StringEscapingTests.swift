import Testing

@testable import VGraph

struct StringEscapingTests {
    @Test(
        "Quotes and backslashes are escaped, everything else is left alone",
        arguments: [
            (#"Hello "World""#, #"Hello \"World\""#),
            (#"C:\Users\file"#, #"C:\\Users\\file"#),
            (#"Path: "C:\data""#, #"Path: \"C:\\data\""#),
            ("Hello World", "Hello World"),
            (#"C:\\Users\\file"#, #"C:\\\\Users\\\\file"#),
        ])
    func escape(input: String, expected: String) {
        #expect(StringEscaping.escape(input) == expected)
    }
}
