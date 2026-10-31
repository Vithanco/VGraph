//
//  DiagnosticsHTMLTest.swift
//  VGraph
//
//  The diagnostics box under the editor. It is filled through `innerHTML`, so
//  what a message says must never become markup.
//

import EditorCore
import Testing
import VGraph

struct DiagnosticsHTMLTest {
    @Test func aCleanReportSaysSo() {
        #expect(EditorCore.diagnosticsHTML([], hardError: nil).contains("No warnings or errors."))
    }

    /// Errors first, whatever order the report listed them in.
    @Test func rowsRunFromErrorsToInfos() {
        let html = EditorCore.diagnosticsHTML(
            [
                MessageWithSeverity(message: "an info", severity: .info),
                MessageWithSeverity(message: "a warning", severity: .warning),
                MessageWithSeverity(message: "an error", severity: .error),
            ], hardError: "it broke")
        let order = ["it broke", "an error", "a warning", "an info"].map { message in
            html.range(of: message).map { html.distance(from: html.startIndex, to: $0.lowerBound) } ?? -1
        }
        #expect(order == order.sorted())
        #expect(!order.contains(-1))
        #expect(!html.contains("No warnings or errors."))
    }

    @Test func eachRowIsLabelledBySeverity() {
        let html = EditorCore.diagnosticsHTML(
            [
                MessageWithSeverity(message: "w", severity: .warning),
                MessageWithSeverity(message: "i", severity: .info),
            ], hardError: "e")
        #expect(html.contains("<b>ERROR</b>&nbsp;e"))
        #expect(html.contains("<b>WARN</b>&nbsp;w"))
        #expect(html.contains("<b>INFO</b>&nbsp;i"))
    }

    @Test func messagesAreEscaped() {
        let html = EditorCore.diagnosticsHTML(
            [MessageWithSeverity(message: "a -> <b> & c", severity: .error)], hardError: nil)
        #expect(html.contains("a -&gt; &lt;b&gt; &amp; c"))
        #expect(!html.contains("<b> & c"))
    }
}
