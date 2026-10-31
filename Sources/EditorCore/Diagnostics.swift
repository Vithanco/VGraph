//
//  Diagnostics.swift
//  EditorCore
//

import VGraph

/// `hardError` is a thrown render failure.
public func diagnosticsHTML(_ messages: [MessageWithSeverity], hardError: String?) -> String {
    var rows = ""
    if let hardError {
        rows += row(.error, hardError)
    }
    for severity in [Severity.error, .warning, .info] {
        for message in messages where message.severity == severity {
            rows += row(severity, message.message)
        }
    }
    return rows.isEmpty ? "<div style=\"color:#3a7a4a;\">No warnings or errors.</div>" : rows
}

/// Enough for text placed between tags; not for attribute values.
public func htmlEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private func row(_ severity: Severity, _ text: String) -> String {
    let (color, label) =
        switch severity {
        case .error: ("#b00020", "ERROR")
        case .warning: ("#b26a00", "WARN")
        case .info: ("#3367d6", "INFO")
        }
    return "<div style=\"padding:2px 0;color:\(color);\"><b>\(label)</b>&nbsp;\(htmlEscape(text))</div>"
}
