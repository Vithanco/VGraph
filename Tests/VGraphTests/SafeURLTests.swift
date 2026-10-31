//
//  SafeURLTests.swift
//  VGraph
//
//  What may be stored in a `url` attribute — and therefore handed to the host
//  browser by the openURL command.
//

import Testing

@testable import VGraph

struct SafeURLTests {

    @Test func keepsWebLinksAsTyped() {
        #expect(VURL.safe("https://vithanco.com/docs") == "https://vithanco.com/docs")
        #expect(VURL.safe("http://example.com") == "http://example.com")
        #expect(VURL.safe("mailto:klaus@vithanco.com") == "mailto:klaus@vithanco.com")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(VURL.safe("  https://vithanco.com  ") == "https://vithanco.com")
    }

    /// The common case of pasting a bare host: assume the web rather than reject.
    @Test func assumesHttpsWhenNoSchemeIsGiven() {
        #expect(VURL.safe("vithanco.com") == "https://vithanco.com")
        #expect(VURL.safe("vithanco.com/docs?a=1#top") == "https://vithanco.com/docs?a=1#top")
    }

    /// The whole reason this type exists: the editor hands the result to
    /// `window.open`, so a scripting scheme stored here would run as the page.
    @Test func rejectsSchemesThatAreNotLinks() {
        #expect(VURL.safe("javascript:alert(1)") == nil)
        #expect(VURL.safe("JavaScript:alert(1)") == nil)
        #expect(VURL.safe("  javascript:alert(1)") == nil)
        #expect(VURL.safe("data:text/html;base64,PHNjcmlwdD4=") == nil)
        #expect(VURL.safe("vbscript:msgbox(1)") == nil)
        #expect(VURL.safe("file:///etc/passwd") == nil)
    }

    /// A scheme-looking prefix only counts before the first path separator, so a
    /// port number or a colon inside a path is not mistaken for one.
    @Test func readsTheSchemeOnlyBeforeThePath() {
        #expect(VURL.safe("https://example.com:8080/a") == "https://example.com:8080/a")
        #expect(VURL.safe("example.com/a:b") == "https://example.com/a:b")
    }

    @Test func rejectsWhatCannotBeALink() {
        #expect(VURL.safe("") == nil)
        #expect(VURL.safe("   ") == nil)
        #expect(VURL.safe("https://") == nil)
        #expect(VURL.safe("mailto:") == nil)
        // Whitespace inside would break both quoting and the browser.
        #expect(VURL.safe("https://exa mple.com") == nil)
        // Not a host at all — no dot, no scheme.
        #expect(VURL.safe("just some notes") == nil)
        #expect(VURL.safe("notes") == nil)
    }
}
